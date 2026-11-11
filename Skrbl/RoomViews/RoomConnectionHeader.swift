import SwiftUI

struct RoomConnectionHeader: View {
    let mode: RoomConnectionMode
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection")
                .appTextStyle(AppTheme.chalkboardText(size: 20, relativeTo: .headline))

            ViewThatFits(in: .horizontal) {
                HStack {
                    connectionLabel.fixedSize()
                    Spacer()
                    changeButton.fixedSize()
                }
                VStack(alignment: .leading, spacing: 12) {
                    connectionLabel
                    changeButton
                }
            }
        }
    }

    private var connectionLabel: some View {
        HStack {
            Image(decorative: mode.title)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 48)
            Text(mode.title)
                .appTextStyle(AppTheme.chalkboardText(size: 20))
        }
    }

    private var changeButton: some View {
        Button(action: onChange) {
            ChalkButtonLabel(title: "Change", frameName: "small_button_frame")
        }
    }
}
