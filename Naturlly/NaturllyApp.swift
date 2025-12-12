//
//  NaturllyApp.swift
//  Naturlly TTS
//
//  Created on November 26, 2025.
//

import SwiftUI

@main
struct NaturllyApp: App {
    var body: some Scene {
        WindowGroup {
            let audioManager = AudioPlayerManager()
            TabView {
                ContentView()
                    .tabItem {
                        Label("TTS", systemImage: "waveform")
                    }
                
                LibraryView()
                    .tabItem {
                        Label("Library", systemImage: "books.vertical")
                    }
            }
            .environmentObject(audioManager)
        }
    }
}
