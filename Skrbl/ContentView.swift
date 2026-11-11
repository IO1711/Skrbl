import SwiftUI

struct ContentView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Text("Scribble")
                        .font(AppTheme.font(size: 60, relativeTo: .largeTitle))
                        .foregroundStyle(AppTheme.text)
                        .minimumScaleFactor(0.65)
                        .padding(.vertical, 30)

                    VStack(spacing: dynamicTypeSize.isAccessibilitySize
                           ? 16 : (horizontalSizeClass == .compact ? -40 : -100)) {
                        NavigationLink {
                            CreateRoomView()
                        } label: {
                            ChalkMenuCard(
                                title: "Create room",
                                frameName: "frame_2",
                                decorationName: "dog_chalk"
                            )
                        }
                        .accessibilityLabel("Create room")

                        NavigationLink {
                            JoinRoomView()
                        } label: {
                            ChalkMenuCard(title: "Join room", frameName: "frame")
                        }
                        .accessibilityLabel("Join room")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)
            }
            .buttonStyle(.plain)
            .mainBackground()
        }
    }
}

#Preview {
    ContentView()
}
