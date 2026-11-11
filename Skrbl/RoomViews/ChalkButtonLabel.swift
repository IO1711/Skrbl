import SwiftUI

struct ChalkButtonLabel: View {
    let title: String
    var frameName = "flat_button_frame"
    var expandsWidth = false

    var body: some View {
        Text(title)
            .font(AppTheme.font(size: 18, relativeTo: .headline))
            .foregroundStyle(AppTheme.text)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, frameName == "small_button_frame" ? 12 : 24)
            .frame(
                minWidth: frameName == "small_button_frame" ? 120 : nil,
                maxWidth: expandsWidth ? .infinity : nil,
                minHeight: frameName == "small_button_frame" ? 60 : 55
            )
            .background {
                Image(decorative: frameName)
                    .resizable()
            }
    }
}
