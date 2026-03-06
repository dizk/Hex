import Foundation

public struct AppAlias: Codable, Equatable, Identifiable, Sendable {
	public var id: UUID
	public var isEnabled: Bool
	public var alias: String
	public var appName: String

	public init(
		id: UUID = UUID(),
		isEnabled: Bool = true,
		alias: String,
		appName: String
	) {
		self.id = id
		self.isEnabled = isEnabled
		self.alias = alias
		self.appName = appName
	}

	// Custom decoder to handle missing `isEnabled` field gracefully (defaults to true)
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.id = try container.decode(UUID.self, forKey: .id)
		self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
		self.alias = try container.decode(String.self, forKey: .alias)
		self.appName = try container.decode(String.self, forKey: .appName)
	}
}
