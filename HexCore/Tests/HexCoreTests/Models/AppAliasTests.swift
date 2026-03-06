import Foundation
import Testing
@testable import HexCore

struct AppAliasTests {

	// MARK: - Default initializer

	@Test
	func defaultInitializer_setsIsEnabledTrue_andGeneratesUUID() {
		let alias = AppAlias(alias: "terminal", appName: "Ghostty")

		#expect(alias.isEnabled == true)
		#expect(alias.alias == "terminal")
		#expect(alias.appName == "Ghostty")
		// UUID should be non-nil (always true for UUID, but verify it was generated)
		#expect(alias.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
	}

	// MARK: - Equatable uses all fields (including ID)

	@Test
	func twoAliases_withSameFieldsButDifferentIDs_areNotEqual() {
		let alias1 = AppAlias(alias: "terminal", appName: "Ghostty")
		let alias2 = AppAlias(alias: "terminal", appName: "Ghostty")

		// Different UUIDs are generated, so they should not be equal
		#expect(alias1 != alias2)
	}

	@Test
	func twoAliases_withSameID_areEqual() {
		let sharedID = UUID()
		let alias1 = AppAlias(id: sharedID, alias: "terminal", appName: "Ghostty")
		let alias2 = AppAlias(id: sharedID, alias: "terminal", appName: "Ghostty")

		#expect(alias1 == alias2)
	}

	// MARK: - JSON round-trip

	@Test
	func jsonRoundTrip_preservesAllFields() throws {
		let id = UUID()
		let original = AppAlias(id: id, isEnabled: false, alias: "code", appName: "Visual Studio Code")

		let encoder = JSONEncoder()
		let data = try encoder.encode(original)

		let decoder = JSONDecoder()
		let decoded = try decoder.decode(AppAlias.self, from: data)

		#expect(decoded.id == id)
		#expect(decoded.isEnabled == false)
		#expect(decoded.alias == "code")
		#expect(decoded.appName == "Visual Studio Code")
		#expect(decoded == original)
	}

	// MARK: - Decoding with missing optional fields

	@Test
	func decodingFromJSON_withMissingIsEnabled_usesDefaultTrue() throws {
		// JSON that omits "isEnabled" — the decoder should use the default (true)
		let id = UUID()
		let json = """
		{
			"id": "\(id.uuidString)",
			"alias": "terminal",
			"appName": "Ghostty"
		}
		"""
		let data = Data(json.utf8)
		let decoder = JSONDecoder()
		let decoded = try decoder.decode(AppAlias.self, from: data)

		#expect(decoded.id == id)
		#expect(decoded.isEnabled == true)
		#expect(decoded.alias == "terminal")
		#expect(decoded.appName == "Ghostty")
	}

	// MARK: - Identifiable conformance

	@Test
	func identifiable_idMatchesUUID() {
		let id = UUID()
		let alias = AppAlias(id: id, alias: "slack", appName: "Slack")

		#expect(alias.id == id)
	}
}
