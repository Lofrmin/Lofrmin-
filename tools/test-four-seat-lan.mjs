import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const root = fileURLToPath(new URL('../', import.meta.url));
const engine = (process.env.GODOT_CONSOLE || 'godot');
const env = { ...process.env, APPDATA: `${root}.runtime/roaming`, LOCALAPPDATA: `${root}.runtime/local` };
function run(role) {
  return new Promise((resolve, reject) => {
    const child = spawn(engine, ['--headless', '--path', root, '--', `--lan-${role}-test`], { env, windowsHide: true });
    let output = '';
    child.stdout.on('data', data => { output += data; });
    child.stderr.on('data', data => { output += data; });
    child.on('error', reject);
    child.on('close', code => resolve({ code, output }));
  });
}
const host = run('host');
await new Promise(resolve => setTimeout(resolve, 800));
const results = await Promise.all([host, ...Array.from({ length: 3 }, () => run('client'))]);
for (const result of results) {
  assert.equal(result.code, 0, result.output);
  assert(!result.output.includes('SCRIPT ERROR'), result.output);
}
assert(results[0].output.includes('LAN_HOST_PASS'), results[0].output);
const seats = results.slice(1).map(result => Number(result.output.match(/LAN_CLIENT_PASS \/ seat (\d)/)?.[1])).sort();
assert.deepEqual(seats, [1, 2, 3]);
console.log('FOUR_SEAT_LAN_PASS: three unique client seats, authoritative commands, shared world state');
