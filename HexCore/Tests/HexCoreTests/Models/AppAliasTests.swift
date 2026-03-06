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

	// MARK: - Binding simulation (struct mutability for SwiftUI bindings)

	@Test
	func mutatingAliasField_updatesValue() {
		var alias = AppAlias(alias: "terminal", appName: "Ghostty")
		#expect(alias.alias == "terminal")

		alias.alias = "term"
		#expect(alias.alias == "term")
		// Other fields unchanged
		#expect(alias.appName == "Ghostty")
		#expect(alias.isEnabled == true)
	}

	@Test
	func mutatingAppNameField_updatesValue() {
		var alias = AppAlias(alias: "code", appName: "VS Code")
		#expect(alias.appName == "VS Code")

		alias.appName = "Visual Studio Code"
		#expect(alias.appName == "Visual Studio Code")
		#expect(alias.alias == "code")
	}

	@Test
	func mutatingIsEnabled_updatesValue() {
		var alias = AppAlias(alias: "slack", appName: "Slack")
		#expect(alias.isEnabled == true)

		alias.isEnabled = false
		#expect(alias.isEnabled == false)
	}

	// MARK: - Array operations (used by the view for add/find/remove)

	@Test
	func arrayAppend_andFindByID_returnsCorrectAlias() {
		var aliases: [AppAlias] = []
		let alias1 = AppAlias(alias: "terminal", appName: "Ghostty")
		let alias2 = AppAlias(alias: "code", appName: "Visual Studio Code")

		aliases.append(alias1)
		aliases.append(alias2)

		#expect(aliases.count == 2)

		// Find by ID (simulates aliasBinding helper)
		let found = aliases.first(where: { $0.id == alias2.id })
		#expect(found != nil)
		#expect(found?.alias == "code")
		#expect(found?.appName == "Visual Studio Code")
	}

	@Test
	func arrayFindByID_withNonexistentID_returnsNil() {
		let alias = AppAlias(alias: "terminal", appName: "Ghostty")
		let aliases = [alias]

		let found = aliases.first(where: { $0.id == UUID() })
		#expect(found == nil)
	}

	@Test
	func arrayRemoveByID_removesCorrectElement() {
		let alias1 = AppAlias(alias: "terminal", appName: "Ghostty")
		let alias2 = AppAlias(alias: "code", appName: "Visual Studio Code")
		let alias3 = AppAlias(alias: "slack", appName: "Slack")
		var aliases = [alias1, alias2, alias3]

		aliases.removeAll { $0.id == alias2.id }

		#expect(aliases.count == 2)
		#expect(aliases[0].id == alias1.id)
		#expect(aliases[1].id == alias3.id)
	}

	@Test
	func arrayMutateByIndex_updatesInPlace() {
		var aliases = [
			AppAlias(alias: "terminal", appName: "Ghostty"),
			AppAlias(alias: "code", appName: "VS Code"),
		]

		// Simulate what the binding does: find index, mutate in place
		guard let index = aliases.firstIndex(where: { $0.id == aliases[1].id }) else {
			Issue.record("Expected to find alias by ID")
			return
		}
		aliases[index].alias = "vscode"
		aliases[index].appName = "Visual Studio Code"

		#expect(aliases[index].alias == "vscode")
		#expect(aliases[index].appName == "Visual Studio Code")
		// First alias unchanged
		#expect(aliases[0].alias == "terminal")
	}
}
