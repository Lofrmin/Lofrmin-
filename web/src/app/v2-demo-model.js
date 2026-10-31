// Offline demo only. No imports of API clients, IPC or device transports.
export const CATALOG = [
 {id:'water',name:'矿泉水',price:4,art:'💧',store:'A'},
 {id:'cookie',name:'黄油曲奇',price:10,art:'🍪',store:'A'},
 {id:'sandwich',name:'全麦三明治',price:18,art:'/workspace/sandwich.png',store:'A'},
 {id:'fruit',name:'鲜果杯',price:15,art:'/workspace/fruit.png',store:'A'},
 {id:'coffee',name:'生椰拿铁',price:16,art:'/workspace/coffee.png',store:'A'},
];
export const STAGES=['模拟付款成功','补给点接单','正在备货','装车完成','小车出发','模拟配送中','已抵达取餐点','已领取'];
export function dateKey(d){return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;}
export function parsePlan(text,now=new Date()){
 const items={};const cn={'一':1,'二':2,'两':2,'三':3,'四':4,'五':5,'六':6,'七':7,'八':8,'九':9,'十':10};
 for(const [id,words] of [['water','水|矿泉水'],['cookie','曲奇|饼干'],['sandwich','三明治|午餐'],['fruit','水果|果杯'],['coffee','咖啡|拿铁']]){
  if(new RegExp(words).test(text)){const m=text.match(new RegExp(`([一二两三四五六七八九十0-9]+)\\s*(瓶|份|杯|个|包)?\\s*(${words})`));items[id]=m?Number(m[1])||cn[m[1]]||1:1;}
 }
 if(!Object.keys(items).length)throw new Error('暂未识别商品，请试试“两瓶水和一份曲奇”，也可以在补给页直接选购。');
 const d=new Date(now);d.setDate(d.getDate()+(text.includes('后天')?2:text.includes('明天')?1:0));
 const t=text.match(/([一二两三四五六七八九十0-9]+)\s*[:：点时]\s*(\d{1,2})?/);let h=t?(Number(t[1])||cn[t[1]]||15):15;
 if(/下午|晚上/.test(text)&&h<12)h+=12;
 return {store:'A',date:dateKey(d),time:`${String(h).padStart(2,'0')}:${String(t?.[2]||0).padStart(2,'0')}`,location:'A 区取餐点',items,locationAck:!/[BCDＢＣＤ]\s*区|工位/.test(text),mode:'DEMO'};
}
export const total=p=>CATALOG.reduce((s,x)=>s+x.price*(p.items[x.id]||0),0);
export function validatePlan(p,now=new Date()){
 if(p.store!=='A')return '单笔演示仅支持 A 区补给站';
 if(!/^\d{4}-\d{2}-\d{2}$/.test(p.date)||dateKey(new Date(p.date+'T12:00:00'))!==p.date)return '请选择有效日期';
 const when=new Date(`${p.date}T${p.time}:00`);
 if(!/^([01]\d|2[0-3]):[0-5]\d$/.test(p.time)||!Number.isFinite(+when))return '请选择有效时间';
 if(+when<+now+30*60000||+when>+now+31*86400000)return '请选择提前30分钟、未来30天内的预约';
 if(p.time<'09:00'||p.time>'18:30')return '演示服务时间为09:00–18:30';
 if(!p.locationAck||p.location!=='A 区取餐点')return '请确认 A 区固定取餐点';
 if(!Object.keys(p.items).length||Object.entries(p.items).some(([id,n])=>!CATALOG.some(x=>x.id===id)||!Number.isInteger(n)||n<0||n>9)||total(p)<=0)return '商品数量须为0–9，至少选择一件';
 return '';
}
export class DemoDelivery {
 constructor({mode='DEMO'}={}){this.mode=mode;this.draft=null;this.order=null;this.paused=false;this.failed=false;this.disconnected=false;this.events=[];this.paid=new WeakMap();}
 setDraft(plan){this.draft=structuredClone(plan);return this.draft;}
 record(label){this.events.push({label,at:new Date().toISOString()});}
 pay(plan=this.draft){if(this.mode!=='DEMO'||plan?.mode!=='DEMO')throw new Error('真实模式未接入：禁止模拟付款或设备确认');if(this.paid.has(plan))return this.paid.get(plan);const error=validatePlan(plan);if(error)throw new Error(error);this.order={...structuredClone(plan),id:'DEMO-'+globalThis.crypto.randomUUID(),amount:total(plan),step:0};this.paid.set(plan,this.order);this.paused=false;this.failed=false;this.disconnected=false;this.events=[];this.record(STAGES[0]);return this.order;}
 advance(){if(this.mode==='DEMO'&&this.order?.mode==='DEMO'&&!this.paused&&!this.failed&&!this.disconnected&&this.order.step<7){this.order.step++;this.record(STAGES[this.order.step]);}}
 receive(){if(this.mode==='DEMO'&&this.order?.mode==='DEMO'&&this.order.step===6&&!this.failed&&!this.disconnected){this.order.step=7;this.record(STAGES[7]);}}
 fail(){if(this.order&&!this.failed){this.failed=true;this.record('模拟异常：配送暂停');}}
 disconnect(){if(this.order&&!this.disconnected){this.disconnected=true;this.record('模拟通信中断：等待恢复，不推测设备状态');}}
 resume(){if(this.failed||this.disconnected||this.paused)this.record('演示恢复');this.failed=false;this.disconnected=false;this.paused=false;}
 restart(){if(this.order?.mode!=='DEMO'||this.mode!=='DEMO')return;if(this.order)this.order.step=0;this.resume();this.events=[];this.record(STAGES[0]);}
}
