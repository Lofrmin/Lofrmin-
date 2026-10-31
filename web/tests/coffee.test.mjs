import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { createCoffeeGateway } = require('../desktop/coffee.cjs');
const { startCoffeeDemo } = require('../desktop/coffee-demo.cjs');
const coords = { latitude: 31.23, longitude: 121.47 };
const store = (id, distanceMeters, products = [{ id: 'latte', name: '拿铁', priceCents: 2200, available: true }]) => ({ id, name: id, distanceMeters, products });
const input = { storeId: 'near', productId: 'latte', priceCents: 2200, idempotencyKey: 'test-idempotency-0001' };
const ok = (value) => ({ ok: true, json: async () => value });

test('unconfigured service never creates a simulated successful order', async () => {
  const gateway = createCoffeeGateway();
  assert.equal(gateway.configured, false);
  await assert.rejects(gateway.nearby(coords), /尚未接入/);
  await assert.rejects(gateway.order(input), /商品或价格/);
});
test('nearby stores sorted by distance; unavailable products removed', async () => {
  const gateway = createCoffeeGateway({ baseUrl: 'https://merchant.example', fetchImpl: async () => ok({ stores: [store('far', 800), store('empty', 80, []), store('near', 200), store('invalid', -1), store('sold-out', 50, [{ id: 'x', name: '售罄', priceCents: 2000, available: false }])] }) });
  assert.deepEqual((await gateway.nearby(coords)).stores.map((s) => s.id), ['near', 'far']);
  await assert.rejects(gateway.nearby({ latitude: 999, longitude: 0 }), /有效位置/);
});
test('duplicate clicks submit once with an idempotency key, server controls confirmation', async () => {
  let count = 0, payload;
  const gateway = createCoffeeGateway({ baseUrl: 'https://merchant.example', token: 'test-token', fetchImpl: async (url, init) => {
    if (url.includes('nearby')) return ok({ stores: [store('near', 200)] });
    count++; payload = init;
    await new Promise((resolve) => setTimeout(resolve, 15));
    return ok({ orderId: 'ORDER-1', status: 'accepted', pickupCode: '1234' });
  } });
  await gateway.nearby(coords);
  const [a, b] = await Promise.all([gateway.order(input), gateway.order(input)]);
  assert.equal(count, 1); assert.deepEqual(a, b);
  assert.equal(payload.headers['Idempotency-Key'], input.idempotencyKey);
  assert.equal(payload.headers.Authorization, 'Bearer test-token');
  assert.equal(JSON.parse(payload.body).fulfilment, 'pickup');
  await assert.rejects(gateway.order({ ...input, priceCents: 1, idempotencyKey: 'another-order-0001' }), /价格/);
});
test('timeout retry uses original key; malformed confirmations never appear successful', async () => {
  const keys = [];
  const gateway = createCoffeeGateway({ baseUrl: 'https://merchant.example', fetchImpl: async (url, init) => {
    if (url.includes('nearby')) return ok({ stores: [store('near', 200)] });
    keys.push(init.headers['Idempotency-Key']);
    if (keys.length === 1) throw new Error('timeout');
    return ok({ status: 'pending' });
  } });
  await gateway.nearby(coords);
  await assert.rejects(gateway.order(input), /timeout/);
  await assert.rejects(gateway.order(input), /未确认订单/);
  assert.deepEqual(keys, [input.idempotencyKey, input.idempotencyKey]);
});
test('local demo API is idempotent and exposes progress through order status', async () => {
  const demo = await startCoffeeDemo({ port: 0, stageMs: 15 });
  try {
    const gateway = createCoffeeGateway({ baseUrl: demo.origin });
    await gateway.nearby({ latitude: 0, longitude: 0 });
    const demoInput = { ...input, storeId: 'demo-store', productId: 'americano', priceCents: 1800 };
    const first = await gateway.order(demoInput);
    const duplicate = await gateway.order({ ...demoInput });
    assert.equal(first.orderId, duplicate.orderId);
    assert.match(first.orderId, /^DEMO-/);
    const status = await gateway.orderStatus(first.orderId);
    assert.equal(status.orderId, first.orderId);
    await new Promise((resolve) => setTimeout(resolve, 60));
    assert.equal((await gateway.orderStatus(first.orderId)).status, 'ready');
    await assert.rejects(gateway.order({ ...demoInput, priceCents: 1, idempotencyKey: 'bad-price-key-0001' }), /价格/);
  } finally {
    demo.server.closeAllConnections();
    await new Promise((resolve) => demo.server.close(resolve));
  }
});
