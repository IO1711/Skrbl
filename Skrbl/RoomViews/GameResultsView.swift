//
//  GameResultsView.swift
//  Skrbl
//
//  Created by Codex on 09/08/2026.
//

import SwiftUI

struct GameResultsView: View {
    let rankings: [RoomPlayerScore]
    let onBackToRoom: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.yellow)

                    Text("Game Over")
                        .font(AppTheme.font(size: 34))
                        .multilineTextAlignment(.center)

                    if !rankings.isEmpty {
                        Text(winnerText)
                            .appTextStyle(
                                AppTheme.secondaryChalkboardText(size: 19)
                            )
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)

                LazyVStack(spacing: 12) {
                    ForEach(Array(rankings.enumerated()), id: \.element.id) {
                        index,
                        playerScore in
                        rankingRow(
                            playerScore,
                            position: rankingPosition(at: index)
                        )
                    }
                }

                Button(action: onBackToRoom) {
                    Text("Back to Room")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(WhiteOutlineButtonStyle())
                .controlSize(.large)
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .mainBackground()
    }

    private func rankingRow(
        _ playerScore: RoomPlayerScore,
        position: Int
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(medalColor(for: position), lineWidth: 2)
                    .frame(width: 44, height: 44)

                Text("#\(position)")
                    .font(AppTheme.font(size: 15))
                    .foregroundStyle(AppTheme.text)
            }

            Text(playerScore.playerName)
                .font(AppTheme.font(size: 17))
                .lineLimit(1)

            Spacer(minLength: 12)

            Text("\(playerScore.points) pts")
                .appTextStyle(AppTheme.chalkboardText(size: 18))
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.text, lineWidth: position == 1 ? 2.5 : 1.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Rank \(position), \(playerScore.playerName), \(playerScore.points) points"
        )
    }

    private func rankingPosition(at index: Int) -> Int {
        guard rankings.indices.contains(index) else { return index + 1 }
        let points = rankings[index].points
        return (rankings.firstIndex { $0.points == points } ?? index) + 1
    }

    private var winnerText: String {
        guard let winningScore = rankings.first?.points else { return "" }
        let winners = rankings.prefix { $0.points == winningScore }
        if winners.count == 1, let winner = winners.first {
            return "\(winner.playerName) wins!"
        }
        return "\(winners.count) players tie for first!"
    }

    private func medalColor(for position: Int) -> Color {
        switch position {
        case 1:
            .yellow
        case 2:
            .gray
        case 3:
            .orange
        default:
            AppTheme.text
        }
    }
}

#Preview("Game Results") {
    NavigationStack {
        GameResultsView(
            rankings: [
                RoomPlayerScore(
                    playerID: UUID(),
                    playerName: "Maya",
                    points: 846
                ),
                RoomPlayerScore(
                    playerID: UUID(),
                    playerName: "Alex",
                    points: 720
                ),
                RoomPlayerScore(
                    playerID: UUID(),
                    playerName: "Sam",
                    points: 720
                ),
                RoomPlayerScore(
                    playerID: UUID(),
                    playerName: "Jordan",
                    points: 510
                )
            ],
            onBackToRoom: {}
        )
        .navigationTitle("Final Rankings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
