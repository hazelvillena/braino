import AppKit
import SwiftUI
import Carbon

struct TaskItem: Codable, Identifiable {
    var id = UUID()
    var title: String
    var notes = ""
    var today = false
    var completed = false
    var created = Date()
}

final class TaskStore: ObservableObject {
    @Published var tasks: [TaskItem] = []
    @Published var error: String?
    let url: URL
    init() {
        url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Braino/tasks.json")
        reload()
    }
    func reload() {
        do {
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            tasks = try JSONDecoder().decode([TaskItem].self, from: Data(contentsOf: url))
            error = nil
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
    func add(_ title: String, today: Bool) {
        let text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, error == nil else { return }
        tasks.insert(TaskItem(title: text, today: today), at: 0); save()
    }
    func update(_ item: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == item.id }) else { return }
        tasks[index] = item; save()
    }
}

let ink = Color(red: 0.19, green: 0.23, blue: 0.21)
let accent = Color(red: 0.33, green: 0.43, blue: 0.32)
let paper = Color(red: 0.97, green: 0.96, blue: 0.93)

struct TaskRow: View {
    @EnvironmentObject var store: TaskStore
    let task: TaskItem
    @State private var expanded = false
    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Button { var t = task; t.completed.toggle(); store.update(t) } label: {
                Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21, weight: .light)).foregroundStyle(task.completed ? accent : Color.gray.opacity(0.5))
            }.buttonStyle(.plain).help(task.completed ? "Reopen task" : "Complete task")
            VStack(alignment: .leading, spacing: 8) {
                TextField("Task", text: Binding(get: { task.title }, set: { value in var t = task; t.title = value; store.update(t) }))
                    .textFieldStyle(.plain).font(.system(size: 14)).strikethrough(task.completed).foregroundStyle(task.completed ? .secondary : ink)
                if expanded {
                    TextField("Add a note…", text: Binding(get: { task.notes }, set: { value in var t = task; t.notes = value; store.update(t) }), axis: .vertical)
                        .textFieldStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
                } else if !task.notes.isEmpty {
                    Text(task.notes).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Button { var t = task; t.today.toggle(); store.update(t) } label: {
                Image(systemName: task.today ? "sun.max.fill" : "sun.max").foregroundStyle(task.today ? accent : Color.gray.opacity(0.4))
            }.buttonStyle(.plain).help(task.today ? "Remove from Today" : "Move to Today")
            Button { expanded.toggle() } label: { Image(systemName: "ellipsis").foregroundStyle(.secondary) }
                .buttonStyle(.plain).help("Show notes")
        }
        .padding(14).background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            Button("Delete task", role: .destructive) { store.tasks.removeAll { $0.id == task.id }; store.save() }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: TaskStore
    @State private var selection = "Today"
    @State private var draft = ""
    @AppStorage("floating") private var floating = false
    @FocusState private var capturing: Bool
    var visible: [TaskItem] {
        store.tasks.filter { selection == "Logbook" ? $0.completed : !$0.completed && (selection != "Today" || $0.today) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 7) { Image(systemName: "leaf.fill").foregroundStyle(accent); Text("braino").font(.system(size: 19, weight: .semibold, design: .serif)) }
                Spacer()
                Button { floating.toggle(); NotificationCenter.default.post(name: .init("BrainoFloating"), object: floating) } label: {
                    Image(systemName: floating ? "pin.fill" : "pin").foregroundStyle(floating ? accent : .secondary)
                }.buttonStyle(.plain).help("Keep above other windows")
            }.padding(.bottom, 27)
            HStack(spacing: 5) {
                ForEach(["Today", "Inbox", "Logbook"], id: \.self) { tab in
                    Button { selection = tab } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab == "Today" ? "sun.max" : tab == "Inbox" ? "tray" : "checkmark.circle")
                            Text(tab)
                        }.font(.system(size: 12, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 9)
                            .background(selection == tab ? Color.white : .clear, in: Capsule())
                            .foregroundStyle(selection == tab ? ink : .secondary)
                    }.buttonStyle(.plain)
                }
            }.padding(4).background(ink.opacity(0.045), in: Capsule())
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(selection).font(.system(size: 34, weight: .regular, design: .serif))
                    Text(selection == "Today" ? Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()) : selection == "Inbox" ? "A little space for everything on your mind." : "Look how far you’ve come.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(visible.count)").font(.system(size: 13, weight: .medium)).foregroundStyle(accent).padding(9).background(accent.opacity(0.09), in: Circle())
            }.padding(.top, 28).padding(.bottom, 22)
            if let error = store.error { Text(error).font(.caption).foregroundStyle(.red).padding(.bottom, 10) }
            ScrollView {
                LazyVStack(spacing: 8) {
                    if visible.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: selection == "Logbook" ? "checkmark.seal" : "sparkle").font(.system(size: 30, weight: .ultraLight)).foregroundStyle(accent)
                            Text(selection == "Logbook" ? "Small steps add up." : selection == "Today" ? "Make room for what matters." : "A clearer mind starts here.")
                                .font(.system(size: 18, design: .serif))
                            Text(selection == "Logbook" ? "Completed tasks will find a home here." : "Add a task below. Take it one thing at a time.")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity).padding(.vertical, 70)
                    }
                    ForEach(visible) { TaskRow(task: $0) }
                }.padding(.bottom, 12)
            }
            if selection != "Logbook" {
                HStack(spacing: 10) {
                    Image(systemName: "plus").foregroundStyle(accent)
                    TextField("What’s on your mind?", text: $draft).textFieldStyle(.plain).font(.system(size: 14)).focused($capturing)
                        .onSubmit { store.add(draft, today: selection == "Today"); draft = "" }
                    Text("↵").foregroundStyle(.tertiary)
                }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(accent.opacity(0.2)))
            }
            HStack { Text("ONE THING AT A TIME").tracking(1.6); Spacer(); Text("⌃ ⌥ SPACE") }
                .font(.system(size: 9, weight: .medium)).foregroundStyle(.tertiary).padding(.top, 18)
        }.padding(25).frame(minWidth: 400, minHeight: 500).background(paper).foregroundStyle(ink)
            .onReceive(NotificationCenter.default.publisher(for: .init("BrainoCapture"))) { _ in capturing = true }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = TaskStore()
    var window: NSWindow!
    var status: NSStatusItem!
    var hotkey: EventHotKeyRef?
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 650), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "Braino"; window.titleVisibility = .hidden; window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false; window.delegate = self
        window.contentView = NSHostingView(rootView: ContentView().environmentObject(store).padding(.top, 20))
        window.minSize = NSSize(width: 400, height: 530)
        window.backgroundColor = NSColor(calibratedRed: 0.97, green: 0.96, blue: 0.93, alpha: 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.level = UserDefaults.standard.bool(forKey: "floating") ? .floating : .normal
        if !window.setFrameAutosaveName("BrainoMain") { window.center() }
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "Braino tasks")
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Braino    ⌃⌥Space", action: #selector(show), keyEquivalent: "") .target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Braino", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        status.menu = menu
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, pointer in
            guard let pointer else { return noErr }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(pointer).takeUnretainedValue()
            DispatchQueue.main.async { delegate.show() }; return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), nil)
        let result = RegisterEventHotKey(UInt32(kVK_Space), UInt32(controlKey | optionKey), EventHotKeyID(signature: 0x53544C4C, id: 1), GetApplicationEventTarget(), 0, &hotkey)
        if result != noErr { store.error = "Shortcut unavailable. Use the menu bar to open Braino." }
        NotificationCenter.default.addObserver(forName: .init("BrainoFloating"), object: nil, queue: .main) { [weak self] note in self?.window.level = (note.object as? Bool == true) ? .floating : .normal }
        show()
    }
    @objc func show() {
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .init("BrainoCapture"), object: nil)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { show(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()
