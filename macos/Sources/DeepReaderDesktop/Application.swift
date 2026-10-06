// SPDX-License-Identifier: AGPL-3.0-or-later
import AppKit
import PDFKit
import DeepReaderCore

@MainActor public enum Application {
    private static var delegate: AppDelegate?
    public static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        delegate = AppDelegate(); app.delegate = delegate
        app.run()
    }
}

@MainActor private final class AppDelegate: NSObject, NSApplicationDelegate {
    var reader: ReaderWindow?
    var pending: URL?
    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let smoke = ProcessInfo.processInfo.arguments.firstIndex(of: "--smoke-test")
            let arguments = ProcessInfo.processInfo.arguments
            let smokeFolder = smoke.flatMap { $0 + 1 < arguments.count ? URL(fileURLWithPath: arguments[$0+1], isDirectory: true) : nil }
            let store = try LibraryStore(root: smokeFolder?.appendingPathComponent("test-profile"))
            let model = ReaderModel(store: store)
            let controller = ReaderWindow(model: model); reader = controller
            controller.menusChanged = { [weak self] in self?.menus() }; menus(); controller.present()
            NSApp.activate(ignoringOtherApps: true)
            if let url = pending { controller.open(url); pending = nil }
            if let folder = smokeFolder {
                Task { @MainActor in
                    do {
                        try await Task.sleep(nanoseconds: 1000000000)
                        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        try SmokeTest.run(controller: controller, folder: folder)
                        try await Task.sleep(nanoseconds: 500000000)
                        try controller.snapshot(to: folder.appendingPathComponent("macos-window.png"))
                        try "PASS: app launched; PDF selection, highlights, sidebar docking, books and archive verified.\n".write(to: folder.appendingPathComponent("smoke-result.txt"), atomically: true, encoding: .utf8)
                        model.cancel(); exit(0)
                    } catch {
                        try? "FAIL: \(error.localizedDescription)\n".write(to: folder.appendingPathComponent("smoke-result.txt"), atomically: true, encoding: .utf8)
                        exit(1)
                    }
                }
            }
        } catch {
            let alert = NSAlert(); alert.messageText = "DeepReader"; alert.informativeText = "Could not open local application data. Check available space and folder permissions."
            alert.runModal(); NSApp.terminate(nil)
        }
    }
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard let first = filenames.first else { return }
        let url = URL(fileURLWithPath: first)
        if let reader = reader { reader.open(url); reader.showWindow(nil) } else { pending = url }
        sender.reply(toOpenOrPrint: .success)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        reader?.showWindow(nil); return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard reader?.canTerminate() ?? true else { return .terminateCancel }
        reader?.model.cancel(); return .terminateNow
    }
    private func menus() {
        guard let reader = reader else { return }
        let m = reader.model, main = NSMenu()
        func submenu(_ title: String) -> NSMenu {
            let item = NSMenuItem(); let menu = NSMenu(title: title); item.submenu = menu; main.addItem(item); return menu
        }
        func add(_ menu: NSMenu, _ title: String, _ selector: Selector, _ key: String = "", _ flags: NSEvent.ModifierFlags = [.command], target: AnyObject? = nil) {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: key); item.keyEquivalentModifierMask = flags; item.target = target ?? reader; menu.addItem(item)
        }
        let app = submenu("DeepReader")
        add(app, m.t("关于 DeepReader", "About DeepReader"), #selector(NSApplication.orderFrontStandardAboutPanel(_:)), target: NSApp)
        app.addItem(.separator()); add(app, m.t("隐藏 DeepReader", "Hide DeepReader"), #selector(NSApplication.hide(_:)), "h", target: NSApp)
        add(app, m.t("退出 DeepReader", "Quit DeepReader"), #selector(NSApplication.terminate(_:)), "q", target: NSApp)
        let file = submenu(m.t("文件", "File"))
        add(file, m.t("打开 PDF…", "Open PDF…"), #selector(ReaderWindow.openPanel), "o")
        add(file, m.t("保存 PDF", "Save PDF"), #selector(ReaderWindow.savePDF), "s")
        add(file, m.t("保存 PDF 副本…", "Save PDF copy…"), #selector(ReaderWindow.saveCopy), "s", [.command, .shift])
        let edit = submenu(m.t("编辑", "Edit"))
        for (title, action, key) in [(m.t("撤销", "Undo"), "undo:", "z"), (m.t("剪切", "Cut"), "cut:", "x"), (m.t("复制", "Copy"), "copy:", "c"), (m.t("粘贴", "Paste"), "paste:", "v"), (m.t("全选", "Select All"), "selectAll:", "a")] {
            let item = NSMenuItem(title: title, action: NSSelectorFromString(action), keyEquivalent: key); edit.addItem(item)
        }
        edit.addItem(.separator()); add(edit, m.t("搜索 PDF", "Find in PDF"), #selector(ReaderWindow.focusSearch), "f")
        add(edit, m.t("下一个匹配", "Find Next"), #selector(ReaderWindow.findNext), "g")
        add(edit, m.t("上一个匹配", "Find Previous"), #selector(ReaderWindow.findPrevious), "g", [.command, .shift])
        let view = submenu(m.t("显示", "View"))
        add(view, m.t("显示 AI 侧栏", "Show AI Sidebar"), #selector(ReaderWindow.showAI), "a", [.command, .shift])
        add(view, m.t("切换悬浮／停靠", "Toggle Floating / Docked"), #selector(ReaderWindow.toggleFloating))
        add(view, m.t("放大", "Zoom In"), #selector(ReaderWindow.zoomIn), "+")
        add(view, m.t("缩小", "Zoom Out"), #selector(ReaderWindow.zoomOut), "-")
        let ai = submenu("AI")
        add(ai, m.t("解释选中内容", "Explain Selection"), #selector(ReaderWindow.explain), "d", [.command, .shift])
        add(ai, m.t("发送追问", "Send Follow-up"), #selector(ReaderWindow.ask), "\r")
        NSApp.mainMenu = main
    }
}
