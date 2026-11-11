import Foundation

nonisolated enum RoomGameRules {
    static func normalizedPlayerName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(24))
    }

    static func normalizedViewerWord(_ word: String) -> String {
        let singleLine = word
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return String(singleLine.prefix(32))
    }


    static func guessKey(_ word: String) -> String {
        let folded = word.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        return folded.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
            .lowercased()
    }

    static func correctGuessPoints(remainingSeconds: Int, timeLimit: Int) -> Int {
        guard timeLimit > 0 else { return 20 }
        let remaining = min(max(remainingSeconds, 0), timeLimit)
        let elapsedFraction = 1 - Double(remaining) / Double(timeLimit)
        guard elapsedFraction > 0.20 else { return 100 }
        let progress = min(max((elapsedFraction - 0.20) / 0.80, 0), 1)
        return min(max(Int((20 + 80 * (1 - pow(progress, 1.5))).rounded()), 20), 100)
    }

    static func pointsAfterHintPenalty(_ points: Int, revealedLetterCount: Int) -> Int {
        let penalty = min(Double(max(revealedLetterCount, 0)) * 0.10, 0.50)
        return max(Int((Double(points) * (1 - penalty)).rounded()), 1)
    }

    static func isHintLetter(_ character: Character) -> Bool {
        character.unicodeScalars.contains {
            CharacterSet.alphanumerics.contains($0)
        }
    }

    static func wordHint(characters: [Character], revealedIndices: Set<Int>) -> String {
        var result = ""
        var needsCharacterSpacing = false
        for (index, character) in characters.enumerated() {
            if character.isWhitespace {
                result += "   "
                needsCharacterSpacing = false
                continue
            }
            if needsCharacterSpacing { result += " " }
            result += isHintLetter(character) && !revealedIndices.contains(index)
                ? "_" : String(character)
            needsCharacterSpacing = true
        }
        return result
    }

    /// Uses the previous order so a departed drawer still has a position in the rotation.
    static func nextTurn(
        after drawerID: UUID?,
        previousOrder: [UUID],
        activePlayerIDs: [UUID],
        round: Int,
        numberOfRounds: Int
    ) -> RoomTurn? {
        guard let drawerID,
              let currentIndex = previousOrder.firstIndex(of: drawerID),
              !activePlayerIDs.isEmpty else { return nil }

        for offset in 1...previousOrder.count {
            let candidateIndex = (currentIndex + offset) % previousOrder.count
            let candidate = previousOrder[candidateIndex]
            guard activePlayerIDs.contains(candidate) else { continue }
            let nextRound = round + (candidateIndex <= currentIndex ? 1 : 0)
            guard nextRound <= numberOfRounds else { return nil }
            return RoomTurn(drawerID: candidate, round: nextRound)
        }
        return nil
    }
}
