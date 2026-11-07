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

struct TaskEditor: View {
    @State private var draft: TaskItem
    let onSave: (TaskItem) -> Void
    let onCancel: () -> Void
    init(task: TaskItem, onSave: @escaping (TaskItem) -> Void, onCancel: @escaping () -> Void) {
        _draft = State(initialValue: task); self.onSave = onSave; self.onCancel = onCancel
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().opacity(0.5)
            VStack(alignment: .leading, spacing: 5) {
                Text("Notes").font(.system(size: 10)).foregroundStyle(.secondary)
                TextField("Add a little context…", text: $draft.notes, axis: .vertical).lineLimit(2...6).textFieldStyle(.plain).padding(10).background(ink.opacity(0.025), in: RoundedRectangle(cornerRadius: 9))
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    Toggle("Due date · optional", isOn: Binding(get: { draft.dueDate != nil }, set: { draft.dueDate = $0 ? TaskDates.today : nil })).toggleStyle(.checkbox).font(.system(size: 10))
                    if draft.dueDate != nil { DatePicker("Due date", selection: Binding(get: { draft.dueDate ?? TaskDates.today }, set: { draft.dueDate = TaskDates.calendar.startOfDay(for: $0) }), displayedComponents: .date).labelsHidden() }
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Category").font(.system(size: 10)).foregroundStyle(.secondary)
                    TextField("None", text: Binding(get: { draft.bucket ?? "" }, set: { draft.bucket = $0.isEmpty ? nil : $0 })).textFieldStyle(.plain).padding(8).background(ink.opacity(0.025), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            HStack {
                if draft.dueDate != nil { Button("Clear due date") { draft.dueDate = nil }.foregroundStyle(.secondary) }
                Spacer()
                Button("Cancel", action: onCancel).foregroundStyle(.secondary)
                Button { onSave(draft) } label: { Text("Save").fontWeight(.semibold).padding(.horizontal, 12).padding(.vertical, 6).background(Color(red: 0.91, green: 0.93, blue: 0.87), in: RoundedRectangle(cornerRadius: 7)) }
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).keyboardShortcut(.return, modifiers: .command)
            }.buttonStyle(.plain).font(.system(size: 10))
        }.font(.system(size: 11, design: .rounded))
    }
}

struct WeeklyDaySection: View {
    @EnvironmentObject var store: TaskStore
    let day: Date
    let entries: [TaskItem]
    let bucket: String
    @State private var draft = ""
    @State private var open = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool
    private func add() {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        store.add(draft, date: day, bucket: ["All categories", "Uncategorized"].contains(bucket) ? "" : bucket)
        if store.error == nil { draft = "" }; focused = true
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.26)) { open.toggle() } } label: {
            HStack(spacing: 8) {
                Text(TaskDates.calendar.isDateInToday(day) ? "Today" : day.formatted(.dateTime.weekday(.wide)))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, TaskDates.calendar.isDateInToday(day) ? 5 : 0).padding(.vertical, 3)
                    .background(TaskDates.calendar.isDateInToday(day) ? sunflower.opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 5))
                Text(day.formatted(.dateTime.month(.abbreviated).day())).font(.system(size: 10)).foregroundStyle(.tertiary)
                Spacer()
                Text("\(entries.count)").font(.system(size: 9)).foregroundStyle(.tertiary)
                Image(systemName: "chevron.down").font(.system(size: 9)).rotationEffect(.degrees(open ? 0 : -90)).foregroundStyle(.secondary)
            }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(day.formatted(.dateTime.weekday(.wide)))
            if open {
            VStack(alignment: .leading, spacing: 5) {
            ForEach(entries) { TaskRow(task: $0, compact: true) }
            HStack(spacing: 10) {
                Image(systemName: "plus").font(.system(size: 12)).foregroundStyle(.tertiary).frame(width: 20)
                TextField("add something", text: $draft).font(.system(size: 11)).textFieldStyle(.plain).focused($focused).onSubmit(add)
                    .accessibilityLabel("Add task for \(day.formatted(.dateTime.weekday(.wide)))")
                if focused || !draft.isEmpty { Button(action: add) { Image(systemName: "return").font(.system(size: 10)).foregroundStyle(.secondary) }.buttonStyle(.plain).accessibilityLabel("Save task") }
            }.padding(.horizontal, 8).padding(.vertical, 6).overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(ink.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
            }.padding(.top, 5).transition(.opacity.combined(with: .move(edge: .top)))
            }
        }.padding(10).background(.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ink.opacity(0.06), lineWidth: 1))
            .onReceive(NotificationCenter.default.publisher(for: .init("BrainoCapture"))) { _ in if TaskDates.calendar.isDateInToday(day) { open = true; focused = false; DispatchQueue.main.async { focused = true } } }
    }
}

