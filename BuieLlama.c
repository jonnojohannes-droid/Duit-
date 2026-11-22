#include "BuieLlama.h"
#include <llama.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct BuieEngine { struct llama_model *model; atomic_bool cancelled; };

static void set_error(char *b, size_t n, const char *s) {
    if (b && n) snprintf(b, n, "%s", s ? s : "Unknown llama.cpp error");
}

BuieEngine *buie_engine_create(const char *path, int context_size, char *err, size_t err_n) {
    if (!path || !path[0]) { set_error(err, err_n, "No model path supplied."); return NULL; }
    llama_backend_init();
    struct llama_model_params mp = llama_model_default_params();
    mp.n_gpu_layers = 99;
    struct llama_model *model = llama_model_load_from_file(path, mp);
    if (!model) { set_error(err, err_n, "llama.cpp could not load this GGUF model."); return NULL; }
    BuieEngine *e = calloc(1, sizeof(BuieEngine));
    if (!e) { llama_model_free(model); set_error(err, err_n, "Not enough memory."); return NULL; }
    e->model = model;
    atomic_init(&e->cancelled, false);
    set_error(err, err_n, "");
    (void)context_size;
    return e;
}

int buie_engine_generate(BuieEngine *e, const char *prompt, int max_tokens,
                         char *out, size_t out_n, char *err, size_t err_n) {
    if (!e || !e->model || !prompt || !out || out_n < 2) {
        set_error(err, err_n, "Invalid generation arguments."); return -1;
    }
    atomic_store(&e->cancelled, false);
    out[0] = 0;
    struct llama_context_params cp = llama_context_default_params();
    cp.n_ctx = 4096;
    cp.n_batch = 512;
    struct llama_context *ctx = llama_init_from_model(e->model, cp);
    if (!ctx) { set_error(err, err_n, "The model context could not be created."); return -2; }

    const struct llama_vocab *vocab = llama_model_get_vocab(e->model);
    int32_t plen = (int32_t)strlen(prompt);
    int32_t cap = plen + 256;
    llama_token *tokens = malloc((size_t)cap * sizeof(llama_token));
    if (!tokens) { llama_free(ctx); set_error(err, err_n, "Not enough memory to tokenize."); return -3; }

    int32_t ntok = llama_tokenize(vocab, prompt, plen, tokens, cap, true, true);
    if (ntok < 0) { free(tokens); llama_free(ctx); set_error(err, err_n, "The prompt is too long for tokenization."); return -4; }

    struct llama_sampler *sampler = llama_sampler_init_greedy();
    if (!sampler) { free(tokens); llama_free(ctx); set_error(err, err_n, "Could not create sampler."); return -5; }
    struct llama_batch batch = llama_batch_get_one(tokens, ntok, 0, 0);
    if (llama_decode(ctx, batch) != 0) {
        llama_sampler_free(sampler); free(tokens); llama_free(ctx);
        set_error(err, err_n, "The model rejected the prompt."); return -6;
    }

    size_t used = 0;
    char piece[1024];
    int generated = 0, result = 0;
    while (generated < max_tokens && !atomic_load(&e->cancelled)) {
        llama_token token = llama_sampler_sample(sampler, ctx, -1);
        if (llama_vocab_is_eog(vocab, token)) break;
        int n = llama_token_to_piece(vocab, token, piece, (int32_t)sizeof(piece), 0, true);
        if (n > 0) {
            if (used + (size_t)n + 1 >= out_n) {
                result = -7; set_error(err, err_n, "Generated output exceeded the safety limit."); break;
            }
            memcpy(out + used, piece, (size_t)n); used += (size_t)n; out[used] = 0;
        }
        batch = llama_batch_get_one(&token, 1, ntok + generated, 0);
        if (llama_decode(ctx, batch) != 0) {
            result = -8; set_error(err, err_n, "Generation stopped because llama.cpp returned a decode error."); break;
        }
        generated++;
    }
    if (atomic_load(&e->cancelled) && result == 0) {
        result = 1; set_error(err, err_n, "Generation cancelled.");
    } else if (result == 0) set_error(err, err_n, "");

    llama_sampler_free(sampler); free(tokens); llama_free(ctx);
    return result;
}

void buie_engine_cancel(BuieEngine *e) { if (e) atomic_store(&e->cancelled, true); }
void buie_engine_destroy(BuieEngine *e) {
    if (e) { if (e->model) llama_model_free(e->model); free(e); }
    llama_backend_free();
}
