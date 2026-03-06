# Hex — Voice to Text

A macOS menu bar app for on-device voice-to-text. Press a hotkey, speak, and the transcription is pasted wherever you're typing. Everything runs locally — no cloud, no latency.

## Features

- On-device transcription via [Parakeet TDT v3](https://github.com/FluidInference/FluidAudio) (default, multilingual) and [WhisperKit](https://github.com/argmaxinc/WhisperKit)
- **Press-and-hold** a hotkey to record, release to transcribe
- **Double-tap** to lock recording, tap again to stop
- Auto-paste into the active application
- Multiple model sizes (Tiny through Large)
- Apple Silicon native

## Install

**[Download the latest DMG](https://hex-updates.s3.us-east-1.amazonaws.com/hex-latest.dmg)**

Or via Homebrew:
```bash
brew install --cask kitlangton-hex
```

## Usage

1. Grant microphone and accessibility permissions when prompted
2. Configure a global hotkey in Settings
3. **Press-and-hold** the hotkey to record, release to transcribe and paste
4. **Double-tap** the hotkey to lock recording, tap once more to stop

## Building

Requires macOS 14+, Xcode 15+, Apple Silicon.

```bash
open Hex.xcodeproj
# Or from the command line:
xcodebuild -scheme Hex -configuration Debug -skipMacroValidation
```

Unit tests:
```bash
cd HexCore && swift test
```

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Attribution

This is a fork of [kitlangton/Hex](https://github.com/kitlangton/Hex), originally created by [Kit Langton](https://github.com/kitlangton).

Copyright (c) 2025 Kit Langton
