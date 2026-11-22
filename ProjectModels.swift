import Foundation

struct ProjectFile: Codable, Hashable {
    let path: String
    let content: String
}

struct GeneratedProject: Codable {
    let files: [ProjectFile]

    static func parse(_ text: String) throws -> GeneratedProject {
        guard let data = text.data(using: .utf8) else { throw ProjectError.invalidOutput }
        let project: GeneratedProject
        do { project = try JSONDecoder().decode(GeneratedProject.self, from: data) }
        catch { throw ProjectError.invalidOutput }
        guard !project.files.isEmpty else { throw ProjectError.emptyProject }

        var seen = Set<String>()
        for file in project.files {
            let p = file.path
            let parts = p.split(separator: "/", omittingEmptySubsequences: false)
            let invalid = p.isEmpty || p.hasPrefix("/") || p.contains("\\") ||
                p.contains("\0") || p.contains(":") ||
                parts.contains("..") || parts.contains(".") || parts.contains("")
            guard !invalid, seen.insert(p).inserted else { throw ProjectError.invalidPath(p) }
        }
        return project
    }
}

enum ProjectError: LocalizedError {
    case invalidOutput, emptyProject, invalidPath(String), tooLarge
    var errorDescription: String? {
        switch self {
        case .invalidOutput: return "Het model gaf ongeldige tekst terug."
        case .emptyProject: return "Het model gaf geen geldig compleet project terug. Probeer een kleinere of duidelijkere opdracht."
        case .invalidPath(let p): return "Ongeldig of dubbel bestandspad: \(p)"
        case .tooLarge: return "Het project is te groot om te exporteren."
        }
    }
}
