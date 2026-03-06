# Research: Voice Commands

**Date:** 2026-03-06
**Based on:** BRAINSTORM.md
**Status:** Ready for alignment
**Feature:** voice-commands

## Findings

### 1. macOS Window Listing APIs

**Question:** How does macOS expose the list of all open windows (titles, app names, window IDs)? What APIs or accessibility frameworks are needed? Does the sandbox allow this?

**Finding:** Two complementary APIs exist:

1. **CGWindowListCopyWindowInfo** (Core Graphics) -- Enumerates all windows in a single call, returning owner name, PID, window ID, bounds, and layer. However, `kCGWindowName` (window title) is **only populated if the app has Screen Recording permission** (since macOS Catalina 10.15). On Sequoia (15), Screen Recording prompts users for monthly re-confirmation. Without Screen Recording, you get everything except titles.

2. **Accessibility API (AXUIElement)** -- `AXUIElementCreateApplication(pid)` + `kAXWindowsAttribute` enumerates an app's windows. `kAXTitleAttribute` returns window titles. This only requires **Accessibility permission**, which Hex already has. Does NOT require Screen Recording. This is the better path.

Hex already uses AXUIElement APIs in production (`PasteboardClient.swift` for text insertion, `KeyEventMonitorClient.swift` for event taps) while sandboxed with Accessibility permission. The "sandbox blocks all accessibility" narrative from Apple forums appears to apply specifically to Mac App Store distribution, not Developer ID-signed apps like Hex.

