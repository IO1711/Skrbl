import SwiftUI

struct ChalkMenuCard: View {
    let title: String
    let frameName: String
    var iconName: String?
    var decorationName: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var designSize: CGSize {
        frameName == "frame_2"
            ? CGSize(width: 450, height: 330)
            : CGSize(width: 500, height: 350)
    }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            accessibilityCard
        } else {
            Image(decorative: frameName)
                .resizable()
                .aspectRatio(designSize, contentMode: .fit)
                .frame(maxWidth: designSize.width)
                .visualEffect { image, geometry in
                    image.scaleEffect(zoom(for: geometry.size.width))
                }
                .overlay {
                    GeometryReader { geometry in
                        let scale = geometry.size.width / designSize.width
                            * zoom(for: geometry.size.width)

                        cardContent(scale: scale)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .offset(
                                x: iconName == nil ? 0 : (frameName == "frame_2" ? -50 : -20) * scale,
                                y: iconName == nil ? 0 : (frameName == "frame_2" ? -10 : 10) * scale
                            )
                    }
                }
                .overlay {
                    if let decorationName {
                        GeometryReader { geometry in
                            let scale = geometry.size.width / designSize.width
                                * zoom(for: geometry.size.width)

                            Image(decorative: decorationName)
                                .resizable()
                                .scaledToFit()
                                .frame(
                                    width: (decorationName == "dog_chalk" ? 180 : 100) * scale,
                                    height: (decorationName == "dog_chalk" ? 180 : 100) * scale
                                )
                                .rotationEffect(.degrees(decorationName == "dog_chalk" ? 3 : 0))
                                .position(
                                    x: geometry.size.width / 2
                                        + (decorationName == "dog_chalk" ? 85 : -100) * scale,
                                    y: geometry.size.height / 2
                                        + (decorationName == "dog_chalk" ? -120 : 155) * scale
                                )
                        }
                        .allowsHitTesting(false)
                    }
                }
        }
    }

    private func zoom(for width: CGFloat) -> CGFloat {
        guard width > 0 else { return 1 }
        let maximumZoom = frameName == "frame_2" ? 1.25 : 1.45
        return min(max(1, designSize.width / width), maximumZoom)
    }

    @ViewBuilder
    private func cardContent(scale: CGFloat) -> some View {
        if let iconName {
            HStack(spacing: frameName == "frame_2" ? 20 * scale : 8 * scale) {
                Image(decorative: iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88 * scale, height: 95 * scale)
                    .padding(.leading, frameName == "frame_2" ? 50 * scale : 0)

                Text(title)
                    .font(AppTheme.font(size: 30, relativeTo: .title2))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(AppTheme.text)
        } else {
            Text(title)
                .font(AppTheme.font(size: 30, relativeTo: .title2))
                .foregroundStyle(AppTheme.text)
                .multilineTextAlignment(.center)
                .offset(y: frameName == "frame_2" ? -10 * scale : 10 * scale)
        }
    }

    private var accessibilityCard: some View {
        HStack(spacing: 16) {
            if let iconName {
                Image(decorative: iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
            }
            Text(title)
                .font(AppTheme.font(size: 30, relativeTo: .title2))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(AppTheme.text)
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(20)
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.text, lineWidth: 2)
        }
        .padding(.horizontal, 20)
    }
}
