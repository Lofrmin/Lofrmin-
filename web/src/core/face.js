const median = (a) => {
  const s = [...a].sort((x, y) => x - y);
  return s.length ? s[Math.floor(s.length / 2)] : 0;
};

export class FaceFeatures {
  constructor() {
    this.thrClose = 0.5;
    this.thrOpen = 0.35;
    this.base = { yaw: 0, pitch: 0 };
    this.closed = false;
    this.closeStart = 0;
    this.blinks = [];
    this.longs = [];
    this.yawns = [];
    this.closedLog = [];
    this.jawStart = 0;
    this.yawnLatched = false;
    this.lastSeen = -1e9;
    this.raw = { eye: 0, jaw: 0, yaw: 0, pitch: 0, frown: 0, smile: 0 };
    this.calib = null;
  }

  startCalibration(ms = 8000) {
    return new Promise((resolve) => { this.calib = { until: performance.now() + ms, eye: [], yaw: [], pitch: [], resolve }; });
  }

  finishCalibration() {
    const c = this.calib;
    this.calib = null;
    if (c.eye.length < 20) return c.resolve({ ok: false, reason: '校准期间没检测到人脸' });
    const b0 = median(c.eye);
    this.thrClose = Math.min(0.75, b0 + 0.3);
    this.thrOpen = Math.min(0.6, b0 + 0.15);
    this.base = { yaw: median(c.yaw), pitch: median(c.pitch) };
    c.resolve({ ok: true, eyeBase: b0, thrClose: this.thrClose, thrOpen: this.thrOpen, ...this.base });
  }

  update(result, now = performance.now()) {
    const bs = result.faceBlendshapes?.[0]?.categories;
    if (!bs) {
      if (this.calib && now > this.calib.until) this.finishCalibration();
      return;
    }
    const g = Object.fromEntries(bs.map((c) => [c.categoryName, c.score]));
    const eye = (g.eyeBlinkLeft + g.eyeBlinkRight) / 2;
    const m = result.facialTransformationMatrixes?.[0]?.data;
    const yaw = m ? (Math.atan2(m[8], m[10]) * 180) / Math.PI : 0;
    const pitch = m ? (Math.asin(Math.max(-1, Math.min(1, -m[9]))) * 180) / Math.PI : 0;
    this.raw = {
      eye, jaw: g.jawOpen, yaw, pitch,
      frown: (g.browDownLeft + g.browDownRight) / 2,
      smile: (g.mouthSmileLeft + g.mouthSmileRight) / 2,
    };
    this.lastSeen = now;

    if (this.calib) {
      this.calib.eye.push(eye); this.calib.yaw.push(yaw); this.calib.pitch.push(pitch);
      if (now > this.calib.until) this.finishCalibration();
    }

    if (!this.closed && eye > this.thrClose) { this.closed = true; this.closeStart = now; }
    else if (this.closed && eye < this.thrOpen) {
      this.closed = false;
      const dur = now - this.closeStart;
      if (dur > 500) this.longs.push(now);
      else if (dur > 50) this.blinks.push(now);
    }
    this.closedLog.push([now, this.closed]);

    if (g.jawOpen > 0.6) {
      if (!this.jawStart) this.jawStart = now;
      if (!this.yawnLatched && now - this.jawStart > 1200) { this.yawns.push(now); this.yawnLatched = true; }
    } else { this.jawStart = 0; this.yawnLatched = false; }

    const cut = (arr, ms) => { while (arr.length && now - (arr[0][0] ?? arr[0]) > ms) arr.shift(); };
    cut(this.blinks, 60000); cut(this.longs, 180000); cut(this.yawns, 300000); cut(this.closedLog, 60000);
  }

  snapshot(now = performance.now()) {
    const present = now - this.lastSeen < 1500;
    const n = this.closedLog.length;
    const perclos = n ? this.closedLog.filter((x) => x[1]).length / n : 0;
    const span = n ? Math.min(60, Math.max(10, (now - this.closedLog[0][0]) / 1000)) : 60;
    return {
      present,
      blinkPerMin: (this.blinks.length * 60) / span,
      perclos,
      longCloses: this.longs.length,
      yawns5min: this.yawns.length,
      yaw: this.raw.yaw - this.base.yaw,
      pitch: this.raw.pitch - this.base.pitch,
      eye: this.raw.eye,
      jaw: this.raw.jaw,
      frown: this.raw.frown,
      smile: this.raw.smile,
      calibrating: !!this.calib,
    };
  }
}
