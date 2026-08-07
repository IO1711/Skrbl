//
//  ContentView.swift
//  Sketra
//
//  Created by Bilolbek Rayimov on 30/07/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Scribble")
                    .frame(maxWidth: .infinity)
                    .font(AppTheme.font(size: 50))
                    .foregroundStyle(AppTheme.text)
                    .padding(.vertical, 40)

                ScrollView {
                    VStack(spacing: -100) {
                        NavigationLink {
                            CreateRoomView()
                        } label: {
                            ZStack(alignment: .center) {
                                Image("frame_2")
                                    .resizable()
                                    .frame(width: 450, height: 330)
                                    .overlay(alignment: .topTrailing) {
                                        Image("dog_chalk")
                                            .resizable()
                                            .frame(width: 180, height: 180)
                                            //.padding(.bottom, -20)
                                            .rotationEffect(.degrees(3))
                                            .offset(x: -50, y: -45)
                                    }

                                Text("Create room")
                                    .font(AppTheme.font(size: 30))
                                    .foregroundStyle(AppTheme.text)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        NavigationLink {
                            JoinRoomView()
                        } label: {
                            ZStack(alignment: .center) {
                                Image("frame")
                                    .resizable()
                                    .frame(width: 500, height: 350)

                                Text("Join room")
                                    .font(AppTheme.font(size: 30))
                                    .foregroundStyle(AppTheme.text)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .buttonStyle(.plain)
            .mainBackground()
        }
    }

    /*private func menuItem(
        title: String,
        subtitle: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(AppTheme.text)
                .frame(width: 44, height: 44)
                .overlay {
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(AppTheme.text, lineWidth: 1.5)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppTheme.font(size: 17))
                    .foregroundStyle(AppTheme.text)
                Text(subtitle)
                    .font(AppTheme.font(size: 14))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(12)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.text, lineWidth: 1.5)
        }
    }*/
}

#Preview {
    ContentView()
}

/*
 NavigationStack {
     List {
         NavigationLink {
             CreateRoomView()
         } label: {
             menuItem(
                 title: "Create Room",
                 subtitle: "Host nearby over Wi-Fi or Bluetooth",
                 systemImage: "person.2.badge.plus"
             )
         }
         .listRowBackground(Color.clear)
         .listRowSeparator(.hidden)

         NavigationLink {
             JoinRoomView()
         } label: {
             menuItem(
                 title: "Join Room",
                 subtitle: "Find a nearby room or scan its QR code",
                 systemImage: "rectangle.portrait.and.arrow.right"
             )
         }
         .listRowBackground(Color.clear)
         .listRowSeparator(.hidden)
     }
     .scrollContentBackground(.hidden)
     .mainBackground()
     .navigationTitle("Sketra")
 }
}
 */
