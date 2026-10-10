import SwiftUI

struct LivePreviewView: View {
    @ObservedObject var manager: LivePreviewManager

    var body: some View {
        ZStack {
            Color.black

            if let frame = manager.currentFrame {
                Image(uiImage: frame)
                    .resizable()
                    .scaledToFit()
                    .transition(.opacity)
            } else {
                placeholder
            }
        }
        .clipShape(Rectangle())
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            if manager.isStreaming {
                ProgressView()
                    .tint(.white)
                Text("Conectando preview…")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                Image(systemName: "video.slash.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.3))
                Text("Sin señal")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}
