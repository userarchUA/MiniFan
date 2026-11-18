import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let model = Model()
    var window: NSWindow!
    var statusItem: NSStatusItem?
    let menu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()
        buildWindow()
        menu.delegate = self
        model.onTick = { [weak self] in self?.updateStatusItem() }
        model.onSettingsChanged = { [weak self] in self?.syncStatusItem() }
        syncStatusItem()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { return !model.showMenuBar }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow(); return true
    }

    // MARK: window
    func buildWindow() {
        let hosting = NSHostingView(rootView: RootView(m: model))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 740),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.minSize = NSSize(width: 980, height: 680)
        window.contentView = hosting
        window.center()
        window.setFrameAutosaveName("MiniFanMainWindow")
        window.makeKeyAndOrderFront(nil)
    }

    @objc func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func buildMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit MiniFan", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        let winItem = NSMenuItem()
        main.addItem(winItem)
        let winMenu = NSMenu(title: "Window")
        winMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        winMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        winItem.submenu = winMenu
        NSApp.mainMenu = main
    }

    // MARK: menu bar item
    func syncStatusItem() {
        if model.showMenuBar {
            if statusItem == nil {
                statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                statusItem?.menu = menu
            }
            updateStatusItem()
        } else if let s = statusItem {
            NSStatusBar.system.removeStatusItem(s)
            statusItem = nil
        }
    }

    func updateStatusItem() {
        guard let btn = statusItem?.button else { return }
        let t = model.primaryTemp.map { model.temp($0) } ?? "--"
        btn.title = "\(t)  \(Int(model.rpmNow)) rpm"
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let t = model.primaryTemp.map { model.temp($0) } ?? "--"
        let h1 = NSMenuItem(title: "\(model.primaryName): \(t)", action: nil, keyEquivalent: "")
        h1.isEnabled = false
        menu.addItem(h1)
        let h2 = NSMenuItem(title: "Fan: \(Int(model.rpmNow)) rpm", action: nil, keyEquivalent: "")
        h2.isEnabled = false
        menu.addItem(h2)
        menu.addItem(NSMenuItem.separator())
        for n in Presets.names {
            let it = NSMenuItem(title: Presets.title(n), action: #selector(pickProfile(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = n
            it.state = model.activeProfile == n ? .on : .off
            menu.addItem(it)
        }
        menu.addItem(NSMenuItem.separator())
        let open = NSMenuItem(title: "Open MiniFan", action: #selector(showWindow), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
    }

    @objc func pickProfile(_ sender: NSMenuItem) {
        if let n = sender.representedObject as? String { model.applyProfile(n) }
    }
}
