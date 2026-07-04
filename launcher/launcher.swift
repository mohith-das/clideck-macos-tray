import Cocoa
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var clideckProcess: Process?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Set up the native app menu so "Quit" works naturally
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        NSApplication.shared.mainMenu = mainMenu
        
        let appMenu = NSMenu()
        let quitItem = NSMenuItem(title: "Quit CliDeck", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu

        // 1. Read port from ~/.clideck/settings.json
        var port = "4000"
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let settingsPath = home + "/.clideck/settings.json"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let configPort = json["port"] {
            port = "\(configPort)"
        }

        // 2. Start clideck process as a child
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Use exec so the node process replaces the shell, allowing clean termination
        task.arguments = ["-c", "export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH && exec clideck"]
        
        // If clideck is killed externally (e.g. from the Menu Bar tray), quit this wrapper app too!
        task.terminationHandler = { _ in
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
        
        do {
            try task.run()
            self.clideckProcess = task
        } catch {
            print("Failed to start clideck")
        }

        // 3. Open browser reliably
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let url = URL(string: "http://localhost:\(port)") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // If the user right-clicks the Dock icon and hits Quit, kill clideck!
        clideckProcess?.terminate()
        
        // Fallback cleanup to ensure no zombie processes are left behind
        let killTask = Process()
        killTask.executableURL = URL(fileURLWithPath: "/bin/sh")
        killTask.arguments = ["-c", "pkill -f 'node.*/opt/homebrew/bin/clideck' || true ; pkill -f 'tray_darwin' || true"]
        try? killTask.run()
        killTask.waitUntilExit()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular) // Show in Dock and keep running
app.run()
