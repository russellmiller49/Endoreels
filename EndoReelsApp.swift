//
//  EndoReelsApp.swift
//  EndoReels
//
//  Created by Russell Miller on 10/2/25.
//

import SwiftUI

@main
struct EndoReelsApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
