import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var state: AppState
    @State private var importing = false
    private var ggufType: UTType { UTType(filenameExtension: "gguf") ?? .data }

    var body: some View {
        NavigationStack {
            Form {
                Section("AI-model") {
                    if let name = state.modelName {
                        LabeledContent("Model", value: name)
                    } else {
                        Text("Geen model geselecteerd").foregroundStyle(.secondary)
                    }
                    Button("Model importeren") { importing = true }
                        .disabled(state.isBusy)
                }
                Section("Opdracht") {
                    TextEditor(text: $state.instruction)
                        .frame(minHeight: 180)
                        .disabled(state.isBusy)
                    Button { state.runTask() } label: {
                        Label("Voer opdracht uit", systemImage: "play.fill")
                    }
                    .disabled(state.isBusy || state.modelName == nil ||
                        state.instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if state.canCancel {
                        Button(role: .destructive) { state.cancelTask() } label: {
                            Label("Opdracht stoppen", systemImage: "stop.fill")
                        }
                    }
                }
                Section("Status") {
                    HStack(alignment: .top, spacing: 10) {
                        if state.isBusy { ProgressView() }
                        else { Image(systemName: "info.circle").foregroundStyle(.secondary) }
                        Text(state.status).font(.footnote).textSelection(.enabled)
                    }
                }
                Section("Export") {
                    Button { state.beginExport() } label: {
                        Label("Exporteer de broncode als zip", systemImage: "archivebox")
                    }
                    .disabled(state.document == nil || state.isBusy)
                }
                Section {
                    Text("Het model blijft op dit apparaat. Gebruik een instructiemodel dat in het beschikbare geheugen past.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Buie")
            .fileImporter(isPresented: $importing, allowedContentTypes: [ggufType], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls): if let url = urls.first { state.importModel(from: url) }
                case .failure(let error): state.status = "Import mislukt: \(error.localizedDescription)"
                }
            }
            .fileExporter(isPresented: $state.showExporter, document: state.document,
                          contentType: .zip, defaultFilename: "Buie-Generated-Project") { result in
                state.exportCompleted(result)
            }
        }
    }
}
