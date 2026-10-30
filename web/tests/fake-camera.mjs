import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

/** Deterministic looping Y4M input, avoiding OS fake-camera track stalls. */
export function ensureFakeCamera() {
  const path = resolve('.runtime/test-camera.y4m');
  if (existsSync(path)) return path;
  mkdirSync(resolve('.runtime'), { recursive: true });
  const width = 320, height = 240, frames = 30;
  const header = Buffer.from(`YUV4MPEG2 W${width} H${height} F10:1 Ip A1:1 C420\nFRAME\n`);
  const chunks = [header];
  for (let i = 0; i < frames; i++) {
    const data = Buffer.alloc(width * height * 3 / 2, 128);
    data.fill(70 + i * 3, 0, width * height);
    chunks.push(data, Buffer.from('FRAME\n'));
  }
  writeFileSync(path, Buffer.concat(chunks));
  return path;
}
