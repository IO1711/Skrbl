//
//  SketraApp.swift
//  Sketra
//
//  Created by Bilolbek Rayimov on 30/07/2026.
//

import SwiftUI
import UIKit

@main
struct SketraApp: App {
    init() {
        let backgroundColor = UIColor(
            red: 9.0 / 255.0,
            green: 53.0 / 255.0,
            blue: 11.0 / 255.0,
            alpha: 1
        )
        let titleFont = UIFont(name: "Chalkduster", size: 17)
            ?? .systemFont(ofSize: 17)
        let largeTitleFont = UIFont(name: "Chalkduster", size: 32)
            ?? .systemFont(ofSize: 32)

        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithOpaqueBackground()
        navigationAppearance.backgroundColor = backgroundColor
        navigationAppearance.shadowColor = .clear
        navigationAppearance.titleTextAttributes = [
            .font: titleFont,
            .foregroundColor: UIColor.white
        ]
        navigationAppearance.largeTitleTextAttributes = [
            .font: largeTitleFont,
            .foregroundColor: UIColor.white
        ]

        UINavigationBar.appearance().standardAppearance = navigationAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance
        UINavigationBar.appearance().compactAppearance = navigationAppearance
        UIBarButtonItem.appearance().setTitleTextAttributes(
            [.font: titleFont, .foregroundColor: UIColor.white],
            for: .normal
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .font(AppTheme.font(size: 16))
                .foregroundStyle(AppTheme.text)
                .tint(AppTheme.text)
                .preferredColorScheme(.dark)
        }
    }
}
