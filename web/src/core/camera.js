import { FaceFeatures } from './face.js';

export class Camera {
  constructor(video, overlay, { render = true } = {}) {
    this.video = video;
    this.overlay = overlay;
    this.features = new FaceFeatures();
    this.running = false;
    this.fps = 0;
    this.delegate = '';
    this.renderEnabled = render;
    this.timer = null;
  }

  async start() {
    const vision = await import('@mediapipe/tasks-vision');
    const { FaceLandmarker, FilesetResolver, DrawingUtils } = vision;
    this.FL = FaceLandmarker;
    const fileset = await FilesetResolver.forVisionTasks('/mediapipe/wasm');
    const opts = (delegate) => ({
      baseOptions: { modelAssetPath: '/mediapipe/face_landmarker.task', delegate },
      runningMode: 'VIDEO',
      numFaces: 1,
      outputFaceBlendshapes: true,
      outputFacialTransformationMatrixes: true,
    });
    try {
      this.lm = await FaceLandmarker.createFromOptions(fileset, opts('GPU'));
      this.delegate = 'GPU';
    } catch {
      this.lm = await FaceLandmarker.createFromOptions(fileset, opts('CPU'));
      this.delegate = 'CPU';
    }
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ video: { width: 640, height: 480, facingMode: 'user' }, audio: false });
      this.video.srcObject = this.stream;
      await this.video.play();
      this.ctx = this.overlay.getContext('2d');
      this.draw = new DrawingUtils(this.ctx);
      this.running = true;
      this.lastVideoAt = performance.now();
      this.watchdog = window.setInterval(() => {
        if (!this.running) return;
        if (performance.now() - (this.lastVideoAt ?? 0) > 5000) {
          this.stop(); this.onError?.(new Error('摄像头画面已中断，请重新开始监测'));
        }
      }, 2000);
      this.loop();
    } catch (error) { this.stop(); throw error; }
  }

  stop() {
    this.running = false;
    clearTimeout(this.timer);
    clearInterval(this.watchdog);
    this.stream?.getTracks().forEach((t) => t.stop());
    this.ctx?.clearRect(0, 0, this.overlay.width, this.overlay.height);
    this.lm?.close(); this.lm = null;
    this.video.srcObject = null;
    if (this.features.calib) { this.features.calib.resolve({ ok: false, reason: '监测已停止' }); this.features.calib = null; }
  }

  loop() {
    let last = -1, frames = 0, fpsT = performance.now();
    const step = () => {
      if (!this.running) return;
      const now = performance.now();
      if (this.video.currentTime !== last && this.video.readyState >= 2) {
        last = this.video.currentTime;
        this.lastVideoAt = now;
        let r;
        try { r = this.lm.detectForVideo(this.video, now); }
        catch (error) { this.stop(); this.onError?.(error); return; }
        this.features.update(r, now);
        if (this.renderEnabled) this.render(r);
        frames++;
      }
      if (now - fpsT > 1000) { this.fps = frames; frames = 0; fpsT = now; }
      this.timer = setTimeout(step, 66);
    };
    step();
  }

  render(r) {
    const { overlay: c, video: v, ctx, FL } = this;
    if (c.width !== v.videoWidth) { c.width = v.videoWidth; c.height = v.videoHeight; }
    ctx.clearRect(0, 0, c.width, c.height);
    const pts = r.faceLandmarks?.[0];
    if (!pts) return;
    const closed = this.features.closed;
    this.draw.drawConnectors(pts, FL.FACE_LANDMARKS_TESSELATION, { color: 'rgba(160,190,255,0.12)', lineWidth: 0.6 });
    this.draw.drawConnectors(pts, FL.FACE_LANDMARKS_FACE_OVAL, { color: 'rgba(125,211,252,0.7)', lineWidth: 1.5 });
    const eyeColor = closed ? '#fb7185' : '#a3e635';
    for (const k of ['FACE_LANDMARKS_LEFT_EYE', 'FACE_LANDMARKS_RIGHT_EYE', 'FACE_LANDMARKS_LEFT_IRIS', 'FACE_LANDMARKS_RIGHT_IRIS'])
      this.draw.drawConnectors(pts, FL[k], { color: eyeColor, lineWidth: 1.6 });
    this.draw.drawConnectors(pts, FL.FACE_LANDMARKS_LIPS, { color: this.features.jawStart ? '#fbbf24' : '#f0abfc', lineWidth: 1.6 });
  }
}
