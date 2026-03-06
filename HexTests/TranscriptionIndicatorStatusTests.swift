//
//  TranscriptionIndicatorStatusTests.swift
//  HexTests
//
//  Tests for the TranscriptionIndicatorView.Status enum, verifying
//  color properties for command feedback states and regression-checking
//  existing statuses.
//

import SwiftUI
import Testing
@testable import Hex

// MARK: - TranscriptionIndicatorView.Status Color Tests

@MainActor
struct TranscriptionIndicatorStatusTests {

    typealias Status = TranscriptionIndicatorView.Status

    // MARK: - commandSuccess colors

    @Test
    func commandSuccess_backgroundColor_isGreen() {
        let status = Status.commandSuccess
        #expect(status.baseBackgroundColor == Color.green)
    }

    @Test
    func commandSuccess_strokeColor_isGreenMixedWithWhite() {
        let status = Status.commandSuccess
        let expected = Color.green.mix(with: .white, by: 0.3)
        #expect(status.baseStrokeColor == expected)
    }

    @Test
    func commandSuccess_innerShadowColor_isGreenMixedWithBlack() {
        let status = Status.commandSuccess
        let expected = Color.green.mix(with: .black, by: 0.3)
        #expect(status.baseInnerShadowColor == expected)
    }

    // MARK: - commandFailure colors

    @Test
    func commandFailure_backgroundColor_isRed() {
        let status = Status.commandFailure
        #expect(status.baseBackgroundColor == Color.red)
    }

    @Test
    func commandFailure_strokeColor_isRedMixedWithWhite() {
        let status = Status.commandFailure
        let expected = Color.red.mix(with: .white, by: 0.3)
        #expect(status.baseStrokeColor == expected)
    }

    @Test
    func commandFailure_innerShadowColor_isRedMixedWithBlack() {
        let status = Status.commandFailure
        let expected = Color.red.mix(with: .black, by: 0.3)
        #expect(status.baseInnerShadowColor == expected)
    }

    // MARK: - Visibility: command statuses are not hidden

    @Test
    func commandSuccess_isNotHidden() {
        let status = Status.commandSuccess
        #expect(status != .hidden)
    }

    @Test
    func commandFailure_isNotHidden() {
        let status = Status.commandFailure
        #expect(status != .hidden)
    }

    // MARK: - Regression: existing statuses retain their colors

    @Test
    func recording_backgroundColor_isRed() {
        let status = Status.recording
        #expect(status.baseBackgroundColor == Color.red)
    }

    @Test
    func recording_strokeColor_isRedMixedWithWhite() {
        let status = Status.recording
        // Recording's base stroke uses mix(with: .white, by: 0.1) with 0.6 opacity
        let expected = Color.red.mix(with: .white, by: 0.1).opacity(0.6)
        #expect(status.baseStrokeColor == expected)
    }

    @Test
    func recording_innerShadowColor_isRed() {
        let status = Status.recording
        #expect(status.baseInnerShadowColor == Color.red)
    }

    @Test
    func transcribing_backgroundColor_isBlue() {
        let status = Status.transcribing
        let transcribeBaseColor = Color.blue
        let expected = transcribeBaseColor.mix(with: .black, by: 0.5)
        #expect(status.baseBackgroundColor == expected)
    }

    @Test
    func transcribing_strokeColor_isBlueMixedWithWhite() {
        let status = Status.transcribing
        let transcribeBaseColor = Color.blue
        let expected = transcribeBaseColor.mix(with: .white, by: 0.1).opacity(0.6)
        #expect(status.baseStrokeColor == expected)
    }

    @Test
    func transcribing_innerShadowColor_isBlue() {
        let status = Status.transcribing
        #expect(status.baseInnerShadowColor == Color.blue)
    }

    @Test
    func hidden_returnsAllClearColors() {
        let status = Status.hidden
        #expect(status.baseBackgroundColor == Color.clear)
        #expect(status.baseStrokeColor == Color.clear)
        #expect(status.baseInnerShadowColor == Color.clear)
    }
}
