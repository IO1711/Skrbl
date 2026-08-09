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
        VStack(spacing: 0) {
            Text("How would you like to play?")
                .font(AppTheme.font(size: 30))
                .foregroundStyle(AppTheme.text)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)

            ScrollView {
                VStack(spacing: -100) {
                    ForEach(RoomConnectionMode.allCases) { mode in
                        Button {
                            onSelect(mode)
                        } label: {
                            ZStack(alignment: .center) {
                                if mode == .wifi {
                                    Image("frame_2")
                                        .resizable()
                                        .frame(width: 450, height: 330)
                                        .overlay() {
                                            HStack{

                                                Image("\(mode.title)")
                                                    .resizable()
                                                    .frame(width: 88, height: 95)
                                                    .padding(.leading, 50)
                                                    .padding(.trailing, 20)

                                                Text(mode.title)
                                                    .font(AppTheme.font(size: 30))
                                                    .foregroundStyle(AppTheme.text)
                                            }
                                            .offset(x:-50, y: -10)
                                        }
                                } else {
                                    Image("frame")
                                        .resizable()
                                        .frame(width: 500, height: 350)
                                        .overlay(alignment: .topTrailing) {
                                            Image("spider_chalk")
                                                .resizable()
                                                .frame(width: 100, height: 100)
                                            //.padding(.bottom, -20)
                                                .rotationEffect(.degrees(0))
                                                .offset(x: -300, y: 280)
                                        }
                                        .overlay(alignment: .center) {
                                            HStack{

                                                Image("\(mode.title)")
                                                    .resizable()
                                                    .frame(width: 88, height: 95)

                                                Text(mode.title)
                                                    .font(AppTheme.font(size: 30))
                                                    .foregroundStyle(AppTheme.text)
                                            }
                                            .offset(x:-20, y: 10)
                                        }
                                }

                                /*HStack{

                                    Image("\(mode.title)")
                                        .resizable()
                                        .frame(width: 88, height: 95)

                                    Text(mode.title)
                                        .font(AppTheme.font(size: 30))
                                        .foregroundStyle(AppTheme.text)
                                }*/

                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .buttonStyle(.plain)
        .mainBackground()
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

#Preview("Connection Mode Selection") {
    NavigationStack {
        ConnectionModeSelectionView(actionTitle: "Creating a Room") { _ in }
    }
}


/*
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
*/
