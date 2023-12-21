//
//  BatteryBoiApp.swift
//  BatteryBoi
//
//  Created by Joe Barbour on 8/4/23.
//

import SwiftUI
import EnalogSwift
import Sparkle
import Combine
import Foundation
import UserNotifications

@main
struct BatteryBoiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            EmptyView()

        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
        
    }
    
}

class CustomView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Draw or add your custom elements here
        
    }
    
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate, ObservableObject {
    static var shared = AppDelegate()
    
    public var status:NSStatusItem? = nil
    public var hosting:NSHostingView = NSHostingView(rootView: MenuContainer())
    
    private var updates = Set<AnyCancellable>()
    private var callback: CFMessagePortCallBack = { messagePort, messageID, cfData, info in
        var payload:Data = Data("\n\u{001B}[1m\u{001B}[31m\("PARSING ERROR")\u{001B}[0m\n".utf8)
        if let pointer = info, let received = cfData as Data? {
            if let arguments = try? JSONDecoder().decode([String].self, from: received) {
                var primary:ProcessPrimaryCommands? = nil
                var secondary:ProcessSecondaryCommands? = nil
                var flags:[String] = []

                if arguments.indices.contains(0) {
                    primary = ProcessPrimaryCommands(rawValue: arguments[0])
                    
                }
                
                if arguments.indices.contains(1) {
                    secondary = ProcessSecondaryCommands(rawValue: arguments[1])
                    
                }
                
                if arguments.indices.contains(0) && arguments.indices.contains(0) {
                    flags = Array(arguments.suffix(arguments.count - 1)).map { String($0) }
                    
                }
                
                if let response = ProcessManager.shared.processInbound(primary, subcommand: secondary, flags: flags) {
                    payload = Data(response.utf8)

                }
    
            }

        }
           
        return Unmanaged.passRetained(payload as CFData)

    }
    
    final func applicationDidFinishLaunching(_ notification: Notification) {
        self.status = NSStatusBar.system.statusItem(withLength: 45)
        self.hosting.frame.size = NSSize(width: 45, height: 22)
        
        guard let status = self.status else {
            print("Failed to create status item.")
            return
            
        }
        
        if let window = NSApplication.shared.windows.first {
            window.close()
            
        }
        
        if let channel = Bundle.main.infoDictionary?["SD_SLACK_CHANNEL"] as? String  {
            #if !DEBUG
                EnalogManager.main.user(SystemDeviceTypes.identifyer)
                EnalogManager.main.crash(SystemEvents.fatalError, channel: .init(.slack, id: channel))
                EnalogManager.main.ingest(SystemEvents.userLaunched, description: "Launched BatteryBoi")
            #endif
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            _ = SettingsManager.shared.enabledTheme
            
            print("\n\nApp Installed: \(AppManager.shared.appInstalled)\n\n")
            print("App Usage (Days): \(AppManager.shared.appUsage?.day ?? 0)\n\n")

            UpdateManager.shared.updateCheck()
            
            WindowManager.shared.windowOpen(.alert, alert: .userInitiated, device: nil)
            
            MenubarManager.shared.$primary.removeDuplicates().sink { type in
                if type == nil {
                    self.applicationMenuBarIcon(false)
                } else {
                    self.applicationMenuBarIcon(true)
                }
            }.store(in: &self.updates)
            
        }
        
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(applicationHandleURLEvent(event:reply:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))

        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(applicationDidWakeNotification(_:)), name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(applicationDidWakeNotification(_:)), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(applicationDidSleepNotification(_:)), name: NSWorkspace.screensDidSleepNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationFocusDidMove(notification:)), name: NSWindow.didMoveNotification, object: nil)

        self.applicationMessagePortHandle()
        
    }
    
    private func applicationMessagePortHandle() {
        if let id = Bundle.main.infoDictionary?["ENV_CLIBOI_PORT"] as? String  {
            let info = Unmanaged.passUnretained(self).toOpaque()
            let port = id as CFString
            
            var context = CFMessagePortContext(version: 0, info: info, retain: nil, release: nil, copyDescription: nil)
            
            if let message = CFMessagePortCreateLocal(nil, port, callback, &context, nil) {
                if let source = CFMessagePortCreateRunLoopSource(nil, message, 0) {
                    CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
                    
                }
                
            }
            
        }
        
    }
    
    private func applicationMenuBarIcon(_ visible:Bool) {
        if visible == true {
            if let button = self.status?.button {
                button.title = ""
                button.addSubview(self.hosting)
                button.action = #selector(applicationStatusBarButtonClicked(sender:))
                button.target = self
                
                SettingsManager.shared.enabledPinned = .disabled
                
            }
            
        }
        else {
            if let button = self.status?.button {
                button.subviews.forEach { $0.removeFromSuperview() }
                
            }
            
        }
        
    }
    
    @objc func applicationStatusBarButtonClicked(sender: NSStatusBarButton) {
        if WindowManager.shared.windowIsVisible(.chargingBegan) == false {
            WindowManager.shared.windowOpen(.alert, alert: .userInitiated, device: nil)

        }
        else {
            WindowManager.shared.windowSetState(.dismissed)
            
        }
                
    }
    
    @objc func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        #if MAINTARGET
            WindowManager.shared.windowOpen(.alert, alert: .userInitiated, device: nil)

        #endif
        
        return false
        
    }
    
    @objc func applicationHandleURLEvent(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        
    }

    @objc func applicationFocusDidMove(notification:NSNotification) {
        if let window = notification.object as? NSWindow {
            if window.title == "modalwindow" {
                NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { _ in
                    window.animator().alphaValue = 1.0;
                    
                }
                                
            }

        }
        
    }
    
    @objc private func applicationDidWakeNotification(_ notification: Notification) {
        BatteryManager.shared.powerForceRefresh()
        AppManager.shared.sessionid = UUID()
        
    }
    
    @objc private func applicationDidSleepNotification(_ notification: Notification) {
        
    }
    
}
