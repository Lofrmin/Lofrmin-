import { LINES, pick } from './lines.js';
import { STATES } from '../core/state.js';
import { desk, on } from '../desk/mqtt.js';

const MOOD = { focused: 'focused', normal: 'normal', distracted: 'curious', tired: 'tired', drowsy: 'alert', away: 'away' };
const LIGHT = { focused: 'focus', normal: 'normal', tired: 'eye', drowsy: 'focus' };

// 状态 → 宠物表情、台词、按钮、工位联动
export class Reactions {
  constructor(app) {
    this.app = app;
    this.lastSaid = {};
    this.flashT = 0;
    this.coffeeOfferAt = 0;
    this.focusStart = null;
    this.pomodoroDone = false;
    this.lastWater = performance.now();
    this.pausedByAway = false;
    this.awayT = 0;
    on('desk/event', (m) => {
      if (m?.key !== 'confirm') return;
      if (performance.now() - this.coffeeOfferAt < 30000) this.orderCoffee('BOOT 键确认');
      else this.flash('happy', 2000);
    });
  }

  say(text, { actions = [], notify = false, voice = true, color = '#a78bfa', tag = '提醒', log = true } = {}) {
    const t = this.app.hub.say(text.replace('{m}', this.app.pomodoroMin), { actions, notify, voice });
    if (log) this.app.log.add(t, { color, tag });
  }

  flash(mood, ms = 2500) {
    clearTimeout(this.flashT);
    this.app.hub.setMood(mood);
    this.flashT = setTimeout(() => this.app.hub.setMood(MOOD[this.app.sm.state]), ms);
  }

  coffeeBtn = () => ({ label: '☕ 看看附近咖啡', run: () => this.orderCoffee('点击按钮') });
  breakBtn = () => ({ label: '好，休息', run: () => { this.app.light.preset('relax'); this.app.music.play('calm'); this.focusStart = null; } });

  orderCoffee(via) {
    this.app.coffee.request();
    this.coffeeOfferAt = 0;
    this.flash('happy');
    this.app.log.add(`已打开附近咖啡推荐（${via}）`, { color: '#528068', tag: '咖啡' });
  }

  offerCoffee() {
    if (this.app.coffee.busy) return [];
    this.coffeeOfferAt = performance.now();
    return [this.coffeeBtn()];
  }

  onState(next, prev) {
    const { app } = this;
    clearTimeout(this.flashT);
    clearTimeout(this.awayT);
    app.hub.setMood(MOOD[next]);
    if (next === 'away') this.awayT = setTimeout(() => app.sm.state === 'away' && app.hub.setMood('sleepy'), 30000);
    if (next === 'focused') { this.focusStart ??= performance.now(); this.pomodoroDone = false; }
    if (app.auto && LIGHT[next]) app.light.preset(LIGHT[next]);
    const now = performance.now();
    const cool = (id, ms) => { if (now - (this.lastSaid[id] ?? -1e9) < ms) return false; this.lastSaid[id] = now; return true; };
    const color = STATES[next].color;
    let actions = [];
    switch (next) {
      case 'distracted':
        actions = [{ label: '🎧 专注音乐', run: () => app.music.play('lofi') }];
        if (cool(next, 45000)) this.say(pick(LINES.distracted), { actions, color, tag: '分心' });
        break;
      case 'tired':
        if ((!window.neuroDesktop || app.mode === 'demo') && cool('coffee-popup', 20 * 60000)) this.orderCoffee('疲劳提醒');
        actions = [this.breakBtn(), ...this.offerCoffee()];
        if (cool(next, 60000)) this.say(pick(LINES.tired), { actions, notify: true, color, tag: '疲劳' });
        break;
      case 'drowsy':
        if ((!window.neuroDesktop || app.mode === 'demo') && cool('coffee-popup', 20 * 60000)) this.orderCoffee('困倦提醒');
        if (app.auto) desk({ type: 'alert' });
        actions = this.offerCoffee();
        if (cool(next, 30000)) this.say(pick(LINES.drowsy), { actions, notify: true, color, tag: '困倦' });
        break;
      case 'away':
        if (app.music.track) { this.pausedByAway = app.music.track; app.music.stop(); this.say(pick(LINES.awayMusic), { color, tag: '离开' }); }
        else if (cool(next, 60000)) this.say(pick(LINES.away), { color, tag: '离开', voice: false });
        break;
      case 'focused':
        if (cool(next, 90000)) this.say(pick(LINES.focused), { color, tag: '专注' });
        break;
      default:
        if (prev === 'away') {
          this.flash('happy', 3000);
          const resume = this.pausedByAway;
          this.pausedByAway = false;
          this.say(pick(LINES.back), { actions: resume ? [{ label: '▶ 继续播放', run: () => app.music.play(resume) }] : [], color, tag: '回来' });
        }
    }
    if (next !== 'focused' && next !== 'normal') this.focusStart = null;
  }

  poke() {
    this.flash(Math.random() < 0.3 ? 'love' : 'happy', 1800);
    this.app.hub.say(pick(LINES.poke), { voice: Math.random() < 0.5 });
  }

  pomodoro() {
    this.flash('alert', 3000);
    this.say(pick(LINES.pomodoro), { actions: [this.breakBtn()], notify: true, color: '#f472b6', tag: '番茄钟' });
  }

  water() {
    this.lastWater = performance.now();
    this.flash('happy', 2500);
    this.say(pick(LINES.water), { notify: true, color: '#38bdf8', tag: '喝水' });
  }

  tick(now = performance.now()) {
    const st = this.app.sm.state;
    if (this.focusStart != null && !this.pomodoroDone && now - this.focusStart > this.app.pomodoroMin * 60000) {
      this.pomodoroDone = true;
      this.pomodoro();
    }
    if (st !== 'away' && now - this.lastWater > 45 * 60000) this.water();
  }
}
