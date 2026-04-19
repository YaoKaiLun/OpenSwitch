import SwiftUI
import AppKit

@main
struct OpenSwitchApp: App {
    @NSApplicationDelegateAdaptor(OpenSwitchAppDelegate.self) private var appDelegate

    @StateObject private var viewModel = AssociationViewModel(
        associationManager: LaunchServicesAssociationManager(),
        appProvider: InstalledAppsProvider(),
        presetStore: LocalPresetStore()
    )

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: viewModel)
                .frame(minWidth: 1120, minHeight: 720)
        }
    }
}

final class OpenSwitchAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
