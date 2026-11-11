import AppKit
import SwiftUI
import Carbon
import WebKit

struct TaskItem: Codable, Identifiable {
    var id = UUID()
    var title: String
    var notes = ""
    var today = false // Legacy flag, migrated on load.
    var completed = false
    var created = Date()
    var scheduled: Date? = nil
    var completedAt: Date? = nil
    var dueDate: Date? = nil
    var bucket: String? = nil
    var planned: Date? { scheduled ?? (today ? Calendar.current.startOfDay(for: Date()) : nil) }
}

enum TaskDates {
    static let calendar = Calendar.current
    static var today: Date { calendar.startOfDay(for: Date()) }
    static func add(_ days: Int, to date: Date = today) -> Date { calendar.date(byAdding: .day, value: days, to: date)! }
    static var week: [Date] {
        let offset = (calendar.component(.weekday, from: today) + 5) % 7
        return (0..<7).map { add($0 - offset) }
    }
    static func active(_ task: TaskItem, view: String, day: Date?, bucket: String) -> Bool {
        guard !task.completed, matchesBucket(task, bucket) else { return false }
        if view == "Someday" { return task.planned == nil }
        guard let date = task.planned else { return false }
        if view == "Today" { return date < add(1) }
        if let day { return calendar.isDate(date, inSameDayAs: day) }
        return date >= week[0] && date < add(1, to: week[6])
    }
    static func matchesBucket(_ task: TaskItem, _ bucket: String) -> Bool {
        bucket == "All categories" || (bucket == "Uncategorized" ? (task.bucket ?? "").isEmpty : task.bucket == bucket)
    }
    static func history(_ task: TaskItem, range: String, start: Date, end: Date, bucket: String) -> Bool {
        guard task.completed, matchesBucket(task, bucket) else { return false }
        if range == "All time" { return true }
        guard let date = task.completedAt else { return false }
        let lower = range == "Past day" ? today : range == "Past week" ? add(-6) : range == "Past month" ? add(-29) : calendar.startOfDay(for: start)
        let upper = range == "Custom range" ? add(1, to: calendar.startOfDay(for: end)) : add(1)
        return date >= lower && date < upper
    }
}

final class TaskStore: ObservableObject {
    @Published var tasks: [TaskItem] = []
    @Published var error: String?
    @Published var lastCompleted: UUID?
    @Published var lastDeleted: TaskItem?
    private var deletedIndex = 0
    @Published var customCategories: [String] = []
    let url: URL
    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Braino/tasks.json")
        if let data = try? Data(contentsOf: self.url.deletingLastPathComponent().appendingPathComponent("categories.json")), let names = try? JSONDecoder().decode([String].self, from: data) { customCategories = names }
        reload()
    }
    @discardableResult func addCategory(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let known = customCategories + tasks.compactMap(\.bucket)
        if let existing = known.first(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) { return existing }
        do {
            let next = customCategories + [trimmed]
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(next).write(to: url.deletingLastPathComponent().appendingPathComponent("categories.json"), options: .atomic)
            customCategories = next; return trimmed
        } catch { self.error = "Couldn’t save category: \(error.localizedDescription)"; return nil }
    }
    func reload() {
        do {
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            tasks = try JSONDecoder().decode([TaskItem].self, from: Data(contentsOf: url))
            var migrated = false
            for index in tasks.indices where tasks[index].today {
                if tasks[index].scheduled == nil { tasks[index].scheduled = TaskDates.today }
                tasks[index].today = false; migrated = true
            }
            error = nil
            if migrated { save() }
        } catch { self.error = "Couldn’t read your tasks: \(error.localizedDescription)" }
    }
    func save() {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(tasks).write(to: url, options: .atomic)
            error = nil
        } catch { self.error = "Couldn’t save your tasks: \(error.localizedDescription)" }
    }
    func add(_ title: String, date: Date?, bucket: String, dueDate: Date? = nil) {
        let text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, error == nil else { return }
        let category = bucket.trimmingCharacters(in: .whitespacesAndNewlines)
        tasks.insert(TaskItem(title: text, scheduled: date, dueDate: dueDate, bucket: category.isEmpty ? nil : category), at: 0); save()
    }
    func update(_ item: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == item.id }) else { return }
        tasks[index] = item; save()
    }
    func toggle(_ id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].completed.toggle()
        tasks[index].completedAt = tasks[index].completed ? Date() : nil
        if tasks[index].completed { lastCompleted = id; lastDeleted = nil }
        save()
    }
    func delete(_ id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        lastDeleted = tasks[index]; deletedIndex = index; lastCompleted = nil
        tasks.remove(at: index); save()
    }
    func undo() {
        if let deleted = lastDeleted {
            if !tasks.contains(where: { $0.id == deleted.id }) { tasks.insert(deleted, at: min(deletedIndex, tasks.count)) }
            lastDeleted = nil; save(); return
        }
        guard let id = lastCompleted, let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].completed = false; tasks[index].completedAt = nil; lastCompleted = nil; save()
    }
}

