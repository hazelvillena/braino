import AppKit
import SwiftUI
import Carbon

struct TaskItem: Codable, Identifiable {
    var id = UUID()
    var title: String
    var notes = ""
    var today = false // Legacy flag, migrated on load.
    var completed = false
    var created = Date()
    var scheduled: Date? = nil
    var completedAt: Date? = nil
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
    let url: URL
    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Braino/tasks.json")
        reload()
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
    func add(_ title: String, date: Date?, bucket: String) {
        let text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, error == nil else { return }
        let category = bucket.trimmingCharacters(in: .whitespacesAndNewlines)
        tasks.insert(TaskItem(title: text, scheduled: date, bucket: category.isEmpty ? nil : category), at: 0); save()
    }
    func update(_ item: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == item.id }) else { return }
        tasks[index] = item; save()
    }
    func toggle(_ id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].completed.toggle()
        tasks[index].completedAt = tasks[index].completed ? Date() : nil
        if tasks[index].completed { lastCompleted = id }
        save()
    }
    func undo() {
        guard let id = lastCompleted, let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].completed = false; tasks[index].completedAt = nil; lastCompleted = nil; save()
    }
}

// Braino design tokens: lemon, carbon and a quiet neutral canvas.
let ink = Color(red: 25.0/255, green: 26.0/255, blue: 23.0/255)
let sunflower = Color(red: 245.0/255, green: 217.0/255, blue: 40.0/255)
let paper = Color(red: 249.0/255, green: 248.0/255, blue: 242.0/255)

struct BrandMark: View {
    var size: CGFloat = 43
    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: "BrainoIcon", withExtension: "png"), let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
            } else { Image(systemName: "brain").resizable().scaledToFit().padding(8) }
        }.frame(width: size, height: size).accessibilityLabel("Braino")
    }
}

