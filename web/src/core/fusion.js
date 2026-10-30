export const clamp = (v, lo = 0, hi = 100) => Math.max(lo, Math.min(hi, v));

export function visual(face) {
  const offAxis = Math.max(clamp((Math.abs(face.yaw) - 15) * 4), clamp((Math.abs(face.pitch) - 12) * 5));
  const focus = clamp(100 - offAxis - face.perclos * 200);
  const blinkDev = Math.abs((face.blinkPerMin || 15) - 15);
  const fatigue = clamp(face.perclos * 300 + face.yawns5min * 10 + face.longCloses * 10 + blinkDev);
  return { focus, fatigue, offAxis };
}

// 视觉 0.7 + EEG 0.3；任一路缺失时退化为单路
export function fuse(eeg, face) {
  const v = face ? visual(face) : null;
  if (v && eeg) return {
    focus: 0.7 * v.focus + 0.3 * eeg.engagement,
    fatigue: 0.7 * v.fatigue + 0.3 * eeg.drowsiness,
    present: face.present, source: '视觉+EEG', vis: v,
  };
  if (v) return { focus: v.focus, fatigue: v.fatigue, present: face.present, source: '仅视觉', vis: v };
  if (eeg) return { focus: eeg.engagement, fatigue: eeg.drowsiness, present: true, source: '仅EEG' };
  return null;
}

export const ema = (prev, x, k = 0.2) => (prev == null ? x : prev + k * (x - prev));
