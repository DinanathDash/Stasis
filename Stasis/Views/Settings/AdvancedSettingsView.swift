import Defaults
import SwiftUI
import smc_power

struct AdvancedSettingsView: View {
    let capabilities: DeviceCapabilities
    @Default(.useHardwarePercentage) var useHardwarePercentage
    @Default(.useRawHardwareHealth) var useRawHardwareHealth
    @Default(.showAdvancedChargingControls) var showAdvancedChargingControls

    var body: some View {
        Form {
            Section {
                Toggle("Use hardware percentage", isOn: $useHardwarePercentage)
                Toggle(
                    "Use raw hardware health",
                    isOn: $useRawHardwareHealth
                )
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Battery Reading")
                    Text(
                        "Use the raw battery percentage instead of the macOS calibrated value."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            Section("Menu Controls") {
                Toggle("Show manual charging controls", isOn: $showAdvancedChargingControls)
                    .disabled(capabilities.nativeMode)
                
                if capabilities.nativeMode {
                    Text("Manual charging controls are not supported on this macOS version.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 4, for: .scrollContent)
        .scrollEdgeEffectStyleSoftIfAvailable()
    }
}

#Preview {
    AdvancedSettingsView(
        capabilities: DeviceCapabilities(
            chargingControl: true,
            adapterControl: true,
            hasMagSafe: true,
            magsafeLEDControl: true,
            nativeMode: false
        )
    )
}
