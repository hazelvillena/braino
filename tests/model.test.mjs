import test from 'node:test';
import assert from 'node:assert/strict';
import {dayKey,addDays,weekDays,normalize,activeTasks,completedTasks,toggleTask,captureTask,moveTask,restoreTaskOrder} from '../preview/model.mjs';
const now=new Date('2026-11-06T12:00:00');
const open=(id,date,bucket='')=>({id,title:id,date,bucket,completed:false});
test('Today includes overdue but excludes future and undated tasks',()=>{const tasks=[open('old','2026-10-01'),open('today','2026-11-06'),open('later','2026-11-07'),open('someday',null)];assert.deepEqual(activeTasks(tasks,'Today',null,'all',now).map(t=>t.id),['old','today']);assert.deepEqual(activeTasks(tasks,'Someday',null,'all',now).map(t=>t.id),['someday']);});
test('Week is Monday through Sunday, with explicit day selection and optional buckets',()=>{assert.deepEqual(weekDays(now),['2026-11-02','2026-11-03','2026-11-04','2026-11-05','2026-11-06','2026-11-07','2026-11-08']);const tasks=[open('monday','2026-11-02','Work'),open('sunday','2026-11-08'),open('next','2026-11-09')];assert.equal(activeTasks(tasks,'This week',null,'all',now).length,2);assert.deepEqual(activeTasks(tasks,'This week','2026-11-02','Work',now).map(t=>t.id),['monday']);assert.deepEqual(activeTasks(tasks,'This week',null,'none',now).map(t=>t.id),['sunday']);});
test('Completion timestamps drive inclusive day and custom ranges; reopening clears them',()=>{const tasks=[{...open('done','2026-11-06'),completed:true,completedAt:'2026-11-06T12:00:00'},{...open('lastweek',null),completed:true,completedAt:'2026-10-30T12:00:00'},{...open('unknown',null),completed:true,completedAt:null}];assert.deepEqual(completedTasks(tasks,'day','','','all',now).map(t=>t.id),['done']);assert.deepEqual(completedTasks(tasks,'week','','','all',now).map(t=>t.id),['done']);assert.equal(completedTasks(tasks,'month','','','all',now).length,2);assert.equal(completedTasks(tasks,'all','','','all',now).length,3);assert.deepEqual(completedTasks(tasks,'custom','2026-10-30','2026-10-30','all',now).map(t=>t.id),['lastweek']);assert.equal(completedTasks(tasks,'custom','2026-11-07','2026-11-01','all',now).length,0);const done=toggleTask(open('new',null),now);assert.equal(done.completedAt,now.toISOString());assert.equal(toggleTask(done,now).completedAt,null);});
test('Legacy tasks migrate without inventing completion dates',()=>{const tasks=normalize([{id:'old',title:'old',today:true,completed:true}],now);assert.equal(tasks[0].date,'2026-11-06');assert.equal(tasks[0].completedAt,null);assert.equal(tasks[0].bucket,'');});
test('Date arithmetic follows calendar dates across daylight saving',()=>{assert.equal(addDays('2026-11-01',1),'2026-11-02');assert.equal(dayKey(now),'2026-11-06');});

test('Capture belongs to the active view regardless of its optional due date',()=>{const today=captureTask('  A thought  ','Today',{dueDate:'2026-12-25'},now);assert.equal(today.title,'A thought');assert.equal(today.date,'2026-11-06');assert.equal(today.dueDate,'2026-12-25');assert.equal(activeTasks([today],'Today',null,'all',now).length,1);const someday=captureTask('An idea','Someday',{dueDate:'2026-11-06'},now);assert.equal(someday.date,null);assert.equal(activeTasks([someday],'Someday',null,'all',now).length,1);const week=captureTask('Friday task','This week',{},now);assert.equal(week.dueDate,null);assert.equal(activeTasks([week],'This week',null,'all',now).length,1);});

test('Reordering survives persistence and preserves task data and hidden neighbors',()=>{
 const tasks=[{...open('a','2026-11-06','Work'),notes:'Keep me',dueDate:'2026-12-25'},open('hidden','2026-11-06','Personal'),open('b','2026-11-06','Work'),open('c','2026-11-06')];
 const moved=moveTask(tasks,'a',{targetId:'b',after:true});
 assert.deepEqual(moved.map(t=>t.id),['hidden','b','a','c']);
 assert.equal(moved[2].notes,'Keep me');assert.equal(moved[2].dueDate,'2026-12-25');assert.equal(moved[2].bucket,'Work');
 assert.deepEqual(normalize(JSON.parse(JSON.stringify(moved)),now).map(t=>t.id),['hidden','b','a','c']);
 assert.deepEqual(tasks.map(t=>t.id),['a','hidden','b','c']);
 assert.deepEqual(moveTask(moved,'c',{targetId:'b'}).map(t=>t.id),['hidden','c','b','a']);
});
test('Weekly drops move to an empty or populated day without changing the due date',()=>{
 const tasks=[{...open('a','2026-11-06'),dueDate:'2026-12-25'},open('b','2026-11-07')];
 const empty=moveTask(tasks,'a',{date:'2026-11-08'});assert.equal(empty.find(t=>t.id==='a').date,'2026-11-08');assert.equal(empty.find(t=>t.id==='a').dueDate,'2026-12-25');
 const populated=moveTask(tasks,'a',{date:'2026-11-07'});assert.deepEqual(populated.map(t=>t.id),['b','a']);
 assert.equal(populated[1].date,'2026-11-07');
 const before=moveTask(tasks,'a',{targetId:'b',date:'2026-11-07'});assert.deepEqual(before.map(t=>t.id),['a','b']);assert.equal(before[0].date,'2026-11-07');
});
test('Invalid, self and completed drops cannot corrupt ordering',()=>{
 const tasks=[open('a',null),{...open('done',null),completed:true}];
 assert.equal(moveTask(tasks,'a',{targetId:'a'}),tasks);assert.equal(moveTask(tasks,'missing',{targetId:'a'}),tasks);assert.equal(moveTask(tasks,'a',{targetId:'missing'}),tasks);assert.equal(moveTask(tasks,'done',{targetId:'a'}),tasks);assert.equal(moveTask(tasks,'a',{targetId:'done'}),tasks);
});
test('Move undo restores placement and order without erasing later edits or newly added tasks',()=>{
 const tasks=[open('a','2026-11-06'),open('b','2026-11-07')];const moved=moveTask(tasks,'a',{date:'2026-11-07'});moved.find(t=>t.id==='a').notes='An edit made later';moved.unshift(open('new',null));
 const restored=restoreTaskOrder(moved,['a','b'],'a','2026-11-06');assert.deepEqual(restored.map(t=>t.id),['a','b','new']);assert.equal(restored[0].date,'2026-11-06');assert.equal(restored[0].notes,'An edit made later');
});
