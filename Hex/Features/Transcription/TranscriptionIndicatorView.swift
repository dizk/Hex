//
//  HexCapsuleView.swift
//  Hex
//
//  Created by Kit Langton on 1/25/25.

import Inject
import Pow
import SwiftUI

struct TranscriptionIndicatorView: View {
  @ObserveInjection var inject
  
  enum Status: Equatable {
    case hidden
    case optionKeyPressed
    case recording
    case transcribing
    case prewarming
    case commandSuccess
    case commandFailure

    // MARK: - Base color properties (testable, meter-independent)

    private static let transcribeBaseColor: Color = .blue

    /// The base background color for each status (without meter modulation).
    var baseBackgroundColor: Color {
      switch self {
      case .hidden: return Color.clear
      case .optionKeyPressed: return Color.black
      case .recording: return Color.red
      case .transcribing: return Self.transcribeBaseColor.mix(with: .black, by: 0.5)
      case .prewarming: return Self.transcribeBaseColor.mix(with: .black, by: 0.5)
      case .commandSuccess: return Color.green
      case .commandFailure: return Color.red
      }
    }

    /// The base stroke color for each status.
    var baseStrokeColor: Color {
      switch self {
      case .hidden: return Color.clear
      case .optionKeyPressed: return Color.black
      case .recording: return Color.red.mix(with: .white, by: 0.1).opacity(0.6)
      case .transcribing: return Self.transcribeBaseColor.mix(with: .white, by: 0.1).opacity(0.6)
      case .prewarming: return Self.transcribeBaseColor.mix(with: .white, by: 0.1).opacity(0.6)
      case .commandSuccess: return Color.green.mix(with: .white, by: 0.3)
      case .commandFailure: return Color.red.mix(with: .white, by: 0.3)
      }
    }

    /// The base inner shadow color for each status.
    var baseInnerShadowColor: Color {
      switch self {
      case .hidden: return Color.clear
      case .optionKeyPressed: return Color.clear
      case .recording: return Color.red
      case .transcribing: return Self.transcribeBaseColor
      case .prewarming: return Self.transcribeBaseColor
      case .commandSuccess: return Color.green.mix(with: .black, by: 0.3)
      case .commandFailure: return Color.red.mix(with: .black, by: 0.3)
      }
    }
  }

  var status: Status
  var meter: Meter

  /// Background color with meter modulation for recording; delegates to Status for all others.
  private var backgroundColor: Color {
    if status == .recording {
      return .red.mix(with: .black, by: 0.5).mix(with: .red, by: meter.averagePower * 3)
    }
    return status.baseBackgroundColor
  }

  private var strokeColor: Color { status.baseStrokeColor }
  private var innerShadowColor: Color { status.baseInnerShadowColor }

  private let cornerRadius: CGFloat = 8
  private let baseWidth: CGFloat = 16
  private let expandedWidth: CGFloat = 56

  var isHidden: Bool {
    status == .hidden
  }

  @State var transcribeEffect = 0
  @State var commandSuccessGlow = 0
  @State var commandFailureGlow = 0
  @State var failureFlashOpacity: Double = 1.0

  var body: some View {
    let averagePower = min(1, meter.averagePower * 3)
    let peakPower = min(1, meter.peakPower * 3)
    ZStack {
      Capsule()
        .fill(backgroundColor.shadow(.inner(color: innerShadowColor, radius: 4)))
        .overlay {
          Capsule()
            .stroke(strokeColor, lineWidth: 1)
            .blendMode(.screen)
        }
        .overlay(alignment: .center) {
          RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.red.opacity(status == .recording ? (averagePower < 0.1 ? averagePower / 0.1 : 1) : 0))
            .blur(radius: 2)
            .blendMode(.screen)
            .padding(6)
        }
        .overlay(alignment: .center) {
          RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.white.opacity(status == .recording ? (averagePower < 0.1 ? averagePower / 0.1 : 0.5) : 0))
            .blur(radius: 1)
            .blendMode(.screen)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(7)
        }
        .overlay(alignment: .center) {
          GeometryReader { proxy in
            RoundedRectangle(cornerRadius: cornerRadius)
              .fill(Color.red.opacity(status == .recording ? (peakPower < 0.1 ? (peakPower / 0.1) * 0.5 : 0.5) : 0))
              .frame(width: max(proxy.size.width * (peakPower + 0.6), 0), height: proxy.size.height, alignment: .center)
              .frame(maxWidth: .infinity, alignment: .center)
              .blur(radius: 4)
              .blendMode(.screen)
          }.padding(6)
        }
        .cornerRadius(cornerRadius)
        .shadow(
          color: status == .recording ? .red.opacity(averagePower) : .red.opacity(0),
          radius: 4
        )
        .shadow(
          color: status == .recording ? .red.opacity(averagePower * 0.5) : .red.opacity(0),
          radius: 8
        )
        .animation(.interactiveSpring(), value: meter)
        .frame(
          width: status == .recording ? expandedWidth : baseWidth,
          height: baseWidth
        )
        .opacity(status == .hidden ? 0 : (status == .commandFailure ? failureFlashOpacity : 1.0))
        .scaleEffect(status == .hidden ? 0.0 : 1)
        .blur(radius: status == .hidden ? 4 : 0)
        .animation(.bouncy(duration: 0.3), value: status)
        .changeEffect(.glow(color: .red.opacity(0.5), radius: 8), value: status == .recording)
        .changeEffect(.glow(color: .green, radius: 8), value: commandSuccessGlow)
        .changeEffect(.glow(color: .red, radius: 8), value: commandFailureGlow)
        .changeEffect(.shine(angle: .degrees(0), duration: 0.6), value: transcribeEffect)
        .compositingGroup()
        .task(id: status == .transcribing) {
          while status == .transcribing, !Task.isCancelled {
            transcribeEffect += 1
            try? await Task.sleep(for: .seconds(0.25))
          }
        }
        .task(id: status == .commandSuccess) {
          guard status == .commandSuccess else { return }
          commandSuccessGlow += 1
        }
        .task(id: status == .commandFailure) {
          guard status == .commandFailure, !Task.isCancelled else { return }
          commandFailureGlow += 1
          // Double-flash: toggle opacity off/on twice with ~150ms intervals
          for _ in 0..<2 {
            failureFlashOpacity = 0.0
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { break }
            failureFlashOpacity = 1.0
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { break }
          }
        }
      
      // Show tooltip when prewarming
      if status == .prewarming {
        VStack(spacing: 4) {
          Text("Model prewarming...")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
              RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.8))
            )
        }
        .offset(y: -24)
        .transition(.opacity)
        .zIndex(2)
      }
    }
    .enableInjection()
  }
}

#Preview("HEX") {
  VStack(spacing: 8) {
    TranscriptionIndicatorView(status: .hidden, meter: .init(averagePower: 0, peakPower: 0))
    TranscriptionIndicatorView(status: .optionKeyPressed, meter: .init(averagePower: 0, peakPower: 0))
    TranscriptionIndicatorView(status: .recording, meter: .init(averagePower: 0.5, peakPower: 0.5))
    TranscriptionIndicatorView(status: .transcribing, meter: .init(averagePower: 0, peakPower: 0))
    TranscriptionIndicatorView(status: .prewarming, meter: .init(averagePower: 0, peakPower: 0))
    TranscriptionIndicatorView(status: .commandSuccess, meter: .init(averagePower: 0, peakPower: 0))
    TranscriptionIndicatorView(status: .commandFailure, meter: .init(averagePower: 0, peakPower: 0))
  }
  .padding(40)
}
