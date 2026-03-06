import ComposableArchitecture
import HexCore
import Inject
import SwiftUI

struct AppAliasesView: View {
	@ObserveInjection var inject
	@Bindable var store: StoreOf<SettingsFeature>

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				// Header
				VStack(alignment: .leading, spacing: 6) {
					Text("App Aliases")
						.font(.title2.bold())
					Text("Map speakable words to app names for voice commands like \"switch to terminal.\"")
						.font(.callout)
						.foregroundStyle(.secondary)
				}

				// Aliases list
				GroupBox {
					VStack(alignment: .leading, spacing: 10) {
						// Column headers
						aliasColumnHeaders

						// Rows
						LazyVStack(alignment: .leading, spacing: 6) {
							ForEach(store.hexSettings.appAliases) { alias in
								if let aliasBinding = aliasBinding(for: alias.id) {
									AliasRow(alias: aliasBinding) {
										store.send(.removeAppAlias(alias.id))
									}
								}
							}
						}

						// Add button
						HStack {
							Button {
								store.send(.addAppAlias)
							} label: {
								Label("Add Alias", systemImage: "plus")
							}
							Spacer()
						}
					}
					.padding(.vertical, 4)
				} label: {
					VStack(alignment: .leading, spacing: 4) {
						Text("Voice Command Aliases")
							.font(.headline)
						Text("When you say \"switch to [alias]\", the matching app will be focused.")
							.settingsCaption()
					}
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding()
		}
		.enableInjection()
	}

	private var aliasColumnHeaders: some View {
		HStack(spacing: 8) {
			Text("On")
				.frame(width: Layout.toggleColumnWidth, alignment: .leading)
			Text("Alias")
				.frame(maxWidth: .infinity, alignment: .leading)
			Image(systemName: "arrow.right")
				.font(.caption)
				.foregroundStyle(.secondary)
				.frame(width: Layout.arrowColumnWidth)
			Text("App Name")
				.frame(maxWidth: .infinity, alignment: .leading)
			Spacer().frame(width: Layout.deleteColumnWidth)
		}
		.font(.caption)
		.foregroundStyle(.secondary)
		.padding(.horizontal, Layout.rowHorizontalPadding)
	}

	private func aliasBinding(for id: UUID) -> Binding<AppAlias>? {
		guard let index = store.hexSettings.appAliases.firstIndex(where: { $0.id == id }) else { return nil }
		return $store.hexSettings.appAliases[index]
	}
}

private struct AliasRow: View {
	@Binding var alias: AppAlias
	var onDelete: () -> Void

	var body: some View {
		HStack(spacing: 8) {
			Toggle("", isOn: $alias.isEnabled)
				.labelsHidden()
				.toggleStyle(.checkbox)
				.frame(width: Layout.toggleColumnWidth, alignment: .leading)

			TextField("Alias", text: $alias.alias)
				.textFieldStyle(.roundedBorder)
				.frame(maxWidth: .infinity, alignment: .leading)

			Image(systemName: "arrow.right")
				.foregroundStyle(.secondary)
				.frame(width: Layout.arrowColumnWidth)

			TextField("App Name", text: $alias.appName)
				.textFieldStyle(.roundedBorder)
				.frame(maxWidth: .infinity, alignment: .leading)

			Button(role: .destructive, action: onDelete) {
				Image(systemName: "trash")
			}
			.buttonStyle(.borderless)
			.frame(width: Layout.deleteColumnWidth)
		}
		.padding(.horizontal, Layout.rowHorizontalPadding)
		.padding(.vertical, Layout.rowVerticalPadding)
		.frame(maxWidth: .infinity)
		.background(
			RoundedRectangle(cornerRadius: Layout.rowCornerRadius)
				.fill(Color(nsColor: .controlBackgroundColor))
		)
	}
}

private enum Layout {
	static let toggleColumnWidth: CGFloat = 24
	static let deleteColumnWidth: CGFloat = 24
	static let arrowColumnWidth: CGFloat = 16
	static let rowHorizontalPadding: CGFloat = 10
	static let rowVerticalPadding: CGFloat = 6
	static let rowCornerRadius: CGFloat = 8
}
