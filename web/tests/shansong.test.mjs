import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { createHash } from 'node:crypto';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
const { createShansongDelivery, recipientData } = createRequire(import.meta.url)('../desktop/shansong.cjs');
// Synthetic credentials and transport only. Never contacts FlashEx or debits an account.
const config = { baseUrl: 'https://open.ishansong.com/openapi/order/v3', partnerNo: 'TEST-PARTNER', key: 'synthetic-key', merchantId: 'TEST-ID', mobile: '13800000000', name: '测试商户', token: 'synthetic-token' };
export const recipient = { name: '测试收货人', mobile: '13800000000', city: '成都市', addr: '锦江区测试街道1号测试大厦', addrDetail: '8楼前台' };
const input = { coffeeOrderId: '12345678', store: { name: '瑞幸测试门店', address: '成都市锦江区测试街2号' }, productName: '测试拿铁', pickupCode: 'T123', recipient };
function fixture(options = {}) {
  const calls = [];
  const gateway = createShansongDelivery({ config, ...options, fetchImpl: async (url, init) => {
    const u = new URL(url), body = init.body && JSON.parse(init.body);
    calls.push({ u, init, body });
    const custom = await options.response?.(u, init, body);
    if (custom !== undefined) return custom;
    const data = u.pathname.endsWith('/calc') ? { amount: 1600, cutAmount: 200 } : u.pathname.endsWith('/save') ? 'SYNTHETIC-123' : { orderStatus: 44, orderStatusTxt: '派送中', courier: '13800000001', courierName: '测试骑手' };
    return Response.json({ status: 'OK', errCode: 0, data });
  } });
  return { gateway, calls };
}
const confirmation = (q) => ({ quoteId: q.quoteId, coffeeOrderId: input.coffeeOrderId, pickupCode: input.pickupCode, feeCents: q.feeCents, confirmed: true, acceptBilling: true });

test('missing configuration, unsafe endpoints and invalid recipients stop before network', async () => {
  const g = createShansongDelivery();
  assert.equal(g.configuration().configured, false);
  await assert.rejects(g.quote(input), /尚未开通/);
  for (const baseUrl of ['http://open.ishansong.com/openapi/order/v3', 'https://evil.example/openapi/order/v3', 'https://open.ishansong.com.evil.example/openapi/order/v3', 'https://open.ishansong.com/other']) assert.throws(() => createShansongDelivery({ config: { ...config, baseUrl } }), /官方/);
  for (const patch of [{ mobile: 'abc' }, { addr: '' }, { addrDetail: '' }, { city: '' }, { name: 'a\nb' }]) assert.throws(() => recipientData({ ...recipient, ...patch }));
  const { gateway, calls } = fixture();
  await assert.rejects(gateway.quote({ ...input, recipient: { ...recipient, addr: '' } }));
  assert.equal(calls.length, 0);
});

test('V3 signs requests, reverse-geocodes addresses, sends pickup code and never dispatches during quote', async () => {
  const { gateway, calls } = fixture(); const q = await gateway.quote(input);
  assert.equal(q.feeCents, 1400);
  const { body } = calls[0];
  assert.equal(body.signature, createHash('md5').update(`${config.partnerNo}${body.order.orderNo}${config.mobile}${config.key}`).digest('hex').toUpperCase());
  assert.deepEqual(body.order.receiverList, [recipient]);
  assert.equal('lat' in body.order.sender, false);
  assert.match(body.order.remark, /T123/);
  assert.equal(calls.length, 1);
  const confirmationInput = confirmation(q);
  await assert.rejects(gateway.create({ ...confirmationInput, acceptBilling: false }), /扣费/);
  await assert.rejects(gateway.create({ ...confirmationInput, coffeeOrderId: 'other' }), /过期/);
  await assert.rejects(gateway.create({ ...confirmationInput, pickupCode: 'OTHER' }), /取餐码/);
  const [a, b] = await Promise.all([gateway.create(confirmationInput), gateway.create(confirmationInput)]);
  assert.deepEqual(a, b);
  assert.equal(calls.filter((c) => c.u.pathname.endsWith('/save')).length, 1);
  const status = await gateway.status(input.coffeeOrderId);
  assert.equal(status.status, 'delivering'); assert.equal(status.courierName, '测试骑手');
  assert.equal(calls.at(-1).u.searchParams.get('issorderno'), a.deliveryId);
  await gateway.create(confirmationInput);
  assert.equal(calls.filter((c) => c.u.pathname.endsWith('/save')).length, 1);
  assert.equal(JSON.stringify(gateway.configuration()).includes(config.token), false);
});

test('changed fees and expired quotes cannot create delivery orders', async () => {
  let calcs = 0;
  const { gateway, calls } = fixture({ response: (url) => url.pathname.endsWith('/calc') && ++calcs > 1 ? Response.json({ status: 'OK', errCode: 0, data: { amount: 2000, cutAmount: 0 } }) : undefined });
  const q = await gateway.quote(input);
  await assert.rejects(gateway.create(confirmation(q)), /已变化/);
  assert.equal(calls.some((c) => c.u.pathname.endsWith('/save')), false);
  let time = 0; const expired = fixture({ now: () => time }); const old = await expired.gateway.quote(input); time = 120001;
  await assert.rejects(expired.gateway.create(confirmation(old)), /过期/);
});

test('ambiguous dispatch is persisted before debit, blocks duplicates after restart and supports verified recovery', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'nd-shansong-')), journalPath = join(dir, 'orders.json');
  try {
    const { gateway, calls } = fixture({ journalPath, response: (url) => {
      if (url.pathname.endsWith('/save')) {
        assert.equal(JSON.parse(readFileSync(journalPath, 'utf8'))[0].state, 'submitting');
        throw new Error(`timeout ${config.token}`);
      }
    } });
    const q = await gateway.quote(input);
    await assert.rejects(gateway.create(confirmation(q)), (e) => /不会自动重发/.test(e.message) && !e.message.includes(config.token));
    assert.equal((await gateway.status(input.coffeeOrderId)).state, 'unknown');
    const restarted = fixture({ journalPath });
    await assert.rejects(restarted.gateway.create(confirmation(q)), /待核实/);
    assert.equal(restarted.calls.length, 0);
    const recovered = await restarted.gateway.recover({ coffeeOrderId: input.coffeeOrderId, deliveryId: 'SYNTHETIC-123' });
    assert.equal(recovered.state, 'confirmed'); assert.equal(recovered.status, 'delivering');
    await restarted.gateway.create(confirmation(q));
    assert.equal(restarted.calls.some((c) => c.u.pathname.endsWith('/save')), false);
    assert.equal(calls.filter((c) => c.u.pathname.endsWith('/save')).length, 1);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
