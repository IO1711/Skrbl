import SwiftUI
import UIKit

extension SketchColor {
    var color: Color {
        let rgba = rgba
        return Color(
            red: Double(rgba.red) / 255,
            green: Double(rgba.green) / 255,
            blue: Double(rgba.blue) / 255,
            opacity: Double(rgba.alpha) / 255
        )
    }

    func menuIcon(isSelected: Bool) -> Image {
        let rgba = rgba
        let uiColor = UIColor(
            red: CGFloat(rgba.red) / 255,
            green: CGFloat(rgba.green) / 255,
            blue: CGFloat(rgba.blue) / 255,
            alpha: CGFloat(rgba.alpha) / 255
        )
        let symbolName = isSelected ? "checkmark.circle.fill" : "circle.fill"
        let image = UIImage(systemName: symbolName)?
            .withTintColor(uiColor, renderingMode: .alwaysOriginal)

        return Image(uiImage: image ?? UIImage())
    }
}
