import Foundation
import Testing
@testable import HexCore

struct AppAliasSettingsTests {

	// MARK: - Default value is empty array

	@Test
	func defaultSettings_hasEmptyAppAliases() {
		let settings = HexSettings()
		#expect(settings.appAliases == [])
	}

	// MARK: - Init with aliases

	@Test
	func initWithAliases_storesCorrectly() {
		let alias = AppAlias(alias: "terminal", appName: "Ghostty")
		let settings = HexSettings(appAliases: [alias])

		#expect(settings.appAliases.count == 1)
		#expect(settings.appAliases[0].alias == "terminal")
		#expect(settings.appAliases[0].appName == "Ghostty")
		#expect(settings.appAliases[0].isEnabled == true)
	}

	// MARK: - Round-trip encode/decode preserves aliases

	@Test
	func roundTripEncodeDecode_preservesAppAliases() throws {
		let id1 = UUID()
		let id2 = UUID()
		let aliases = [
			AppAlias(id: id1, alias: "terminal", appName: "Ghostty"),
			AppAlias(id: id2, isEnabled: false, alias: "code", appName: "Visual Studio Code")
		]
		let original = HexSettings(appAliases: aliases)

		let data = try JSONEncoder().encode(original)
		let decoded = try JSONDecoder().decode(HexSettings.self, from: data)

		#expect(decoded.appAliases.count == 2)
		#expect(decoded.appAliases[0].id == id1)
		#expect(decoded.appAliases[0].alias == "terminal")
		#expect(decoded.appAliases[0].appName == "Ghostty")
		#expect(decoded.appAliases[0].isEnabled == true)
		#expect(decoded.appAliases[1].id == id2)
		#expect(decoded.appAliases[1].alias == "code")
		#expect(decoded.appAliases[1].appName == "Visual Studio Code")
		#expect(decoded.appAliases[1].isEnabled == false)
		#expect(decoded.appAliases == original.appAliases)
	}

	// MARK: - Forward compatibility (missing key decodes to empty array)

	@Test
	func decodingJSON_withoutAppAliasesKey_defaultsToEmptyArray() throws {
		// Minimal valid JSON that does NOT contain an "appAliases" key
		// This simulates an older settings file before the feature was added
		let json = "{}"
		let data = Data(json.utf8)

		let decoded = try JSONDecoder().decode(HexSettings.self, from: data)

		#expect(decoded.appAliases == [])
	}
}
