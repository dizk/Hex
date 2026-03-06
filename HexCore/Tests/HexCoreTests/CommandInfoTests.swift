import Foundation
import Testing
@testable import HexCore

struct CommandInfoTests {

    // MARK: - CommandInfo round-trip encoding

    @Test
    func commandInfo_roundTrips_allFieldsPopulated() throws {
        let info = CommandInfo(
            rawInput: "switch to chrome",
            actionDescription: "Switched to Google Chrome",
            success: true,
            targetAppBundleID: "com.google.Chrome",
            targetAppName: "Google Chrome"
        )
        let data = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(CommandInfo.self, from: data)
        #expect(decoded == info)
    }

    @Test
    func commandInfo_roundTrips_nilOptionalFields() throws {
        let info = CommandInfo(
            rawInput: "switch to foobar",
            actionDescription: "No matching window found",
            success: false,
            targetAppBundleID: nil,
            targetAppName: nil
        )
        let data = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(CommandInfo.self, from: data)
        #expect(decoded == info)
        #expect(decoded.targetAppBundleID == nil)
        #expect(decoded.targetAppName == nil)
    }

    // MARK: - Transcript backward compatibility

    @Test
    func transcript_roundTrips_withNilCommandInfo() throws {
        let transcript = Transcript(
            timestamp: Date(timeIntervalSince1970: 1000),
            text: "hello world",
            audioPath: URL(fileURLWithPath: "/tmp/audio.m4a"),
            duration: 2.5
        )
        let data = try JSONEncoder().encode(transcript)
        let decoded = try JSONDecoder().decode(Transcript.self, from: data)
        #expect(decoded.commandInfo == nil)
        #expect(decoded.text == "hello world")
    }

    @Test
    func transcript_decodesWithoutCommandInfoKey_backwardCompat() throws {
        // Simulate persisted JSON that was saved before commandInfo existed
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789ABC",
            "timestamp": 1000,
            "text": "old transcript",
            "audioPath": "file:///tmp/audio.m4a",
            "duration": 3.0
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Transcript.self, from: json)
        #expect(decoded.commandInfo == nil)
        #expect(decoded.text == "old transcript")
    }

    @Test
    func transcript_roundTrips_withPopulatedCommandInfo() throws {
        let info = CommandInfo(
            rawInput: "switch to safari",
            actionDescription: "Switched to Safari",
            success: true,
            targetAppBundleID: "com.apple.Safari",
            targetAppName: "Safari"
        )
        let transcript = Transcript(
            timestamp: Date(timeIntervalSince1970: 2000),
            text: "switch to safari",
            audioPath: URL(fileURLWithPath: "/tmp/audio2.m4a"),
            duration: 1.5,
            commandInfo: info
        )
        let data = try JSONEncoder().encode(transcript)
        let decoded = try JSONDecoder().decode(Transcript.self, from: data)
        #expect(decoded.commandInfo == info)
        #expect(decoded.commandInfo?.success == true)
        #expect(decoded.commandInfo?.targetAppBundleID == "com.apple.Safari")
    }

    // MARK: - isCommand computed property

    @Test
    func isCommand_returnsTrue_whenCommandInfoIsSet() {
        let transcript = Transcript(
            timestamp: Date(),
            text: "switch to chrome",
            audioPath: URL(fileURLWithPath: "/tmp/a.m4a"),
            duration: 1.0,
            commandInfo: CommandInfo(
                rawInput: "switch to chrome",
                actionDescription: "Switched to Google Chrome",
                success: true,
                targetAppBundleID: "com.google.Chrome",
                targetAppName: "Google Chrome"
            )
        )
        #expect(transcript.isCommand == true)
    }

    @Test
    func isCommand_returnsFalse_whenCommandInfoIsNil() {
        let transcript = Transcript(
            timestamp: Date(),
            text: "hello world",
            audioPath: URL(fileURLWithPath: "/tmp/a.m4a"),
            duration: 1.0
        )
        #expect(transcript.isCommand == false)
    }
}
