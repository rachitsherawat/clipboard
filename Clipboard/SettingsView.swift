import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("historyLimit") private var historyLimit: Int = 100
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    
    let historyOptions = [50, 100, 200, 500]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Preferences")
                        .font(.headline)
                    Text("Customize your clipboard experience")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            Form {
                Section {
                    // Launch at Login
                    Toggle(isOn: $launchAtLogin) {
                        Text("Start Clipboard at Login")
                            .font(.system(size: 13))
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .padding(.vertical, 6)
                    .onChange(of: launchAtLogin) { newValue in
                        updateLaunchAtLogin(enabled: newValue)
                    }
                }
                
                Divider().opacity(0.5).padding(.vertical, 6)
                
                Section {
                    // Theme
                    Picker("Appearance", selection: $appTheme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.radioGroup)
                    .font(.system(size: 13))
                    .onChange(of: appTheme) { newValue in
                        applyTheme(newValue)
                    }
                }
                
                Divider().opacity(0.5).padding(.vertical, 6)
                
                Section {
                    // History Limit
                    VStack(alignment: .leading, spacing: 4) {
                        Picker("History Limit", selection: $historyLimit) {
                            ForEach(historyOptions, id: \.self) { limit in
                                Text("\(limit) items").tag(limit)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.system(size: 13))
                        .frame(width: 250)
                        
                        Text("Higher limits may increase memory usage slightly.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.leading, 80)
                    }
                }
                
                Spacer()
            }
            .padding(24)
        }
        .frame(width: 400, height: 350)
        .onAppear {
            checkLaunchAtLoginStatus()
        }
    }
    
    // MARK: - Handlers
    
    private func applyTheme(_ theme: String) {
        let appearance: NSAppearance?
        switch theme {
        case "dark":
            appearance = NSAppearance(named: .darkAqua)
        case "light":
            appearance = NSAppearance(named: .aqua)
        default:
            appearance = nil
        }
        NSApp.appearance = appearance
    }
    
    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update Launch at Login: \(error)")
            // Reset toggle if it failed
            checkLaunchAtLoginStatus()
        }
    }
    
    private func checkLaunchAtLoginStatus() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
