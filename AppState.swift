import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var instruction = ""
    @Published var status = "Importeer een GGUF-instructiemodel om te beginnen."
    @Published var modelName: String?
    @Published var isBusy = false
    @Published var canCancel = false
    @Published var document: ZipDocument?
    @Published var showExporter = false

    private let inference = LocalInference()
    private var generationTask: Task<Void, Never>?
    private var modelURL: URL?

    private let modelDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    init() {
        let path = UserDefaults.standard.string(forKey: "Buie.savedModelPath")
        if let path, FileManager.default.fileExists(atPath: path) {
            modelURL = URL(fileURLWithPath: path)
            modelName = UserDefaults.standard.string(forKey: "Buie.savedModelName") ?? URL(fileURLWithPath: path).lastPathComponent
            status = "Model beschikbaar. Laden bij gebruik."
        }
    }

    func importModel(from source: URL) {
        guard source.pathExtension.lowercased() == "gguf" else { status = "Selecteer een .gguf-bestand."; return }
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        do {
            let destination = modelDirectory.appendingPathComponent(source.lastPathComponent)
            if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
            try FileManager.default.copyItem(at: source, to: destination)
            status = "Model wordt geladen..."
            try inference.loadModel(at: destination)
            modelURL = destination
            modelName = destination.lastPathComponent
            UserDefaults.standard.set(destination.path, forKey: "Buie.savedModelPath")
            UserDefaults.standard.set(destination.lastPathComponent, forKey: "Buie.savedModelName")
            status = "Model gereed. Beschrijf je opdracht."
            document = nil
        } catch { status = "Import mislukt: \(error.localizedDescription)" }
    }

    func runTask() {
        guard !isBusy else { return }
        guard modelURL != nil, modelName != nil else { status = "Geen model geselecteerd"; return }
        let taskText = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !taskText.isEmpty else { status = "Beschrijf eerst je opdracht."; return }

        isBusy = true; canCancel = true; document = nil
        status = "Het model werkt lokaal aan je opdracht"
        let prompt = [
            "Maak de gevraagde broncode. Antwoord uitsluitend met een geldig JSON-object in dit formaat:",
            #"{"files":[{"path":"relatief/pad","content":"volledige bestandsinhoud"}]}"#,
            "Gebruik JSON-escaping voor alle tekst. Geef uitsluitend bestanden, geen uitleg of markdown.",
            "Maak geen absolute paden of paden met .. aan.",
            "Opdracht:",
            taskText
        ].joined(separator: "\n")

        let engine = inference
        generationTask = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let raw = try engine.generate(prompt: prompt)
                let project = try GeneratedProject.parse(raw)
                let zip = try ZipDocument(project: project)
                await MainActor.run {
                    guard let self else { return }
                    self.document = zip
                    self.status = "Klaar. Exporteer de broncode als zip."
                    self.isBusy = false; self.canCancel = false; self.generationTask = nil
                }
            } catch {
                await MainActor.run {
                    guard let self else { return }
                    self.status = error.localizedDescription
                    self.isBusy = false; self.canCancel = false; self.generationTask = nil
                }
            }
        }
    }

    func cancelTask() {
        guard isBusy else { return }
        inference.cancel()
        generationTask?.cancel()
        status = "Opdracht gestopt."
        isBusy = false; canCancel = false
    }

    func beginExport() { if document != nil { showExporter = true } }

    func exportCompleted(_ result: Result<URL, Error>) {
        switch result {
        case .success: status = "ZIP-export voltooid."
        case .failure(let error): status = "Export mislukt: \(error.localizedDescription)"
        }
    }
}
