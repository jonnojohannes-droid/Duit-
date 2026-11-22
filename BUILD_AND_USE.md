# Buie — bouwen en gebruiken

## Benodigd
- Mac met Xcode 16 of nieuwer
- CMake, XcodeGen en Git
- iPhone/iPad met iOS 16.4 of nieuwer
- GGUF-instructiemodel dat in het RAM-geheugen past

Installeer tools:

```bash
brew install cmake xcodegen
```

## Lokaal bouwen

Open Terminal in de projectmap:

```bash
chmod +x scripts/prepare_llama.sh
./scripts/prepare_llama.sh
xcodegen generate
open Buie.xcodeproj
```

Selecteer een aangesloten iPhone/iPad en bouw het `Buie` scheme. Een unsigned build kan ook via:

```bash
xcodebuild -project Buie.xcodeproj -scheme Buie \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

`prepare_llama.sh` haalt de officiële llama.cpp-broncode op, configureert CMake voor iOS arm64, bouwt llama.cpp met Metal/Accelerate en combineert de statische bibliotheken tot één linkbare bibliotheek. De bridge wordt tegen headers uit exact die checkout gecompileerd.

## Codemagic

1. Push de volledige projectmap naar een Git-repository.
2. Voeg de repository toe in Codemagic.
3. Zorg dat `codemagic.yaml` in de repository-root staat.
4. Laat Codemagic de YAML-configuratie scannen.
5. Start `Buie iOS — unsigned device build`.

De workflow installeert CMake/XcodeGen, bouwt llama.cpp, genereert het Xcode-project en bouwt een unsigned Release-app. Het `.app`-artefact is voor buildcontrole en niet direct installeerbaar op een iPhone.

### Ondertekende IPA / TestFlight

Voor distributie moet je eigen Apple signing instellen:
1. Upload of genereer een Apple Distribution-certificaat in Codemagic.
2. Voeg het provisioning profile toe voor `com.jonnojohannes.buie`.
3. Configureer `ios_signing` in `codemagic.yaml`.
4. Voeg `xcode-project use-profiles` toe vóór de archive/build-stap.
5. Gebruik `xcode-project build-ipa` om een ondertekende IPA te maken.

Daarvoor is een Apple Developer-account nodig. Geen certificaten, wachtwoorden of private keys in Git opslaan.

## Buie gebruiken

1. Bewaar een `.gguf`-instructiemodel in Bestanden.
2. Open Buie en kies **Model importeren**.
3. Selecteer het GGUF-bestand. Buie kopieert het naar Application Support en laadt het lokaal.
4. Typ één softwareopdracht in het opdrachtveld.
5. Tik **Voer opdracht uit**.
6. De lokale engine genereert JSON met een `files`-array.
7. Buie parseert de JSON en valideert alle paden.
8. Buie schrijft ieder `content`-veld als afzonderlijk bestand in een ZIP-archief.
9. Tik **Exporteer de broncode als zip** en kies de bestemming in Bestanden.

## Uitvoerformaat

```json
{
  "files": [
    {"path": "Sources/App.swift", "content": "import SwiftUI\n..."},
    {"path": "README.md", "content": "# Project"}
  ]
}
```

De ZIP bevat afzonderlijke bestanden en behoudt de mappenstructuur; niet één tekstbestand met de complete AI-uitvoer.

## Model- en uitvoerlimieten

De huidige bridge gebruikt een context van 4096 tokens, een maximale generatie van 8192 tokens en een begrensde uitvoerbuffer van 16 MiB. Grote modellen kunnen meer RAM nodig hebben dan een iPhone beschikbaar heeft. Een te grote opdracht kan onvolledig worden.

De app voert gegenereerde code niet uit en compileert het gegenereerde project niet. Een succesvolle ZIP-export garandeert dus niet dat de gegenereerde software zonder aanpassingen bouwt.

## Belangrijke validatiepunten

Dit project kon hier niet met Xcode/iOS SDK worden gebouwd. Laat de eerste Codemagic-build de exacte API-compatibiliteit van de actuele llama.cpp checkout verifiëren. Na een geslaagde build moet de gebruikte llama.cpp commit in `prepare_llama.sh` worden vastgezet; de hoofdbranch kan later API-wijzigingen krijgen.

De bridge richt zich op fysieke iOS-apparaten (arm64). Simulator-builds vereisen een afzonderlijke llama.cpp build voor de iOS Simulator.
