import SwiftUI

struct ConnectionModeSelectionView: View {
    let onSelect: (RoomConnectionMode) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("How would you like to play?")
                    .font(AppTheme.font(size: 30, relativeTo: .title))
                    .foregroundStyle(AppTheme.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                VStack(spacing: dynamicTypeSize.isAccessibilitySize
                       ? 16 : (horizontalSizeClass == .compact ? -40 : -100)) {
                    ForEach(RoomConnectionMode.allCases) { mode in
                        Button {
                            onSelect(mode)
                        } label: {
                            ChalkMenuCard(
                                title: mode.title,
                                frameName: mode == .wifi ? "frame_2" : "frame",
                                iconName: mode.title,
                                decorationName: mode == .bluetooth ? "spider_chalk" : nil
                            )
                        }
                        .accessibilityLabel(mode.title)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)
        }
        .buttonStyle(.plain)
        .mainBackground()
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

#Preview("Connection Mode Selection") {
    NavigationStack {
        ConnectionModeSelectionView { _ in }
    }
}
