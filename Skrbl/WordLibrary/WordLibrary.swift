//
//  WordLibrary.swift
//  Skrbl
//
//  Created by Codex on 31/07/2026.
//

import Foundation

enum WordTopic: String, Codable, CaseIterable, Identifiable {
    case animals
    case fruit
    case food
    case carBrands
    case vegetable

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .animals:
            "Animals"
        case .fruit:
            "Fruit"
        case .food:
            "Food"
        case .carBrands:
            "Car Brands"
        case .vegetable:
            "Vegetable"
        }
    }

    fileprivate var resourceName: String {
        switch self {
        case .animals:
            "Animals"
        case .fruit:
            "Fruit"
        case .food:
            "Food"
        case .carBrands:
            "CarBrands"
        case .vegetable:
            "Vegetable"
        }
    }
}

enum WordLibraryError: LocalizedError {
    case missingTopic(WordTopic)
    case invalidTopic(WordTopic)
    case insufficientWords(WordTopic)

    var errorDescription: String? {
        switch self {
        case .missingTopic(let topic):
            "Could not find the \(topic.title) word list."
        case .invalidTopic(let topic):
            "The \(topic.title) word list could not be read."
        case .insufficientWords(let topic):
            "The \(topic.title) word list needs at least three words."
        }
    }
}

enum WordLibrary {
    static func words(for topic: WordTopic) throws -> [String] {
        guard let url = Bundle.main.url(
            forResource: topic.resourceName,
            withExtension: "json"
        ) else {
            throw WordLibraryError.missingTopic(topic)
        }

        let data = try Data(contentsOf: url)
        guard let decodedWords = try? JSONDecoder().decode([String].self, from: data) else {
            throw WordLibraryError.invalidTopic(topic)
        }

        let words = decodedWords
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard words.count >= 3 else {
            throw WordLibraryError.insufficientWords(topic)
        }
        return words
    }

    static func choices(
        for topic: WordTopic,
        count: Int = 3
    ) throws -> [String] {
        Array(try words(for: topic).shuffled().prefix(count))
    }
}
