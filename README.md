# Hex — Voice to Text

A macOS menu bar app for on-device voice-to-text. Press a hotkey, speak, and the transcription is pasted wherever you're typing. Everything runs locally — no cloud, no latency.

## Features

- On-device transcription via [Parakeet TDT v3](https://github.com/FluidInference/FluidAudio) (default, multilingual) and [WhisperKit](https://github.com/argmaxinc/WhisperKit)
- **Press-and-hold** a hotkey to record, release to transcribe
- **Double-tap** to lock recording, tap again to stop
- Auto-paste into the active application
- Multiple model sizes (Tiny through Large)
- Apple Silicon native

## Building

Requires macOS 14+, Xcode 15+, Apple Silicon.

1. Clone the repository
2. Open `Hex.xcodeproj` in Xcode
3. Select the **Hex** scheme and your Mac as the run destination
4. Build and run (`Cmd+R`)

From the command line:
```bash
xcodebuild -scheme Hex -configuration Debug -skipMacroValidation
```

Unit tests:
```bash
cd HexCore && swift test
```

## Usage

1. Grant microphone and accessibility permissions when prompted
2. Configure a global hotkey in Settings
3. **Press-and-hold** the hotkey to record, release to transcribe and paste
4. **Double-tap** the hotkey to lock recording, tap once more to stop

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Attribution

This is a fork of [kitlangton/Hex](https://github.com/kitlangton/Hex), originally created by [Kit Langton](https://github.com/kitlangton).

Copyright (c) 2025 Kit Langton
