import smc_power
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case dashboard = "Dashboard"
    case charging = "Charging"
    case advanced = "Advanced"
    case shortcuts = "Shortcuts & Help"
    case about = "About"

    var id: String {
        rawValue
    }

    var title: LocalizedStringKey {
        switch self {
        case .general: return "General"
        case .dashboard: return "Dashboard"
        case .charging: return "Charging"
        case .advanced: return "Advanced"
        case .shortcuts: return "Shortcuts & Help"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .general:
            return "gearshape"
        case .dashboard:
            return "square.grid.2x2"
        case .charging:
            return "battery.100.bolt"
        case .advanced:
            return "gearshape.2"
        case .shortcuts:
            return "bolt.fill"
        case .about:
            return "info.circle"
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @State private var navigationHistory: [SettingsTab] = [.general]
    @State private var historyIndex = 0
    @State private var isHistoryNavigation = false
    @State private var showLanguageDialog = false
    @State private var showHelperDialog = false

    private let capabilities: DeviceCapabilities
    init(capabilities: DeviceCapabilities) {
        self.capabilities = capabilities
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label {
                    Text(tab.title)
                } icon: {
                    Image(systemName: tab.icon)
                }
                .tag(tab)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 180, max: 200)
            .listStyle(.sidebar)
            .scrollEdgeEffectStyleSoftIfAvailable()
            .navigationTitle("Settings")
            .safeAreaInset(edge: .bottom) {
                SidebarBottomButtonsView(
                    showLanguageDialog: $showLanguageDialog,
                    showHelperDialog: $showHelperDialog
                )
            }
        } detail: {
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .dashboard:
                    DashboardSettingsView()
                case .charging:
                    ChargingSettingsView(capabilities: capabilities)
                case .advanced:
                    AdvancedSettingsView(capabilities: capabilities)
                case .shortcuts:
                    ShortcutsHelpView(capabilities: capabilities)
                case .about:
                    AboutSettingsView()
                }
            }
            .navigationTitle(selectedTab.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationTitle("Settings")
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 700, minHeight: 450)
        .sheet(isPresented: $showLanguageDialog) {
            LanguageSelectionDialog()
        }
        .sheet(isPresented: $showHelperDialog) {
            HelperManagementDialog()
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    goBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!canGoBack)

                Button {
                    goForward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!canGoForward)
            }
        }
        .onChange(of: selectedTab) { _, _ in
            recordNavigation()
        }
    }

    private var canGoBack: Bool {
        historyIndex > 0
    }

    private var canGoForward: Bool {
        historyIndex < navigationHistory.count - 1
    }

    private func goBack() {
        guard canGoBack else { return }
        isHistoryNavigation = true
        historyIndex -= 1
        selectedTab = navigationHistory[historyIndex]
        DispatchQueue.main.async { isHistoryNavigation = false }
    }

    private func goForward() {
        guard canGoForward else { return }
        isHistoryNavigation = true
        historyIndex += 1
        selectedTab = navigationHistory[historyIndex]
        DispatchQueue.main.async { isHistoryNavigation = false }
    }

    private func recordNavigation() {
        guard !isHistoryNavigation else { return }
        let tab = selectedTab
        if navigationHistory.last == tab {
            return
        }
        if historyIndex < navigationHistory.count - 1 {
            navigationHistory = Array(navigationHistory.prefix(historyIndex + 1))
        }
        navigationHistory.append(tab)
        historyIndex = navigationHistory.count - 1
    }
}

#Preview {
    SettingsView(
        capabilities: DeviceCapabilities(
            chargingControl: true,
            adapterControl: true,
            hasMagSafe: true,
            magsafeLEDControl: true
        )
    )
}

extension View {
    @ViewBuilder
    func scrollEdgeEffectStyleSoftIfAvailable() -> some View {
        if #available(macOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
    }
}
