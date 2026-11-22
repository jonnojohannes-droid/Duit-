#ifndef BUIE_LLAMA_H
#define BUIE_LLAMA_H
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct BuieEngine BuieEngine;
BuieEngine *buie_engine_create(const char *model_path, int context_size, char *error_buffer, size_t error_buffer_size);
int buie_engine_generate(BuieEngine *engine, const char *prompt, int max_tokens, char *output_buffer, size_t output_buffer_size, char *error_buffer, size_t error_buffer_size);
void buie_engine_cancel(BuieEngine *engine);
void buie_engine_destroy(BuieEngine *engine);
#ifdef __cplusplus
}
#endif
#endif
