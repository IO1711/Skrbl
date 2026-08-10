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
    case countries
    case professions
    case house
    case school
    case kitchenTools
    case weapons
    case superheroes
    case villains
    case cartoonCharacters
    case videoGameCharacters
    case generalMythology
    case greekMythology
    case norseMythology
    case egyptianMythology
    case chineseMythology
    case indianMythology

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
        case .countries:
            "Countries"
        case .professions:
            "Professions"
        case .house:
            "House"
        case .school:
            "School"
        case .kitchenTools:
            "Kitchen Tools"
        case .weapons:
            "Weapons"
        case .superheroes:
            "Superheroes"
        case .villains:
            "Villains"
        case .cartoonCharacters:
            "Cartoon Characters"
        case .videoGameCharacters:
            "Video Game Characters"
        case .generalMythology:
            "General Mythology"
        case .greekMythology:
            "Greek Mythology"
        case .norseMythology:
            "Norse Mythology"
        case .egyptianMythology:
            "Egyptian Mythology"
        case .chineseMythology:
            "Chinese Mythology"
        case .indianMythology:
            "Indian Mythology"
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
        case .countries:
            "Countries"
        case .professions:
            "Professions"
        case .house:
            "House"
        case .school:
            "School"
        case .kitchenTools:
            "KitchenTools"
        case .weapons:
            "Weapons"
        case .superheroes:
            "Superheroes"
        case .villains:
            "Villains"
        case .cartoonCharacters:
            "CartoonCharacters"
        case .videoGameCharacters:
            "VideoGameCharacters"
        case .generalMythology:
            "GeneralMythology"
        case .greekMythology:
            "GreekMythology"
        case .norseMythology:
            "NorseMythology"
        case .egyptianMythology:
            "EgyptianMythology"
        case .chineseMythology:
            "ChineseMythology"
        case .indianMythology:
            "IndianMythology"
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