**Sources:**
- [CGWindowListCopyWindowInfo -- Apple Developer Docs](https://developer.apple.com/documentation/coregraphics/1455137-cgwindowlistcopywindowinfo)
- [kAXWindowsAttribute -- Apple Developer Docs](https://developer.apple.com/documentation/applicationservices/kaxwindowsattribute)
- [alt-tab-macos AXUIElement.swift](https://github.com/lwouis/alt-tab-macos/blob/master/src/api-wrappers/AXUIElement.swift)
- [Screen Recording Permissions in Catalina](https://www.ryanthomson.net/articles/screen-recording-permissions-catalina-mess/)
- Hex codebase: `Hex/Clients/PasteboardClient.swift` (lines 350-379), `Hex/Clients/KeyEventMonitorClient.swift` (lines 497-505)

**Recommendation:** Use AXUIElement exclusively for window enumeration and title reading. Iterate `NSWorkspace.shared.runningApplications` (filtering to `.activationPolicy == .regular`), create an AXUIElement per PID, and read `kAXWindowsAttribute` + `kAXTitleAttribute`. No new permissions needed.

**Risk:** Apple's official position is that sandbox blocks AX APIs. Hex works today, but Apple could tighten enforcement. Since Hex distributes outside the App Store, removing sandbox is always a fallback. AX enumeration is synchronous and can take 50-200ms with many apps -- cache the window list and build it on a background thread.

### 2. Local Small LLMs for Command Detection and Window Matching

**Question:** What local small LLMs are suitable for command detection and window matching?

**Finding:** Six model families were evaluated for the task of taking a short transcription + window title list and determining (a) if it's a command and (b) which window matches:

| Model | Params | 4-bit Size | RAM | MLX Available | License |
|---|---|---|---|---|---|
| Qwen3-0.6B | 0.6B | ~397MB | ~600-800MB | Yes | Apache 2.0 |
| Qwen3.5-0.8B | 0.8B | ~500MB | ~2GB | Yes (8-bit) | Apache 2.0 |
| Gemma 3 1B | 1B | ~600MB | ~2GB | Yes | Apache 2.0 |
| SmolLM2-1.7B | 1.7B | ~1GB | ~2-3GB | Yes | Apache 2.0 |
| Qwen3.5-2B | 2B | ~1.2GB | ~2GB | Yes | Apache 2.0 |
| Phi-4-mini | 3.8B | ~2.3GB | ~4GB | Yes | MIT |

Key context: Community consensus is sub-3B models are "mediocre" for general tasks, but this is a **narrow classification + fuzzy match task** (~50 tokens input, ~5 tokens output), not open-ended generation. Sub-1B models can handle it.

An existing open-source project **Talker** (github.com/john-m24/talker) does nearly exactly what Hex wants -- voice-controlled window management on macOS using a local LLM. It uses Ollama with Qwen-30B (much larger than needed) and AppleScript for window control. This validates the approach but Hex's narrower scope (only window focusing) means a much smaller model suffices.

Apple's Foundation Models framework (macOS 26+) would be ideal long-term -- ~3B on-device model, free, native structured output via `@Generable` macro -- but requires macOS 26 which isn't widely available yet.

**Sources:**
- [Qwen3.5 GitHub](https://github.com/QwenLM/Qwen3.5)
- [mlx-community/Qwen3.5-0.8B-MLX-8bit](https://huggingface.co/mlx-community/Qwen3.5-0.8B-MLX-8bit)
- [Qwen3-0.6B-MLX-4bit](https://huggingface.co/Qwen/Qwen3-0.6B-MLX-4bit)
- [Phi-4-mini (arXiv)](https://arxiv.org/abs/2503.01743)
- [Talker (GitHub)](https://github.com/john-m24/talker)
- [Apple Foundation Models](https://developer.apple.com/documentation/FoundationModels)
- [On-Device LLMs for Intent Detection (arXiv)](https://arxiv.org/abs/2502.12923)

**Recommendation:** Use **Qwen3-0.6B-4bit** as the primary model. It's the smallest viable option (~397MB, ~600-800MB RAM), has MLX-optimized variants on HuggingFace, and Apache 2.0 licensed. If quality is insufficient, step up to Qwen3.5-0.8B or Qwen3.5-2B. However, the LLM should be a **fallback behind heuristic + fuzzy matching** (see Finding 5), not the primary path.

**Risk:** (1) Cold start: first model load takes 1-5 seconds. Mitigate by pre-loading at app launch. (2) Quality: a 0.6B model may struggle with semantic leaps like "my email" -> "Gmail". Build the architecture so the model is swappable. (3) RAM: running Whisper/Parakeet + LLM simultaneously means ~1.2-2GB of ML models. May cause pressure on 8GB Macs. (4) Download size: ~400MB additional download. Use the existing ModelDownloadFeature pattern.

### 3. Local LLM Inference Frameworks for macOS

**Question:** How to run a small local LLM on macOS efficiently? What frameworks exist?

**Finding:** Four frameworks evaluated:

**MLX Swift (recommended):** Apple's own ML framework for Apple Silicon. `mlx-swift-lm` package provides a ready-to-use Swift API. Performance: 80-120+ tok/s on M1/M2 for 0.6B 4-bit, up to 525 tok/s on M4 Max. Clean SPM integration, no C++ interop. WWDC 2025 featured it prominently. Uses Metal for GPU -- works within sandbox (Hex already uses Metal via WhisperKit/FluidAudio). Model ecosystem: large `mlx-community` on HuggingFace with pre-quantized models.

**llama.cpp:** Most widely-used C/C++ inference engine. Swift package available but uses `unsafeFlags` (SPM friction). ~30-50% slower than MLX on Apple Silicon. Known App Store symbol issue (#3438). Massive community and GGUF model ecosystem.

**Core ML conversion:** Native Apple framework, fully sandbox-compatible. But requires non-trivial Python conversion pipeline (coremltools). Fewer pre-converted LLM models available. More manual work.

**Apple Foundation Models (macOS 26+):** Simplest API (3 lines of code), free, native structured output. But requires macOS 26, only Apple's built-in model (no custom models), not yet widely available.

For a warm Qwen3-0.6B-4bit model on any M-series Mac: ~50ms prompt processing (200 tokens) + ~500ms generation (50 tokens) = **well under 1 second total inference**.

**Sources:**
- [mlx-swift-lm (GitHub)](https://github.com/ml-explore/mlx-swift-lm)
- [WWDC25: Explore LLMs on Apple Silicon with MLX](https://developer.apple.com/videos/play/wwdc2025/298/)
- [Production-Grade Local LLM on Apple Silicon (arXiv 2511.05502)](https://arxiv.org/abs/2511.05502)
- [llama.cpp Swift Package Index](https://swiftpackageindex.com/ggml-org/llama.cpp)
- [llama.cpp App Store issue #3438](https://github.com/ggml-org/llama.cpp/issues/3438)
- [Apple Core ML On-Device Llama](https://machinelearning.apple.com/research/core-ml-on-device-llama)

**Recommendation:** Use **MLX Swift** (`mlx-swift-lm`). It's Apple-native, highest performance on Apple Silicon, clean Swift integration, and aligns with Hex's existing Apple-ecosystem ML tools. Load the model at app launch and keep it warm to avoid cold-start latency.

**Risk:** (1) MLX Swift is still evolving -- pin to a specific version. (2) Cold start 1-5 seconds for first load. (3) Memory pressure with multiple ML models loaded. (4) Metal shader compilation behavior in sandbox should be tested early (likely fine since WhisperKit/FluidAudio already use Metal).

### 4. macOS Window Focusing APIs

**Question:** How to bring a specific window to the front on macOS programmatically, especially for a specific window within a multi-window app?

**Finding:** The proven algorithm, used by AltTab, Hammerspoon, Rectangle, and mac-focus-window:

1. Get the target app's PID
2. `AXUIElementCreateApplication(pid)` to create an app reference
3. Read `kAXWindowsAttribute` to enumerate windows
4. Read `kAXTitleAttribute` on each window to get its title
5. Match the desired window (fuzzy match)
6. **`AXUIElementPerformAction(window, kAXRaiseAction)`** -- raises that specific window within the app's stack
7. **`NSRunningApplication(processIdentifier: pid)?.activate(options: .activateIgnoringOtherApps)`** -- brings the app in front of other apps

**Order matters:** perform `kAXRaiseAction` first, THEN `activate`. This combination reliably brings a specific window to the absolute front.

`NSRunningApplication.activate()` alone only activates the app (OS picks which window). `kAXRaiseAction` is what enables window-level targeting.

AppleScript (`perform action "AXRaise" of window`) achieves the same result but with higher overhead. Native AXUIElement calls are faster.

**Sources:**
- [kAXRaiseAction -- Apple Developer Docs](https://developer.apple.com/documentation/applicationservices/kaxraiseaction)
- [AltTab GitHub issue #62](https://github.com/lwouis/alt-tab-macos/issues/62)
- [Hammerspoon libwindow.m](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/window/libwindow.m)
- [Rectangle AccessibilityElement.swift](https://github.com/rxhanson/Rectangle/blob/main/Rectangle/AccessibilityElement.swift)
- [mac-focus-window (GitHub)](https://github.com/karaggeorge/mac-focus-window)

**Recommendation:** Use native AXUIElement API with the `kAXRaiseAction` + `activate()` pattern. Hex already uses AXUIElement in PasteboardClient -- extend that same approach. Build a `WindowClient` TCA dependency that wraps this.

**Risk:** (1) Some apps don't expose proper window titles via AX (e.g., some Electron apps). Combine app name with title for matching. (2) Enumeration takes 50-200ms with many apps -- do it on a background thread, triggered when recording starts. (3) Multiple windows with similar titles need tie-breaking (e.g., prefer most recently focused).

### 5. Command Detection Approach

**Question:** Should the same model handle both "is this a command?" and "which window?" or should command detection be a simpler heuristic?

**Finding:** Research strongly favors a **tiered hybrid approach**:

**Tier 1 -- Heuristic command detection (sub-millisecond):** Check if the transcription starts with trigger prefixes: "switch to", "go to", "open", "focus", "bring up", "show", "show me". Also check length (commands tend to be under ~10 words). This catches 80-90% of commands with zero latency. The existing `ForceQuitCommandDetector` in `TranscriptionFeature.swift` (lines 587-600) uses this exact pattern.

**Tier 2 -- Fuzzy string matching (sub-millisecond):** Extract the target from the command ("switch to **huddle**") and run token-based fuzzy matching (partial ratio / token set ratio) against window titles. "Huddle" matches "Slack | Huddle with Kit" at high confidence. Swift library available: [Fuzzywuzzy_swift](https://github.com/lxian/Fuzzywuzzy_swift). A minimum score threshold (50-60) prevents false matches.

**Tier 3 -- Small LLM (200-600ms, only when Tier 2 fails):** For semantic leaps where fuzzy matching fails (e.g., "my email" -> "Chrome -- Gmail"), invoke the local LLM. This is the only case where a model adds value.

This mirrors production voice systems: Home Assistant uses template matching for fast commands and only falls back to LLM for complex queries. Rhasspy uses finite state transducers for millisecond-scale matching. Talon Voice uses word-based regex rules, not ML.

**Sources:**
- [Home Assistant Voice Chapter 10](https://www.home-assistant.io/blog/2025/06/25/voice-chapter-10/)
- [Rhasspy Intent Recognition](https://rhasspy.readthedocs.io/en/latest/intent-recognition/)
- [Voiceflow Hybrid LLM Classification](https://www.voiceflow.com/pathways/benchmarking-hybrid-llm-classification-systems)
- [Talon Voice Documentation](https://talonvoice.com/docs/)
- [Fuzzywuzzy_swift (GitHub)](https://github.com/lxian/Fuzzywuzzy_swift)
- Hex codebase: `Hex/Features/Transcription/TranscriptionFeature.swift` lines 587-600 (ForceQuitCommandDetector)

**Recommendation:** Implement the tiered approach. Start with Tier 1 + Tier 2 only (heuristic + fuzzy matching). Ship it, gather real usage data, then add Tier 3 (LLM) only if users report unmatched commands that fuzzy matching can't handle. This keeps the initial implementation simple (~100-150 lines of Swift) with zero model dependencies.

**Risk:** (1) Trigger phrase coverage gaps -- users who say "huddle" without a prefix won't be detected. Mitigate with a short-utterance heuristic (1-3 words might be a command candidate). (2) Transcription artifacts -- Whisper/Parakeet may add punctuation or filler words. The normalizer must strip these. (3) Homophone issues -- "switch two" instead of "switch to". Include common misrecognitions.

### 6. Fast API Fallback Services

**Question:** What fast API services would work as a fallback if local models aren't good enough?

**Finding:** Six providers benchmarked for short classification prompts (~200-500 input tokens, ~50 output tokens):

| Provider | Model | TTFT | Est. Total (50 tok) | Price/req | Structured Output | Under 500ms? |
|---|---|---|---|---|---|---|
| **Groq** | Llama 3.1 8B | ~100-130ms | **200-400ms** | ~$0.00003 | Yes (strict JSON) | **Yes** |
| **Cerebras** | Llama 3.1 8B | ~170-240ms | **300-450ms** | ~$0.00006 | Yes | **Likely** |
| Fireworks | Llama 3.1 8B | ~420ms | ~500-600ms | ~$0.00005 | Yes | Borderline |
| OpenAI | GPT-4.1 nano | ~560ms | ~700-1000ms | ~$0.00007 | Yes (best tooling) | No |
| xAI | Grok 4.1 Fast | ~660ms | ~800-1200ms | ~$0.00013 | Yes | No |
| Anthropic | Haiku 4.5 | ~690ms | ~800-1100ms | ~$0.00075 | Yes | No |

**Note:** The brainstorm mentions "Grok" (xAI's model) but **Groq** (the fast inference company running open-source models on custom LPU hardware) is the much better fit. This may have been a naming confusion.

Privacy consideration: Window titles can contain sensitive information (document names, email subjects, Slack channel names). The API fallback should be opt-in with a clear disclosure.

**Sources:**
- [Groq Pricing](https://groq.com/pricing)
- [Cerebras Pricing](https://www.cerebras.ai/pricing)
- [Artificial Analysis -- Provider Benchmarks](https://artificialanalysis.ai/providers/groq)
- [xAI Models and Pricing](https://docs.x.ai/developers/models)
- [OpenAI Pricing](https://developers.openai.com/api/docs/pricing)

**Recommendation:** Use **Groq** as the primary API fallback (Llama 3.1 8B with structured JSON output). It's the only provider that reliably hits under 500ms total for short prompts, and costs ~$0.00003/request ($1/year at 100 commands/day). Use OpenAI-compatible API format so swapping providers is trivial. Keep **Cerebras** as a secondary fallback. Make the API path opt-in in Settings with privacy disclosure.

**Risk:** (1) P95/P99 latency spikes on Groq during peak usage -- set a 500ms timeout and fall back to simple substring matching. (2) Free tier rate limits -- require users to bring their own key or use a Hex proxy. (3) Privacy -- window titles leak information. Local-first approach is essential. (4) Provider stability -- Groq and Cerebras are young companies.

### 7. Permissions and Entitlements for Window Management

**Question:** What entitlements/permissions does Hex need for window management? Does accessibility access need to be granted?

**Finding:** **No new permissions or entitlements are needed.** Hex's current configuration already supports window management:

- **Accessibility permission** (already granted by users): Required for AXUIElement window enumeration and `kAXRaiseAction`. Hex already uses `AXIsProcessTrustedWithOptions`, `AXUIElementCreateSystemWide()`, and `AXUIElementCopyAttributeValue` in production.
- **automation.apple-events entitlement** (already in entitlements): Enables AppleScript/System Events as a fallback path.
- **Sandbox** (currently enabled): Works in practice for Developer ID-signed apps, though Apple's official position says it shouldn't. Hex already demonstrates this works.
- **Screen Recording** (NOT needed): Only required for `kCGWindowName` via CGWindowListCopyWindowInfo. The AXUIElement path gets window titles without it.

Hex's existing permission flow (prompt for Accessibility on first launch, poll for trust status) covers everything needed for voice commands.

**Sources:**
- `Hex/Hex.entitlements` -- current entitlements
- `Hex/Clients/KeyEventMonitorClient.swift` -- existing AXIsProcessTrustedWithOptions usage
- `Hex/Clients/PasteboardClient.swift` -- existing AXUIElement and AppleScript usage
- `HexCore/Sources/HexCore/PermissionClient/PermissionClient+Live.swift` -- permission management
- [Apple Developer Forums thread 810677](https://developer.apple.com/forums/thread/810677)
- [Apple Developer Forums thread 707680](https://developer.apple.com/forums/thread/707680)
- [Accessibility Permission in macOS (jano.dev)](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html)

**Recommendation:** Proceed with no entitlement changes. Use the Accessibility API (AXUIElement) for window listing and focusing. The existing permission is sufficient.

**Risk:** (1) Sandbox + Accessibility is in a gray zone. Apple could tighten enforcement in future macOS. Removing sandbox is always a fallback for Developer ID apps. (2) If Apple breaks this, the AppleScript/System Events path would likely break equally since it also relies on accessibility trust.

## Cross-Verification Notes

**Agreements across agents:**
- Agents 1, 4, and 7 independently agree: Use AXUIElement (not CGWindowListCopyWindowInfo) to avoid needing Screen Recording permission. All three confirm Hex's existing Accessibility permission is sufficient.
- Agents 2, 3, and 5 independently converge on a tiered approach where heuristic + fuzzy matching handles most cases, with LLM as a fallback for semantic matching.
- Agents 2 and 3 both recommend MLX Swift as the inference framework.

**Contradiction -- model size:** Agent 2 recommends Qwen3.5-0.8B; Agent 3 recommends Qwen3-0.6B. These are different model families (Qwen 3.5 vs Qwen 3). Qwen3-0.6B is smaller and faster; Qwen3.5-0.8B is newer (March 2026) with potentially better instruction following. Both are viable -- start with 0.6B for minimum footprint, upgrade if quality is insufficient.

**Contradiction -- AXUIElement vs AppleScript:** Agent 4 recommends native AXUIElement API; Agent 7 recommends AppleScript/System Events. Both achieve the same result. Native AXUIElement is faster (direct API calls vs spawning AppleScript). Since Hex already uses AXUIElement in PasteboardClient, extending that pattern is more consistent. AppleScript can serve as a fallback.

## Ecosystem Conflicts

| Brainstorm says | Research shows | Impact |
|----------------|---------------|--------|
| "Use a model for command-to-window matching" (Key Decision) | Fuzzy string matching (token set ratio / partial ratio) handles most window matching without any model. "Huddle" matches "Slack \| Huddle with Kit" via substring. A model is only needed for semantic leaps like "my email" -> "Gmail". | The model should be a fallback behind heuristic + fuzzy matching, not the primary matching mechanism. This significantly reduces complexity and eliminates the model dependency for most commands. |
| "Try local small LLM first, API as fallback" (Key Decision) | The local LLM itself should be a fallback behind heuristic + fuzzy matching. The cascade should be: heuristic -> fuzzy match -> local LLM -> API. Most commands will resolve at the fuzzy match layer without ever touching a model. | Adds a layer to the architecture but makes the common path much faster (sub-millisecond vs 200-600ms) and eliminates model download/loading for users who never need semantic matching. |
| Mentions "Grok" as API fallback | "Grok" is xAI's model (660ms TTFT, too slow). "Groq" (different company, LPU hardware) is the fast inference provider (100-130ms TTFT). Likely a naming confusion. | Use Groq, not Grok, for the API fallback. |

## Recommendations Summary

1. **Use AXUIElement for all window operations** -- no new permissions needed, Hex already has Accessibility access. Use `kAXRaiseAction` + `NSRunningApplication.activate()` for window focusing. This is the proven pattern used by AltTab, Hammerspoon, and Rectangle.

2. **Implement a tiered command pipeline: heuristic -> fuzzy match -> (optional) LLM -> (optional) API** -- Start by shipping only tiers 1-2 (heuristic prefix detection + fuzzy string matching). This handles the majority of use cases in sub-millisecond time with zero dependencies. Add the LLM tier only if real usage reveals unmatched semantic commands.

3. **Use MLX Swift with Qwen3-0.6B-4bit if/when an LLM tier is needed** -- Apple-native, best performance on Apple Silicon, clean Swift integration, ~397MB download, ~600-800MB RAM. Pre-load at app launch to avoid cold-start latency.

4. **Use Groq as the API fallback** -- Only provider that reliably hits <500ms for short prompts. ~$0.00003/request. Make it opt-in with privacy disclosure about window title transmission.

5. **Build window enumeration into a cacheable snapshot** -- Enumerate windows via AXUIElement on a background thread when recording starts, so results are ready by the time transcription completes. Cache and refresh periodically rather than querying per-command.

6. **Follow the existing ForceQuitCommandDetector pattern** -- The codebase already has a command detection heuristic at `TranscriptionFeature.swift:587-600`. The window-switching command detector should follow the same architectural pattern for consistency.

7. **Plan for Apple Foundation Models (macOS 26+) as a future migration path** -- When macOS 26 adoption is widespread, the built-in ~3B on-device model with native structured output could replace the bundled Qwen model entirely, eliminating download/RAM overhead.

---
*Research completed: 2026-03-06*
