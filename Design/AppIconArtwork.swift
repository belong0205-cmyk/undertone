import SwiftUI

/// App icon: a quiet waveform on a deep squircle, the "undertone" beneath the conversation.
/// Drawn on the 1024 macOS icon grid (824 pt body, 100 pt margin).
struct AppIconArtwork: View {
    private let bars: [CGFloat] = [170, 300, 430, 290, 180]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.13, green: 0.14, blue: 0.23), Color(red: 0.05, green: 0.06, blue: 0.10)],
                    startPoint: .top, endPoint: .bottom
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 185, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 3)
                )
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.35), radius: 20, y: 12)

            HStack(spacing: 44) {
                ForEach(bars.indices, id: \.self) { i in
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(red: 0.70, green: 0.75, blue: 1.0), Color(red: 0.38, green: 0.44, blue: 1.0)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: 62, height: bars[i])
                }
            }

            Image(systemName: "sparkle")
                .font(.system(size: 120, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.9))
                .offset(x: 250, y: -250)
        }
        .frame(width: 1024, height: 1024)
    }
}
