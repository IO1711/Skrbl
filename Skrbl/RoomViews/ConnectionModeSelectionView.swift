//
//  ConnectionModeSelectionView.swift
//  Skrbl
//
//  Created by Codex on 31/07/2026.
//

import SwiftUI

struct ConnectionModeSelectionView: View {
    let actionTitle: String
    let onSelect: (RoomConnectionMode) -> Void

    var body: some View {
        List {
            Section {
                ForEach(RoomConnectionMode.allCases) { mode in
                    Button {
                        onSelect(mode)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: mode.systemImage)
                                .font(.title2)
                                .frame(width: 36)
                                .foregroundStyle(AppTheme.text)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.title)
                                    .font(AppTheme.font(size: 17))

                                Text(mode.description)
                                    .font(AppTheme.font(size: 13))
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.tertiaryText)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(WhiteOutlineButtonStyle())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } header: {
                Text("Connection for \(actionTitle)")
                    .foregroundStyle(AppTheme.secondaryText)
            } footer: {
                Text("Every player must select the same connection type as the host.")
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .scrollContentBackground(.hidden)
        .mainBackground()
    }
}
