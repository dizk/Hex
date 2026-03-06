import Foundation

public struct CommandInfo: Codable, Equatable, Sendable {
    public var rawInput: String
    public var actionDescription: String
    public var success: Bool
    public var targetAppBundleID: String?
    public var targetAppName: String?

    public init(
        rawInput: String,
        actionDescription: String,
        success: Bool,
        targetAppBundleID: String? = nil,
        targetAppName: String? = nil
    ) {
        self.rawInput = rawInput
        self.actionDescription = actionDescription
        self.success = success
        self.targetAppBundleID = targetAppBundleID
        self.targetAppName = targetAppName
    }
}

public struct Transcript: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var timestamp: Date
    public var text: String
    public var audioPath: URL
    public var duration: TimeInterval
    public var sourceAppBundleID: String?
    public var sourceAppName: String?
    public var commandInfo: CommandInfo?

    public var isCommand: Bool { commandInfo != nil }

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        text: String,
        audioPath: URL,
        duration: TimeInterval,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        commandInfo: CommandInfo? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.audioPath = audioPath
        self.duration = duration
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.commandInfo = commandInfo
    }
}

public struct TranscriptionHistory: Codable, Equatable, Sendable {
    public var history: [Transcript] = []
    
    public init(history: [Transcript] = []) {
        self.history = history
    }
}