struct TaskRow: View {
    @EnvironmentObject var store: TaskStore
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let task: TaskItem
    @State private var expanded = false
    @State private var finishing = false
    private func finish() {
        guard !finishing else { return }
        if task.completed || reduceMotion { store.toggle(task.id); return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) { finishing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeOut(duration: 0.16)) { store.toggle(task.id) }
            finishing = false
        }
    }
    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Button(action: finish) {
                ZStack {
                    Circle().strokeBorder(task.completed || finishing ? sunflower : Color.gray.opacity(0.45), lineWidth: 1.4)
                        .background(Circle().fill(task.completed || finishing ? sunflower : .clear))
                    if task.completed || finishing { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(ink) }
                }.frame(width: 20, height: 20).scaleEffect(finishing ? 1.08 : 1)
            }.buttonStyle(.plain).disabled(finishing).help(task.completed ? "Reopen task" : "Complete task").accessibilityLabel(task.completed ? "Reopen \(task.title)" : "Complete \(task.title)")
            VStack(alignment: .leading, spacing: 6) {
                TextField("Task", text: Binding(get: { task.title }, set: { value in var t = task; t.title = value; store.update(t) }))
                    .textFieldStyle(.plain).font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(task.completed ? .secondary : ink)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(task.completed ? Color.gray : ink).frame(height: 1.5)
                            .scaleEffect(x: task.completed || finishing ? 1 : 0, y: 1, anchor: .leading)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.24), value: finishing).allowsHitTesting(false)
                    }
                if expanded {
                    TextField("Notes", text: Binding(get: { task.notes }, set: { value in var t = task; t.notes = value; store.update(t) }), axis: .vertical)
                        .textFieldStyle(.roundedBorder).font(.system(size: 11))
                    HStack {
                        TextField("Category · optional", text: Binding(get: { task.bucket ?? "" }, set: { value in var t = task; t.bucket = value.isEmpty ? nil : value; store.update(t) })).textFieldStyle(.roundedBorder)
                        Menu {
                            Button("Today") { var t = task; t.today = false; t.scheduled = TaskDates.today; store.update(t) }
                            Button("Tomorrow") { var t = task; t.today = false; t.scheduled = TaskDates.add(1); store.update(t) }
                            Button("Someday") { var t = task; t.today = false; t.scheduled = nil; store.update(t) }
                        } label: { Label("When", systemImage: "calendar") }
                    }.font(.system(size: 10))
                    if let date = task.planned {
                        DatePicker("Scheduled", selection: Binding(get: { date }, set: { value in var t = task; t.today = false; t.scheduled = TaskDates.calendar.startOfDay(for: value); store.update(t) }), displayedComponents: .date).font(.system(size: 10))
                    }
                } else if !task.notes.isEmpty { Text(task.notes).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2) }
                if let category = task.bucket, !category.isEmpty { Text(category).font(.system(size: 10)).foregroundStyle(.secondary) }
                if task.completed { Text(task.completedAt.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Completion date unavailable").font(.system(size: 9)).foregroundStyle(.tertiary) }
                else if let date = task.planned, date < TaskDates.today { Text("Earlier · \(date.formatted(date: .abbreviated, time: .omitted))").font(.system(size: 9)).foregroundStyle(.secondary) }
            }
            Button { expanded.toggle() } label: { Image(systemName: "ellipsis").foregroundStyle(.secondary) }.buttonStyle(.plain).help("Edit notes, date and category")
        }.padding(14).background(finishing ? sunflower.opacity(0.08) : .white.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
            .contextMenu { Button("Delete task", role: .destructive) { store.tasks.removeAll { $0.id == task.id }; store.save() } }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: TaskStore
    @State private var selection = "Today"
    @State private var selectedDay: Date? = nil
    @State private var bucket = "All categories"
    @State private var draft = ""
    @State private var draftBucket = ""
    @State private var draftDate = TaskDates.today
    @State private var scheduleDraft = true
    @State private var captureDetails = false
    @State private var completedOpen = false
    @State private var range = "Past day"
    @State private var start = TaskDates.add(-6)
    @State private var end = TaskDates.today
    @AppStorage("floating") private var floating = false
    @FocusState private var capturing: Bool
    var visible: [TaskItem] { store.tasks.filter { TaskDates.active($0, view: selection, day: selectedDay, bucket: bucket) } }
    var history: [TaskItem] { store.tasks.filter { TaskDates.history($0, range: range, start: start, end: end, bucket: bucket) }.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) } }
    var categories: [String] { Array(Set(store.tasks.compactMap(\.bucket).filter { !$0.isEmpty })).sorted() }
    private func add() { guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }; store.add(draft, date: scheduleDraft ? draftDate : nil, bucket: draftBucket); if store.error == nil { draft = "" }; capturing = true }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            tabs
            HStack {
                Text(selection).font(.system(size: 31, weight: .bold, design: .rounded)).tracking(-1)
                Spacer()
                Text("\(visible.count)").font(.system(size: 12, weight: .semibold)).padding(8).background(sunflower.opacity(0.22), in: Circle())
            }.padding(.top, 25)
            Text(selection == "Today" ? Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()) : selection == "This week" ? "A little room to plan ahead." : "Good ideas. No rush.")
                .font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 5).padding(.bottom, 18)
            if selection == "This week" { weekStrip.padding(.bottom, 16) }
            HStack {
                Picker("Category", selection: $bucket) { Text("All categories").tag("All categories"); Text("Uncategorized").tag("Uncategorized"); ForEach(categories, id: \.self) { Text($0).tag($0) } }.labelsHidden().frame(maxWidth: 170)
                Spacer(); Text("Small steps count.").font(.system(size: 10)).foregroundStyle(.tertiary)
            }.padding(.bottom, 10)
            if let error = store.error { Text(error).font(.caption).foregroundStyle(.red) }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if visible.isEmpty { empty }
                    if selection == "This week" && selectedDay == nil {
                        ForEach(TaskDates.week, id: \.self) { day in
                            let entries = visible.filter { $0.planned.map { TaskDates.calendar.isDate($0, inSameDayAs: day) } ?? false }
                            if !entries.isEmpty {
                                Text(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).padding(.top, 8)
                                ForEach(entries) { TaskRow(task: $0) }
                            }
                        }
                    } else { ForEach(visible) { TaskRow(task: $0) } }
                    completedSection.padding(.top, 12)
                }.padding(.bottom, 16)
            }
            capture
            HStack {
                Text("Take it easy. One thing at a time.")
                Spacer(); Text("⌃ ⌥ Space").font(.system(size: 9))
            }.font(.system(size: 10, design: .rounded)).foregroundStyle(.tertiary).padding(.top, 16)
        }.padding(25).frame(minWidth: 410, minHeight: 570).background(paper).foregroundStyle(ink).tint(ink).preferredColorScheme(.light)
            .onReceive(NotificationCenter.default.publisher(for: .init("BrainoCapture"))) { _ in capturing = true }
    }
    var header: some View {
        HStack(spacing: 5) {
            BrandMark(); Text("braino").font(.system(size: 26, weight: .heavy, design: .rounded)).tracking(-1)
            Spacer()
            Button { floating.toggle(); NotificationCenter.default.post(name: .init("BrainoFloating"), object: floating) } label: {
                Label("Keep on top", systemImage: floating ? "pin.fill" : "pin").font(.system(size: 10)).padding(8).background(floating ? sunflower : .clear, in: RoundedRectangle(cornerRadius: 9))
            }.buttonStyle(.plain).help("Keep Braino above other windows").accessibilityLabel("Keep Braino above other windows")
        }.padding(.bottom, 25)
    }
    var tabs: some View {
        HStack(spacing: 3) {
            ForEach(["Today", "This week", "Someday"], id: \.self) { tab in
                Button { selection = tab; selectedDay = nil; scheduleDraft = tab != "Someday"; draftDate = TaskDates.today } label: {
                    Label(tab, systemImage: tab == "Today" ? "sun.max" : tab == "This week" ? "calendar" : "cloud")
                        .font(.system(size: 12, weight: .semibold, design: .rounded)).padding(.horizontal, 12).padding(.vertical, 9)
                        .background(selection == tab ? sunflower : .clear, in: Capsule()).foregroundStyle(selection == tab ? ink : .secondary)
                }.buttonStyle(.plain)
            }
        }.padding(4).background(ink.opacity(0.035), in: Capsule())
    }
    var weekStrip: some View {
        HStack(spacing: 3) {
            Button { selectedDay = nil; draftDate = TaskDates.today } label: { Text("All").font(.system(size: 10)).frame(maxWidth: .infinity, minHeight: 40).background(selectedDay == nil ? ink.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 10)) }.buttonStyle(.plain)
            ForEach(TaskDates.week, id: \.self) { day in
                Button { selectedDay = day; draftDate = day } label: {
                    VStack(spacing: 4) { Text(day.formatted(.dateTime.weekday(.narrow))).font(.system(size: 9)); Text(day.formatted(.dateTime.day())).font(.system(size: 11, weight: .semibold)) }
                        .frame(maxWidth: .infinity, minHeight: 40).background(selectedDay == day ? sunflower.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain).help(day.formatted(date: .complete, time: .omitted))
            }
        }
    }
    var empty: some View {
        VStack(spacing: 9) {
            BrandMark(size: 60).opacity(0.65)
            Text(selection == "Today" ? "A little breathing room." : selection == "Someday" ? "Let an idea land here." : "A little room in your week.").font(.system(size: 17, weight: .semibold, design: .rounded))
            Text("Add one thing below. Take it at your pace.").font(.system(size: 11)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 28)
    }
    var completedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            DisclosureGroup(isExpanded: $completedOpen) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Show", selection: $range) { ForEach(["Past day", "Past week", "Past month", "All time", "Custom range"], id: \.self) { Text($0).tag($0) } }.font(.system(size: 10)).padding(.top, 10)
                    if range == "Custom range" {
                        DatePicker("From", selection: $start, displayedComponents: .date)
                        DatePicker("To", selection: $end, displayedComponents: .date)
                    }
                    if history.isEmpty { Text(start > end && range == "Custom range" ? "Choose an end date on or after the start date." : "No completed tasks in this range.").font(.system(size: 11)).foregroundStyle(.secondary) }
                    ForEach(history) { TaskRow(task: $0) }
                }
            } label: {
                HStack {
                    Text("Completed").font(.system(size: 11, weight: .semibold))
                    Spacer(); Text("\(store.tasks.filter { $0.completed && TaskDates.matchesBucket($0, bucket) }.count)").font(.system(size: 10))
                }.foregroundStyle(.secondary)
            }
            if store.lastCompleted != nil { HStack { Text("A little lighter.").foregroundStyle(.secondary); Spacer(); Button("Undo") { store.undo() }.buttonStyle(.plain) }.font(.system(size: 10)) }
        }
    }
    var capture: some View {
        VStack(spacing: 10) {
            HStack(spacing: 11) {
                Button(action: add) { Image(systemName: "plus").font(.system(size: 12, weight: .bold)).padding(7).background(sunflower, in: RoundedRectangle(cornerRadius: 8)) }.buttonStyle(.plain).accessibilityLabel("Add task")
                TextField("One thing on your mind…", text: $draft).textFieldStyle(.plain).font(.system(size: 12)).focused($capturing).onSubmit(add)
                Button { captureDetails.toggle() } label: { Image(systemName: "slider.horizontal.3").foregroundStyle(.secondary) }.buttonStyle(.plain).help("Task date and category")
            }.padding(13).background(.white, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(sunflower.opacity(0.65), lineWidth: 1.5))
            if captureDetails {
                HStack { Toggle("Schedule", isOn: $scheduleDraft); if scheduleDraft { DatePicker("When", selection: $draftDate, displayedComponents: .date).labelsHidden() } }.font(.system(size: 10))
                TextField("Category · optional (for example, Work)", text: $draftBucket).textFieldStyle(.roundedBorder).font(.system(size: 11))
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = TaskStore()
    var window: NSWindow!
    var status: NSStatusItem!
    var hotkey: EventHotKeyRef?
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 720), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "Braino"; window.titleVisibility = .hidden; window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false; window.delegate = self
        window.contentView = NSHostingView(rootView: ContentView().environmentObject(store).padding(.top, 20))
        window.minSize = NSSize(width: 460, height: 650)
        window.backgroundColor = NSColor(calibratedRed: 249.0/255, green: 248.0/255, blue: 242.0/255, alpha: 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.level = UserDefaults.standard.bool(forKey: "floating") ? .floating : .normal
        if !window.setFrameAutosaveName("BrainoMain") { window.center() }
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let url = Bundle.main.url(forResource: "BrainoMenu", withExtension: "png"), let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 19, height: 19); image.isTemplate = true
            status.button?.image = image
        }
        status.button?.setAccessibilityLabel("Braino tasks")
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
if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--render-preview" {
    try MainActor.assumeIsolated {
    let previewStore = TaskStore()
    previewStore.tasks = [TaskItem(title: "Make space for a good idea", today: true), TaskItem(title: "A little progress on Braino", notes: "One small step is enough.", today: true), TaskItem(title: "Take a proper screen break", today: true)]
    let renderer = ImageRenderer(content: ContentView().environmentObject(previewStore).frame(width: 440, height: 630))
    renderer.scale = 2
    if let image = renderer.nsImage, let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) {
        try png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
        exit(0)
    }
    exit(1)
    }
}
let delegate = AppDelegate()
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()
