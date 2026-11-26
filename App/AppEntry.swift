import Security
import SwiftUI

@main
struct AppEntry: App {
    init() {
        // Harness-owned: a launch with -harness-fresh starts with no saved data, before any view exists.
        if CommandLine.arguments.contains("-harness-fresh") { HarnessFresh.wipe() }
    }

    var body: some Scene {
        WindowGroup { RootView() }
    }
}

/// Every scenario starts from a fresh install: all the app's saved data is removed.
enum HarnessFresh {
    static func wipe() {
        if let bundleId = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: bundleId) }
        let files = FileManager.default
        // Other UserDefaults(suiteName:) domains keep their own plists in Library/Preferences.
        let prefs = NSHomeDirectory() + "/Library/Preferences"
        for name in (try? files.contentsOfDirectory(atPath: prefs)) ?? [] where name.hasSuffix(".plist") {
            let domain = String(name.dropLast(".plist".count))
            UserDefaults(suiteName: domain)?.removePersistentDomain(forName: domain)
        }
        for dir in [NSHomeDirectory() + "/Documents", NSHomeDirectory() + "/Library", NSTemporaryDirectory()] {
            for name in (try? files.contentsOfDirectory(atPath: dir)) ?? [] {
                // Library/Preferences holds the plist UserDefaults just cleared; removing it under a live cfprefsd is unsafe.
                if dir.hasSuffix("/Library") && name == "Preferences" { continue }
                try? files.removeItem(atPath: dir + "/" + name)
            }
        }
        let classes = [kSecClassGenericPassword, kSecClassInternetPassword, kSecClassCertificate, kSecClassKey, kSecClassIdentity]
        for secClass in classes {
            SecItemDelete([kSecClass: secClass] as CFDictionary)
        }
    }
}
