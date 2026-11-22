# Bevindingen uit Buie-unsigned.ipa

Rechtstreeks gecontroleerd:
- Bundle identifier `com.jonnojohannes.buie`.
- Minimum iOS 16.4; iPhone en iPad.
- Embedded `llama.framework` (`org.ggml.llama`), maar de IPA bevat geen publieke frameworkheaders.
- Swift-symbolen voor `AppState`, `ContentView`, `InferenceError`, `ZipDocument`, `BuieCore`, `ProjectFile`, `GeneratedProject` en `ProjectError`.
- Verwijzingen naar `fileImporter`, `fileExporter`, `TextEditor`, `ProgressView` en SwiftUI `Form`.
- JSON-formaat `{"files":[{"path":"relatief/pad","content":"volledige bestandsinhoud"}]}` en promptregels voor geldige JSON, escaping, relatieve paden en het verbieden van `..`.
- Foutmeldingen voor import, model laden, context, ongeldige JSON, bestandspaden en ZIP-export.
- Imports van llama C API-symbolen voor model laden, context, tokenization, decode en sampling.

Beperking: symbolen en strings bewijzen dat deze namen en teksten in de binary voorkomen, niet dat alle codepaden in de oorspronkelijke app correct functioneerden. De door de gebruiker gemelde feitelijke werking — ruwe AI-tekst exporteren — is leidend bij het vaststellen van het oorspronkelijke defect.
