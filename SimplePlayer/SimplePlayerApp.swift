//
//  SimplePlayerApp.swift
//  SimplePlayer
//
//  Created by Eddy Kim on 3/12/26.
//

import SwiftUI
import AppKit

final class SimplePlayerAppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        print("SimplePlayerAppDelegate: openFile \(url.path)")
        AppOpenFileCoordinator.shared.handleIncoming(url: url)
        WindowManager.shared.bringMainWindowToFront()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        print("SimplePlayerAppDelegate: open URLs, using \(url.path)")
        AppOpenFileCoordinator.shared.handleIncoming(url: url)
        WindowManager.shared.bringMainWindowToFront()
    }
}

@main
struct SimplePlayerApp: App {
    @NSApplicationDelegateAdaptor(SimplePlayerAppDelegate.self) private var appDelegate
    @StateObject private var playerViewModel = PlayerViewModel()
    @StateObject private var openFileCoordinator = AppOpenFileCoordinator.shared

    var body: some Scene {
        WindowGroup {
            PlayerView(viewModel: playerViewModel, openFileCoordinator: openFileCoordinator)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open...") {
                    openFileCoordinator.presentOpenPanel()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
