let fixture = URL(fileURLWithPath: CommandLine.arguments[1])
let originalID = UUID()
let legacy: [[String: Any]] = [["id":originalID.uuidString,"title":"Legacy Today task","notes":"Keep this note","today":true,"completed":false,"created":0]]
try JSONSerialization.data(withJSONObject: legacy).write(to: fixture)
let store = TaskStore(url: fixture)
precondition(store.error == nil && store.tasks.count == 1)
precondition(store.tasks[0].id == originalID && store.tasks[0].notes == "Keep this note")
precondition(!store.tasks[0].today && store.tasks[0].scheduled == TaskDates.today)
let reopened = TaskStore(url: fixture)
precondition(reopened.tasks[0].scheduled == TaskDates.today)
store.toggle(originalID)
precondition(store.tasks[0].completed && store.tasks[0].completedAt != nil)
precondition(TaskDates.history(store.tasks[0], range: "Past day", start: TaskDates.today, end: TaskDates.today, bucket: "All categories"))
store.undo()
precondition(!store.tasks[0].completed && store.tasks[0].completedAt == nil)
store.add("Someday idea", date: nil, bucket: "")
precondition(TaskDates.active(store.tasks[0], view: "Someday", day: nil, bucket: "Uncategorized"))
store.add("Weekly work", date: TaskDates.week[0], bucket: "Work")
precondition(TaskDates.active(store.tasks[0], view: "This week", day: TaskDates.week[0], bucket: "Work"))
precondition(!TaskDates.active(store.tasks[0], view: "This week", day: TaskDates.week[6], bucket: "Work"))
var unknown = TaskItem(title:"Legacy completed",completed:true)
precondition(!TaskDates.history(unknown, range:"Past day", start:TaskDates.today,end:TaskDates.today,bucket:"All categories"))
precondition(TaskDates.history(unknown, range:"All time", start:TaskDates.today,end:TaskDates.today,bucket:"All categories"))
unknown.completedAt = TaskDates.add(-7)
precondition(!TaskDates.history(unknown, range:"Past week", start:TaskDates.today,end:TaskDates.today,bucket:"All categories"))
precondition(TaskDates.history(unknown, range:"Custom range", start:TaskDates.add(-7),end:TaskDates.add(-7),bucket:"All categories"))
print("Native checks passed: legacy migration, persistence, completion/undo, scheduling, categories and completion ranges.")

precondition(store.addCategory("  Studio  ") == "Studio")
precondition(store.addCategory("studio") == "Studio")
let categoriesReloaded = TaskStore(url: fixture)
precondition(categoriesReloaded.customCategories.filter { $0 == "Studio" }.count == 1)
precondition(store.addCategory("   ") == nil)
print("Native category checks passed: creation, trimming, deduplication and persistence without tasks.")

store.add("Optional due", date: TaskDates.today, bucket: "", dueDate: TaskDates.add(30))
precondition(TaskDates.active(store.tasks[0], view:"Today",day:nil,bucket:"All categories"))
precondition(store.tasks[0].dueDate == TaskDates.add(30))
store.add("Someday with due", date:nil,bucket:"",dueDate:TaskDates.today)
precondition(TaskDates.active(store.tasks[0],view:"Someday",day:nil,bucket:"All categories"))
print("Due-date independence checks passed.")

let beforeDelete = store.tasks[0]
let countBeforeDelete = store.tasks.count
store.delete(beforeDelete.id)
precondition(store.tasks.count == countBeforeDelete - 1)
precondition(!store.tasks.contains { $0.id == beforeDelete.id })
store.undo()
precondition(store.tasks.count == countBeforeDelete)
precondition(store.tasks[0].id == beforeDelete.id && store.tasks[0].title == beforeDelete.title)
precondition(TaskStore(url: fixture).tasks[0].id == beforeDelete.id)
print("Deletion checks passed: removal, exact restoration and persistence.")

let bridgeState = DesktopBridge.state(store, floating: true)
let bridgeJSON = try JSONSerialization.data(withJSONObject: bridgeState)
let decodedState = try JSONSerialization.jsonObject(with: bridgeJSON) as! [String: Any]
let roundTrip = try DesktopBridge.tasks(decodedState["tasks"] as! [[String: Any]], existing: store.tasks)
precondition(roundTrip.count == store.tasks.count)
for (old, new) in zip(store.tasks, roundTrip) {
 precondition(old.id == new.id && old.title == new.title && old.notes == new.notes && old.created == new.created)
 precondition(old.scheduled == new.scheduled && old.dueDate == new.dueDate && old.completed == new.completed)
}
do {
 let duplicate = (decodedState["tasks"] as! [[String: Any]])[0]
 _ = try DesktopBridge.tasks([duplicate, duplicate], existing: store.tasks)
 fatalError("Duplicate IDs must be rejected")
} catch DesktopBridge.Failure.invalidTask { }
print("Desktop bridge checks passed: JSON validity, complete data round-trip, existing creation dates and duplicate rejection.")
