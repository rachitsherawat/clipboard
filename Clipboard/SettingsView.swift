import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(.systemGray), Color(.systemGray).opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(0.5)
            
            Text("Settings")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary.opacity(0.7))
            
            Text("Preferences and configuration coming soon")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
