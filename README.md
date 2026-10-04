# Feynman Diagrams

An interactive SwiftUI app for learning to read Feynman diagrams, for macOS, iPhone and iPad.

- **Learn**: what the diagrams mean, the line styles for each particle, and a rotatable QED vertex.
- **Processes**: ten real processes (e⁺e⁻ → μ⁺μ⁻, Compton scattering, β decay, Higgs → γγ, …). Click any line or vertex to see its Feynman rule, and drag a time slice to see which particles exist at each moment.
- **Orders & loops** and a **quiz**.
- **Diagram Builder Game**: a puzzle. Build a valid Feynman diagram for each process, with the fewest vertices for three stars.
- **Ask Claude** (⌘K): questions about the page you're on, answered by Claude with the page's contents as context.
- **Find** (⌘F) on any page.

## Run on macOS

Requires macOS 14 or later and a recent Xcode for the Swift toolchain. It's built and tested with Xcode 27.

```sh
swift run
```

You can also open `Package.swift` in Xcode and press Run.

## Run on iPhone or iPad

Requires iOS 17 or later. Tested with Xcode 27 and the iOS 27 simulator.

1. Open `FeynmanDemo.xcodeproj` in Xcode.
2. Pick the **FeynmanDiagrams-iOS** scheme and a simulator or your device.
3. Press Run.

To run on your own device, select your team under **Signing & Capabilities**, and change the bundle ID (`com.issactrotts.FeynmanDiagrams` in `project.yml`) if Xcode says it's taken.

If you don't have a simulator, install one from **Xcode → Settings → Components**, or run `xcodebuild -downloadPlatform iOS`.

## Tests

```sh
swift test
```

The tests cover the Diagram Builder Game's physics rules (vertex types, fermion arrows, charge and flavor conservation).

## Ask Claude

Ask Claude needs an [Anthropic API key](https://console.anthropic.com/).

- **macOS**: set `ANTHROPIC_API_KEY` in the environment before `swift run`, or enter a key in **Settings** (⌘,). Settings stores it in your keychain.
- **iOS**: open the Ask panel and tap the key button.

Conversations are saved per page in `~/Library/Application Support/FeynmanDemo/conversations.json` (inside the app's container on iOS) and restored on launch.

## Project layout

- `Sources/FeynmanDemo/`: all the app code, shared by both platforms.
- `Package.swift`: builds the macOS app with SwiftPM.
- `Tools/MakeIcon.swift`: draws the app icon. Run `swift Tools/MakeIcon.swift` to regenerate both the iOS and macOS versions.
- `project.yml`: generates `FeynmanDemo.xcodeproj` for iOS with [XcodeGen](https://github.com/yonaskolb/XcodeGen). After adding or removing source files, run:

  ```sh
  brew install xcodegen   # once
  xcodegen
  ```
