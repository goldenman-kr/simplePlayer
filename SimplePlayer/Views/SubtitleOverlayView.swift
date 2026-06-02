import SwiftUI

struct SubtitleOverlayView: View {
    let text: String
    let fontScale: Double
    let isFullscreen: Bool

    var body: some View {
        if !text.isEmpty {
            VStack {
                Spacer()
                Text(text)
                    .font(.system(size: fontSize, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .lineLimit(4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 1)
                    .padding(.horizontal, 24)
                    .padding(.bottom, isFullscreen ? 84 : 32)
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    private var fontSize: CGFloat {
        CGFloat((isFullscreen ? 30 : 22) * fontScale)
    }
}
