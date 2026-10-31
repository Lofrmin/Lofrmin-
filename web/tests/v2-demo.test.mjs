import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parsePlan, total, validatePlan, DemoDelivery } from '../src/app/v2-demo-model.js';
test('Chinese demo request parses tomorrow, two waters and cookies',()=>{
 const p=parsePlan('明天下午三点送两瓶水和一份曲奇到 A 区取餐点。',new Date(2026,9,31,10));
 assert.equal(p.date,'2026-11-01');assert.equal(p.time,'15:00');assert.equal(p.items.water,2);assert.equal(p.items.cookie,1);assert.equal(total(p),18);
});
test('unknown input is not silently replaced with an order',()=>assert.throws(()=>parsePlan('你好')));
test('invalid date, quantity, time and mixed store are rejected',()=>{
 const p=parsePlan('明天下午三点两瓶水');assert.ok(validatePlan({...p,time:'25:00'}));assert.ok(validatePlan({...p,items:{water:-1}}));assert.ok(validatePlan({...p,store:'other'}));assert.ok(validatePlan({...p,date:'2026-02-30'}));
});
test('pay is idempotent and never requires real payment',()=>{const d=new DemoDelivery();const p=parsePlan('明天下午三点两瓶水');const a=d.pay(p);assert.equal(a,d.pay(p));assert.match(a.id,/^DEMO-/);assert.equal(a.mode,'DEMO');});
test('paused and failed delivery cannot advance; resume and receive work',()=>{const d=new DemoDelivery();d.pay(parsePlan('明天下午三点两瓶水'));d.paused=true;d.advance();assert.equal(d.order.step,0);d.paused=false;d.fail();d.advance();assert.equal(d.order.step,0);d.resume();for(let i=0;i<7;i++)d.advance();assert.equal(d.order.step,7);});
test('edited amount is derived from quantities',()=>{const p=parsePlan('明天下午三点两瓶水');p.items.cookie=3;assert.equal(total(p),38);});

test('one draft source contains only requested goods; payment snapshots edited values',()=>{const d=new DemoDelivery();const source=parsePlan('明天下午三点送两瓶水和一份曲奇到 A 区取餐点');const p=d.setDraft(source);assert.deepEqual(p.items,{water:2,cookie:1});p.items.water=3;assert.equal(total(d.draft),22);d.pay();assert.equal(d.order.amount,22);p.items.water=1;assert.equal(d.order.items.water,3);});
test('Real mode rejects payment and never advances device confirmation',()=>{const d=new DemoDelivery({mode:'REAL'});assert.throws(()=>d.pay(parsePlan('明天两瓶水')),/真实模式/);d.order={mode:'REAL',step:0};d.advance();d.restart();assert.equal(d.order.step,0);const demo=new DemoDelivery();assert.throws(()=>demo.pay({...parsePlan('明天两瓶水'),mode:'REAL'}));});
test('communication interruption freezes state, recovery resumes and records events',()=>{const d=new DemoDelivery();d.pay(parsePlan('明天两瓶水'));d.disconnect();d.advance();assert.equal(d.order.step,0);assert.match(d.events.at(-1).label,/通信中断/);d.resume();d.advance();assert.equal(d.order.step,1);assert.ok(d.events.every(e=>Number.isFinite(Date.parse(e.at))));});

test('manual pickup completes an arrived demo even when autoplay is paused, but not offline',()=>{const d=new DemoDelivery();d.pay(parsePlan('明天两瓶水'));for(let i=0;i<6;i++)d.advance();d.paused=true;d.disconnect();d.receive();assert.equal(d.order.step,6);d.resume();d.paused=true;d.receive();assert.equal(d.order.step,7);assert.equal(d.events.at(-1).label,'已领取');});
