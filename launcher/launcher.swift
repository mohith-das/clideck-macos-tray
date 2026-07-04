import Cocoa
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var clideckProcess: Process?
    var port = "4000"
    var pollTimer: Timer?
    var failCount = 0
    var hasOpenedBrowser = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Menu setup
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        NSApplication.shared.mainMenu = mainMenu
        
        let appMenu = NSMenu()
        let quitItem = NSMenuItem(title: "Quit CliDeck", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu

        // 1. Read port
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let settingsPath = home + "/.clideck/settings.json"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let configPort = json["port"] {
            self.port = "\(configPort)"
        }

        // 2. Try starting clideck
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH && exec clideck"]
        
        let pipe = Pipe()
        task.standardError = pipe
        task.standardOutput = pipe
        
        var outputStr = ""
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0, let str = String(data: data, encoding: .utf8) {
                outputStr += str
            }
        }
        
        task.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if process.terminationStatus == 0 {
                    // It exited cleanly immediately. It means it was already running!
                    self.openBrowser()
                    self.startPolling()
                } else {
                    // It crashed with an error
                    let alert = NSAlert()
                    alert.messageText = "CliDeck Error"
                    alert.informativeText = "CliDeck failed to start. Another application might be using port \(self.port).\n\nDetails: \(outputStr.prefix(200))"
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        
        do {
            try task.run()
            self.clideckProcess = task
        } catch {
            print("Failed to start clideck")
        }

        // 3. Wait for it to start up, if it didn't crash
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.clideckProcess?.isRunning == true {
                self.openBrowser()
                self.startPolling()
            }
        }
    }
    
    func openBrowser() {
        if hasOpenedBrowser { return }
        hasOpenedBrowser = true
        if let url = URL(string: "http://localhost:\(self.port)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func startPolling() {
        if pollTimer != nil { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard let url = URL(string: "http://localhost:\(self.port)") else { return }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 1.0
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if error != nil || (response as? HTTPURLResponse)?.statusCode != 200 {
                    self.failCount += 1
                    if self.failCount >= 3 {
                        DispatchQueue.main.async {
                            NSApplication.shared.terminate(nil)
                        }
                    }
                } else {
                    self.failCount = 0
                }
            }
            task.resume()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        pollTimer?.invalidate()
        clideckProcess?.terminate()
        
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
app.setActivationPolicy(.regular)
app.run()
