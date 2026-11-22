import Foundation

final class LocalInference: @unchecked Sendable {
    private let lock = NSLock()
    private var handle: OpaquePointer?

    var isLoaded: Bool {\n        lock.lock(); defer { lock.unlock() }\n        return handle != nil\n    }\n\n    func loadModel(at url: URL) throws {
        unload()
        var error = [CChar](repeating: 0, count: 2048)
        let pointer = url.path.withCString { buie_engine_create($0, 4096, &error, error.count) }
        guard let pointer else { throw InferenceError.modelLoad(String(cString: error)) }
        lock.lock(); handle = pointer; lock.unlock()
    }

    func generate(prompt: String, maxTokens: Int = 8192) throws -> String {
        lock.lock(); let current = handle; lock.unlock()
        guard let current else { throw InferenceError.noModel }
        let capacity = 16 * 1024 * 1024
        let output = UnsafeMutablePointer<CChar>.allocate(capacity: capacity)
        defer { output.deallocate() }
        var error = [CChar](repeating: 0, count: 2048)
        let result = prompt.withCString {
            buie_engine_generate(current, $0, Int32(maxTokens), output, capacity, &error, error.count)
        }
        if result == 1 { throw InferenceError.cancelled }
        guard result == 0 else { throw InferenceError.generation(String(cString: error)) }
        return String(cString: output)
    }

    func cancel() {
        lock.lock(); let current = handle; lock.unlock()
        if let current { buie_engine_cancel(current) }
    }

    func unload() {
        lock.lock(); let current = handle; handle = nil; lock.unlock()
        if let current { buie_engine_destroy(current) }
    }

    deinit { unload() }
}

enum InferenceError: LocalizedError {
    case noModel, modelLoad(String), generation(String), cancelled
    var errorDescription: String? {
        switch self {
        case .noModel: return "Geen model geselecteerd"
        case .modelLoad(let s): return s.isEmpty ? "Het model kon niet worden geladen. Gebruik een ondersteund GGUF-model dat op dit apparaat past." : s
        case .generation(let s): return s.isEmpty ? "Het model kon de opdracht niet uitvoeren." : s
        case .cancelled: return "Opdracht gestopt."
        }
    }
}
