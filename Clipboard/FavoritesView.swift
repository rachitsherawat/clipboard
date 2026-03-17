import SwiftUI

struct FavoritesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.fill")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(0.5)
            
            Text("No Favorites Yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary.opacity(0.7))
            
            Text("Star clipboard items to save them here")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