enum DesktopBridge {
    enum Failure: Error { case invalidTask }
    static func day(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    static func date(_ value: Any?) -> Date? {
        guard let value = value as? String, !value.isEmpty else { return nil }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; f.isLenient = false; return f.date(from: value)
    }
    static func optional(_ value: String?) -> Any { if let value { return value }; return NSNull() }
    static func timestamp(_ value: Any?) -> Date? {
        guard let value = value as? String else { return nil }
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
    static func state(_ store: TaskStore, floating: Bool) -> [String: Any] {
        let iso = ISO8601DateFormatter()
        let rows: [[String: Any]] = store.tasks.map { task in
            ["id": task.id.uuidString, "title": task.title, "notes": task.notes,
             "date": optional(task.planned.map(day)), "dueDate": optional(task.dueDate.map(day)),
             "bucket": task.bucket ?? "", "completed": task.completed,
             "completedAt": optional(task.completedAt.map(iso.string(from:)))]
        }
        return ["tasks": rows, "categories": store.customCategories, "floating": floating,
                "readOnly": store.error != nil, "error": store.error ?? ""]
    }
    static func tasks(_ rows: [[String: Any]], existing: [TaskItem]) throws -> [TaskItem] {
        var seen = Set<UUID>()
        return try rows.map { row in
            guard let idString = row["id"] as? String, let id = UUID(uuidString: idString), seen.insert(id).inserted,
                  let title = row["title"] as? String, let notes = row["notes"] as? String else { throw Failure.invalidTask }
            var task = existing.first { $0.id == id } ?? TaskItem(title: title)
            task.id = id; task.title = title; task.notes = notes; task.today = false
            task.scheduled = date(row["date"]); task.dueDate = date(row["dueDate"])
            task.bucket = (row["bucket"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            task.completed = row["completed"] as? Bool == true; task.completedAt = timestamp(row["completedAt"])
            return task
        }
    }
}

// Braino design tokens: the shared HTML/CSS interface is bundled below this native shell.

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, WKScriptMessageHandler, WKNavigationDelegate {
    let store = TaskStore(url: ProcessInfo.processInfo.environment["BRAINO_TEST_DATA_DIR"].map { URL(fileURLWithPath: $0).appendingPathComponent("tasks.json") })
    var window: NSWindow!
    var web: WKWebView!
    var status: NSStatusItem!
    var hotkey: EventHotKeyRef?
    var loaded = false
    var ready = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        installMenus()
        let config = WKWebViewConfiguration()
        do {
            let state = DesktopBridge.state(store, floating: UserDefaults.standard.bool(forKey: "floating"))
            let json = try JSONSerialization.data(withJSONObject: state, options: [.sortedKeys])
            let script = "window.brainoNativeData = \(String(decoding: json, as: UTF8.self));"
            config.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        } catch { fatalError("Could not prepare local task data: \(error)") }
        config.userContentController.add(self, name: "braino")
        web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        web.setValue(false, forKey: "drawsBackground")
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 410, height: 470), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Braino"; window.titleVisibility = .hidden; window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false; window.delegate = self
        window.contentView = web
        window.minSize = NSSize(width: 410, height: 300)
        window.backgroundColor = NSColor(calibratedRed: 249.0/255, green: 248.0/255, blue: 242.0/255, alpha: 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.level = UserDefaults.standard.bool(forKey: "floating") ? .floating : .normal
        window.center()
        guard let ui = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "UI") else { fatalError("Shared UI missing") }
        web.loadFileURL(ui, allowingReadAccessTo: ui.deletingLastPathComponent())
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let url = Bundle.main.url(forResource: "BrainoMenu", withExtension: "png"), let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 19, height: 19); image.isTemplate = true; status.button?.image = image
        }
        status.button?.setAccessibilityLabel("Braino tasks")
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Braino    ⌃Space", action: #selector(show), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Hide Braino", action: #selector(hideWindow), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Braino", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        status.menu = menu
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, pointer in
            guard let pointer else { return noErr }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(pointer).takeUnretainedValue()
            DispatchQueue.main.async { delegate.toggleVisibility() }; return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), nil)
        let result = ProcessInfo.processInfo.environment["BRAINO_TESTING"] == "1" ? noErr : RegisterEventHotKey(UInt32(kVK_Space), UInt32(controlKey), EventHotKeyID(signature: 0x53544C4C, id: 1), GetApplicationEventTarget(), 0, &hotkey)
        if result != noErr { report("Control–Space is unavailable. Use the menu bar to open Braino.") }
        show()
    }
    func installMenus() {
        let main = NSMenu()
        let appItem = NSMenuItem(); let application = NSMenu(title: "Braino")
        application.addItem(withTitle: "About Braino", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        application.addItem(.separator())
        application.addItem(withTitle: "Hide Braino", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        application.addItem(withTitle: "Quit Braino", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = application; main.addItem(appItem)
        let editItem = NSMenuItem(); let edit = NSMenu(title: "Edit")
        for (title, selector, key) in [("Undo", "undo:", "z"), ("Redo", "redo:", "Z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            let item = NSMenuItem(title: title, action: Selector(selector), keyEquivalent: key)
            item.keyEquivalentModifierMask = title == "Redo" ? [.command, .shift] : [.command]
            edit.addItem(item)
        }
        editItem.submenu = edit; main.addItem(editItem); NSApp.mainMenu = main
    }
    @objc func show() {
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        focusCapture()
    }
    @objc func hideWindow() {
        window.orderOut(nil)
        NSApp.hide(nil)
    }
    @objc func toggleVisibility() {
        if window.isVisible && window.isKeyWindow && NSApp.isActive { hideWindow() } else { show() }
    }
    func focusCapture() {
        guard ready else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            guard self.window.isVisible, NSApp.isActive else { return }
            self.window.makeFirstResponder(self.web)
            self.web.evaluateJavaScript("window.brainoFocusCapture?.()", completionHandler: nil)
        }
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        do {
            switch type {
            case "save":
                guard loaded, let rows = body["tasks"] as? [[String: Any]] else { return }
                store.tasks = try DesktopBridge.tasks(rows, existing: store.tasks); store.save()
                if let error = store.error { report(error) }
            case "categories":
                guard loaded, let categories = body["categories"] as? [String] else { return }
                let data = try JSONEncoder().encode(categories)
                try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: store.url.deletingLastPathComponent().appendingPathComponent("categories.json"), options: .atomic)
                store.customCategories = categories
            case "pin":
                let enabled = body["enabled"] as? Bool == true
                UserDefaults.standard.set(enabled, forKey: "floating"); window.level = enabled ? .floating : .normal
            case "ready": ready = true; focusCapture()
            case "layout":
                if let value = body["height"] as? NSNumber { fitWindow(value.doubleValue) }
            default: break
            }
        } catch { report("Couldn’t save changes: \(error.localizedDescription)") }
    }
    func report(_ message: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: [message]), let json = String(data: data, encoding: .utf8) else { return }
        web?.evaluateJavaScript("window.brainoSaveFailed?.(\(json)[0])", completionHandler: nil)
    }
    func fitWindow(_ value: Double) {
        guard value.isFinite else { return }
        let maximum = min(720, (window.screen?.visibleFrame.height ?? 900) - 100)
        let height = max(300, min(maximum, value))
        if abs(height - web.bounds.height) > 2 {
            let top = NSPoint(x: window.frame.minX, y: window.frame.maxY)
            window.setContentSize(NSSize(width: web.bounds.width, height: height))
            window.setFrameTopLeftPoint(top)
        }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded = true
        webView.evaluateJavaScript("document.querySelector('.window').getBoundingClientRect().height + document.querySelector('.status').getBoundingClientRect().height") { [weak self] value, _ in
            if let number = value as? NSNumber { self?.fitWindow(number.doubleValue) }
        }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        decisionHandler(url.isFileURL || url.absoluteString == "about:blank" ? .allow : .cancel)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { show(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()
