export const STATES = {
  away: { label: '离开', color: '#94a3b8' },
  drowsy: { label: '困倦', color: '#f43f5e' },
  tired: { label: '疲劳', color: '#fb923c' },
  distracted: { label: '分心', color: '#facc15' },
  focused: { label: '专注', color: '#34d399' },
  normal: { label: '平稳', color: '#60a5fa' },
};

const RULES = [
  { id: 'away', enter: (s) => !s.present, stay: (s) => !s.present },
  { id: 'drowsy', enter: (s) => s.fatigue > 75, stay: (s) => s.fatigue > 65 },
  { id: 'tired', enter: (s) => s.fatigue > 55, stay: (s) => s.fatigue > 45 },
  { id: 'distracted', enter: (s) => s.focus < 40, stay: (s) => s.focus < 50 },
  { id: 'focused', enter: (s) => s.focus > 70, stay: (s) => s.focus > 60 },
  { id: 'normal', enter: () => true, stay: () => true },
];

export class StateMachine {
  constructor({ hold = 3000, minDwell = 5000 } = {}) {
    this.hold = hold;
    this.minDwell = minDwell;
    this.state = 'normal';
    this.since = -Infinity;
    this.cand = null;
    this.candSince = 0;
    this.listeners = new Set();
  }

  onChange(fn) { this.listeners.add(fn); return () => this.listeners.delete(fn); }

  force(id, now = performance.now()) {
    const prev = this.state;
    this.state = id; this.since = now; this.cand = null;
    if (prev !== id) for (const fn of this.listeners) fn(id, prev, null);
  }

  update(s, now = performance.now()) {
    const cur = RULES.find((r) => r.id === this.state);
    const higher = RULES.slice(0, RULES.indexOf(cur)).find((r) => r.enter(s));
    const next = higher?.id ?? (cur.stay(s) ? this.state : RULES.find((r) => r.enter(s)).id);
    if (next === this.state) { this.cand = null; return this.state; }
    if (next !== this.cand) { this.cand = next; this.candSince = now; }
    const preempt = higher && next === 'away';
    const ready = now - this.candSince >= (preempt ? 1500 : this.hold) && (higher || now - this.since >= this.minDwell);
    if (ready) {
      const prev = this.state;
      this.state = next; this.since = now; this.cand = null;
      for (const fn of this.listeners) fn(next, prev, s);
    }
    return this.state;
  }
}