struct TaskRow: View {
    @EnvironmentObject var store: TaskStore
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let task: TaskItem
    var compact = false
    @State private var expanded = false
    @State private var notesOpen = false
    @State private var hovering = false
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
                TextField("Task", text: Binding(get: { task.title }, set: { value in
                    guard var current = store.tasks.first(where: { $0.id == task.id }) else { return }
                    current.title = value; store.update(current)
                }), axis: .vertical).textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(task.completed ? .secondary : ink)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(task.completed ? Color.gray : ink).frame(height: 1.5)
                            .scaleEffect(x: task.completed || finishing ? 1 : 0, y: 1, anchor: .leading)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.24), value: finishing).allowsHitTesting(false)
                    }
                if expanded {
                    TaskEditor(task: task) { edited in
                        guard var current = store.tasks.first(where: { $0.id == task.id }) else { return }
                        current.notes = edited.notes; current.dueDate = edited.dueDate
                        current.today = false; current.scheduled = edited.planned; current.bucket = edited.bucket?.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.update(current); if store.error == nil { expanded = false }
                    } onCancel: { expanded = false }
                } else if !task.notes.isEmpty && notesOpen {
                    TextField("Add a note…", text: Binding(get: { task.notes }, set: { value in
                        guard var current = store.tasks.first(where: { $0.id == task.id }) else { return }
                        current.notes = value; store.update(current)
                    }), axis: .vertical)
                        .textFieldStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1...20)
                        .padding(.vertical, 3).transition(.opacity.combined(with: .move(edge: .top))).clipped()

                }
                if let category = task.bucket, !category.isEmpty { Text(category).font(.system(size: 10)).foregroundStyle(.secondary) }
                if let due = task.dueDate { Text("Due \(due.formatted(date: .abbreviated, time: .omitted))").font(.system(size: 10)).foregroundStyle(.secondary) }
                if task.completed { Text(task.completedAt.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Completion date unavailable").font(.system(size: 9)).foregroundStyle(.tertiary) }
            }
            if !task.notes.isEmpty && !expanded {
                Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.26)) { notesOpen.toggle() } } label: {
                    Image(systemName: "chevron.down").font(.system(size: 9)).rotationEffect(.degrees(notesOpen ? 0 : -90)).foregroundStyle(.tertiary)
                }.buttonStyle(.plain).help(notesOpen ? "Hide notes" : "Show notes").accessibilityLabel("Notes for \(task.title)")
            }
            Button { expanded.toggle() } label: { Image(systemName: "ellipsis").foregroundStyle(.secondary) }.buttonStyle(.plain).help("Edit notes, date and category")
            Button { store.delete(task.id) } label: { Image(systemName: "trash").font(.system(size: 10)).foregroundStyle(.secondary) }
                .buttonStyle(.plain).opacity(hovering ? 1 : 0).allowsHitTesting(hovering && !finishing).disabled(finishing).help("Delete task").accessibilityLabel("Delete \(task.title)")
        }.padding(compact ? 6 : 11).background(finishing ? sunflower.opacity(0.08) : compact ? .clear : .white, in: RoundedRectangle(cornerRadius: 14))
            .onHover { hovering = $0 }
            .contextMenu { Button("Delete task", role: .destructive) { store.delete(task.id) }.disabled(finishing) }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: TaskStore
    @State private var selection = "Today"
    @State private var bucket = "All categories"
    @State private var draft = ""
    @State private var draftBucket = ""
    @State private var draftDate = TaskDates.today
    @State private var scheduleDraft = false
    @State private var captureDetails = false
    @State private var completedOpen = false
    @State private var range = "Past week"
    @State private var newCategoryOpen = false
    @State private var newCategory = ""
    @Namespace private var pillAnimation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = TaskDates.add(-6)
    @State private var end = TaskDates.today
    @AppStorage("floating") private var floating = false
    @FocusState private var capturing: Bool
    var visible: [TaskItem] { store.tasks.filter { TaskDates.active($0, view: selection, day: nil, bucket: bucket) } }
    var history: [TaskItem] { store.tasks.filter { TaskDates.history($0, range: range, start: start, end: end, bucket: bucket) }.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) } }
    var categories: [String] { Array(Set(store.customCategories + store.tasks.compactMap(\.bucket).filter { !$0.isEmpty })).sorted() }
    private func add() { guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }; store.add(draft, date: selection == "Someday" ? nil : TaskDates.today, bucket: draftBucket, dueDate: scheduleDraft ? draftDate : nil); if store.error == nil { draft = ""; scheduleDraft = false; captureDetails = false }; capturing = true }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            tabs
            HStack {
                Text(selection).font(.system(size: 19, weight: .semibold, design: .rounded)).tracking(-0.4)
                Spacer()
                categoryFilter
                Text("\(visible.count)").font(.system(size: 12, weight: .semibold)).padding(8).background(sunflower.opacity(0.22), in: Circle())
            }.padding(.top, 16).padding(.bottom, 8)
            if let error = store.error { Text(error).font(.caption).foregroundStyle(.red) }
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if visible.isEmpty && selection != "This week" { empty }
                    if selection == "This week" {
                        ForEach(TaskDates.week, id: \.self) { day in
                            let entries = visible.filter { $0.planned.map { TaskDates.calendar.isDate($0, inSameDayAs: day) } ?? false }
                            WeeklyDaySection(day: day, entries: entries, bucket: bucket).id(day)
                        }
                    } else { ForEach(visible) { TaskRow(task: $0) } }
                    completedSection.padding(.top, 10)
                }.padding(.bottom, selection == "This week" ? 300 : 16).id(selection)
                    .transition(reduceMotion ? .identity : .opacity.combined(with: .offset(y: 5)))
            }.frame(maxHeight: selection == "This week" ? 350 : .infinity)
                .onChange(of: selection) { _, value in
                    if value == "This week" { DispatchQueue.main.async { proxy.scrollTo(TaskDates.today, anchor: .top) } }
                }
            }
            if selection != "This week" { capture }
            HStack {
                Text("Log your to do’s.")
                Spacer(); Text("⌃ ⌥ Space").font(.system(size: 9))
            }.font(.system(size: 10, design: .rounded)).foregroundStyle(.tertiary).padding(.top, 16)
        }.padding(20).frame(minWidth: 410, minHeight: 390).background(paper).foregroundStyle(ink).tint(ink).preferredColorScheme(.light)
            .onReceive(NotificationCenter.default.publisher(for: .init("BrainoCapture"))) { _ in
                captureDetails = false; capturing = false
                DispatchQueue.main.async { capturing = true }
            }
    }
    var categoryFilter: some View {
                Picker("Category", selection: Binding(get: { bucket }, set: { value in
                    if value == "__new__" { newCategoryOpen = true } else { bucket = value; draftBucket = ["All categories", "Uncategorized"].contains(value) ? "" : value }
                })) { Text("All").tag("All categories"); Text("Uncategorized").tag("Uncategorized"); ForEach(categories, id: \.self) { Text($0).tag($0) }; Divider(); Text("New category…").tag("__new__") }.labelsHidden().pickerStyle(.menu).font(.system(size: 10)).fixedSize().padding(.horizontal, 5).padding(.vertical, 2).background(ink.opacity(0.025), in: Capsule())
                    .popover(isPresented: $newCategoryOpen) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("New category").font(.system(size: 13, weight: .semibold, design: .rounded))
                            TextField("Category name…", text: $newCategory).textFieldStyle(.roundedBorder).onSubmit(createCategory)
                            HStack { Button("Cancel") { newCategoryOpen = false; newCategory = "" }; Spacer(); Button("Create", action: createCategory).disabled(newCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                        }.padding(16).frame(width: 230)
                    }
    }
    private func createCategory() {
        if let name = store.addCategory(newCategory) { bucket = name; draftBucket = name; newCategory = ""; newCategoryOpen = false }
    }
    var header: some View {
        HStack(spacing: 5) {
            BrandMark(size: 36); Text("braino").font(.system(size: 26, weight: .heavy, design: .rounded)).tracking(-1)
            Spacer()
            Button { floating.toggle(); NotificationCenter.default.post(name: .init("BrainoFloating"), object: floating) } label: {
                Image(systemName: floating ? "pin.fill" : "pin").font(.system(size: 10)).padding(8).background(floating ? sunflower : .clear, in: RoundedRectangle(cornerRadius: 9))
            }.buttonStyle(.plain).help("Keep on top").accessibilityLabel("Keep on top")
        }.padding(.bottom, 14)
    }
    var tabs: some View {
        HStack(spacing: 3) {
            ForEach(["Today", "This week", "Someday"], id: \.self) { tab in
                Button { withAnimation(reduceMotion ? nil : .spring(response: 0.43, dampingFraction: 0.85)) { selection = tab }; captureDetails = false; } label: {
                    Label(tab, systemImage: tab == "Today" ? "sun.max" : tab == "This week" ? "calendar" : "cloud")
                        .font(.system(size: 11, weight: .semibold, design: .rounded)).padding(.horizontal, 11).padding(.vertical, 6)
                        .background { if selection == tab { Capsule().fill(sunflower).matchedGeometryEffect(id: "planning-pill", in: pillAnimation) } }.foregroundStyle(selection == tab ? ink : .secondary)
                }.buttonStyle(.plain)
            }
        }.padding(3).background(ink.opacity(0.035), in: Capsule())
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
            if store.lastCompleted != nil || store.lastDeleted != nil { HStack { Text(store.lastDeleted != nil ? "Task deleted." : "A little lighter.").foregroundStyle(.secondary); Spacer(); Button("Undo") { store.undo() }.buttonStyle(.plain) }.font(.system(size: 10)) }
        }
    }
    var capture: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 11) {
                Button(action: add) { Image(systemName: "plus").font(.system(size: 13)).foregroundStyle(.secondary).frame(width: 20, height: 20) }.buttonStyle(.plain).accessibilityLabel("Add task")
                TextField("add something", text: $draft).textFieldStyle(.plain).font(.system(size: 12)).focused($capturing).onSubmit(add)
                Button { captureDetails.toggle() } label: { Image(systemName: "slider.horizontal.3").font(.system(size: 11)).foregroundStyle(.tertiary) }.buttonStyle(.plain).help("Optional due date and category")
            }.padding(.horizontal, 11).padding(.vertical, 10).background(.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 11)).overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(ink.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
            if captureDetails {
                HStack(spacing: 5) {
                    if scheduleDraft {
                        Text("Due").font(.system(size: 9)).foregroundStyle(.secondary)
                        DatePicker("Due date", selection: $draftDate, displayedComponents: .date).labelsHidden().font(.system(size: 10))
                        Button { scheduleDraft = false } label: { Image(systemName: "xmark").font(.system(size: 8)) }.buttonStyle(.plain).help("Remove due date")
                    } else {
                        Button { scheduleDraft = true; draftDate = TaskDates.today } label: { Label("Add due date", systemImage: "calendar").font(.system(size: 10)).foregroundStyle(.secondary) }.buttonStyle(.plain)
                    }
                    Menu {
                        Button("No category") { draftBucket = "" }
                        ForEach(categories, id: \.self) { name in Button(name) { draftBucket = name } }
                        Divider(); Button("New category…") { newCategoryOpen = true }
                    } label: { Text(draftBucket.isEmpty ? "No category" : draftBucket).font(.system(size: 9)) }.menuStyle(.borderlessButton).fixedSize()
                }.padding(.leading, 40).padding(.bottom, 3)
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
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 560), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "Braino"; window.titleVisibility = .hidden; window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false; window.delegate = self
        window.contentView = NSHostingView(rootView: ContentView().environmentObject(store).padding(.top, 20))
        window.minSize = NSSize(width: 440, height: 460)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { NotificationCenter.default.post(name: .init("BrainoCapture"), object: nil) }
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
