# Buie — Local AI Project Generator

Native SwiftUI iOS reconstruction based on the supplied `Buie-unsigned.ipa`.

Buie is a task runner, not a chatbot:
1. Import a local `.gguf` instruction model from Files.
2. Enter one software-building task.
3. Run inference locally through llama.cpp.
4. Require a strict JSON object containing `files`, `path`, and `content`.
5. Parse and validate the output.
6. Create a ZIP containing separate files and folders.
7. Export the ZIP using the iOS document exporter.

## Structure
- `Buie/App`: SwiftUI app and one-screen workflow.
- `Buie/Core`: state, inference wrapper, parser, path validation, ZIP writer.
- `Buie/Bridge`: C wrapper for llama.cpp.
- `project.yml`: XcodeGen project definition.
- `codemagic.yaml`: unsigned Codemagic workflow.
- `scripts/prepare_llama.sh`: builds llama.cpp for iOS arm64.

## Build
On macOS with Xcode, CMake, XcodeGen and Git:

```bash
brew install cmake xcodegen
./scripts/prepare_llama.sh
xcodegen generate
xcodebuild -project Buie.xcodeproj -scheme Buie \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

The supplied IPA is compiled output, not the lost source project. This is a reconstruction, not a byte-for-byte recovery. The IPA contains a device-only `llama.framework` binary but no public headers; this project builds llama.cpp from source so its headers and linked library match.

The Codemagic workflow creates an unsigned `.app` for build verification. An installable IPA/TestFlight build requires your own Apple signing credentials and provisioning profile. See `docs/BUILD_AND_USE.md`.
