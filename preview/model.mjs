export const dayKey = (value = new Date()) => { const d = new Date(value); return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`; };
export const parseDay = key => new Date(`${key}T00:00:00`);
export const addDays = (key, amount) => { const d = parseDay(key); d.setDate(d.getDate()+amount); return dayKey(d); };
export function weekDays(now = new Date()) { const d = new Date(now); d.setDate(d.getDate()-((d.getDay()+6)%7)); return Array.from({length:7},(_,i)=>addDays(dayKey(d),i)); }
export function normalize(tasks, now = new Date()) { return tasks.filter(t=>t && typeof t.title==='string').map(t=>({...t, notes:typeof t.notes==='string'?t.notes:'', bucket:typeof t.bucket==='string'?t.bucket:'', date:t.date || (t.today ? dayKey(now):null), completed:!!t.completed, completedAt:t.completedAt || null,dueDate:t.dueDate||null})); }
export function activeTasks(tasks, view, day, bucket, now = new Date()) { const today=dayKey(now), week=weekDays(now);return tasks.filter(t=>!t.completed && (bucket==='all'||(bucket==='none'?!t.bucket:t.bucket===bucket)) && (view==='Today' ? !!t.date&&t.date<=today : view==='Someday' ? !t.date : day ? t.date===day : t.date>=week[0]&&t.date<=week[6])); }
export function completedTasks(tasks, range, start, end, bucket, now = new Date()) { const today=dayKey(now), lower=range==='day'?today:range==='week'?addDays(today,-6):range==='month'?addDays(today,-29):range==='custom'?start:null;return tasks.filter(t=>t.completed&&(bucket==='all'||(bucket==='none'?!t.bucket:t.bucket===bucket))&&(!lower||!!t.completedAt&&dayKey(t.completedAt)>=lower&&dayKey(t.completedAt)<=(range==='custom'?end:today))).sort((a,b)=>(b.completedAt||'').localeCompare(a.completedAt||'')); }
export function toggleTask(task, now=new Date()) { return {...task,completed:!task.completed,completedAt:task.completed?null:now.toISOString()}; }

export function captureTask(title, view, {dueDate=null,bucket='',day=null}={}, now=new Date()) { return {id:crypto.randomUUID(),title:title.trim(),notes:'',date:view==='Someday'?null:(day||dayKey(now)),dueDate,bucket,completed:false,completedAt:null}; }

export function moveTask(tasks, id, {targetId=null, after=false, date=undefined}={}) {
  const source=tasks.find(t=>t.id===id);
  if(!source || source.completed || targetId===id) return tasks;
  const target=targetId?tasks.find(t=>t.id===targetId):null;
  if(targetId && (!target || target.completed)) return tasks;
  if(!targetId && date===undefined) return tasks;
  const result=tasks.filter(t=>t.id!==id);
  const moved=date===undefined?source:{...source,date};
  let index;
  if(target){index=result.findIndex(t=>t.id===targetId)+(after?1:0)}
  else {const siblings=result.map((t,i)=>({t,i})).filter(({t})=>!t.completed&&t.date===date);index=siblings.length?siblings.at(-1).i+1:result.length}
  result.splice(index,0,moved);
  return result;
}

export function restoreTaskOrder(tasks, order, movedId, previousDate) {
  const ranks=new Map(order.map((id,index)=>[id,index]));
  return tasks.map(t=>t.id===movedId?{...t,date:previousDate}:t).sort((a,b)=>(ranks.get(a.id)??Infinity)-(ranks.get(b.id)??Infinity));
}
