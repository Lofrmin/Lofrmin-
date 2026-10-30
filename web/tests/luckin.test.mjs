import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const { createLuckinClient, createLuckinGateway, paymentUrl } = createRequire(import.meta.url)('../desktop/luckin.cjs');

// All fixtures are synthetic. No live order or real credential is used by these tests.
export const shop = { deptId: 12, deptName: '测试瑞幸', address: '测试地址', latitude: 30, longitude: 104, distance: 0.2, workTimeStart: '08:00', workTimeEnd: '22:00' };
export const product = { productId: 34, productName: '测试拿铁', skuCode: 'SKU-ICE', estimatePrice: 12.9, productAttrs: [{ attributeId: 1, attributeName: '温度', productSubAttrs: [{ attributeId: 2, attributeName: '冰', selected: true, canSelected: 1 }, { attributeId: 3, attributeName: '热', selected: false, canSelected: 1 }] }] };
export const quote = { discountPrice: 9.9, shopInfo: shop, productInfoList: [{ productId: 34, skuCode: 'SKU-ICE', name: '测试拿铁', amount: 1, additionDesc: '冰·大杯' }], couponCodeList: ['TEST-COUPON'] };
export const created = { orderId: 7639308439653908000, orderIdStr: '7639308439653908490', needPay: true, discountPrice: 9.9, payOrderUrl: 'weixin://wxpay/bizpayurl?pr=test', payOrderQrCodeUrl: 'https://open.lkcoffee.com/transfer/qrcode?token=synthetic' };
function fixture(options = {}) {
  const calls = [];
  const client = { async call(name, args) {
    calls.push({ name, args });
    if (options.call) { const result = await options.call(name, args); if (result !== undefined) return result; }
    return structuredClone({ queryShopList: [shop], searchProductForMcp: [product], queryProductDetailInfo: product, switchProduct: product, previewOrder: quote, createOrder: created, queryOrderDetailInfo: { orderId: created.orderIdStr, orderStatus: 60, orderStatusName: '等待取餐', takeMealCodeInfo: { code: 'A123' } } }[name]);
  } };
  const gateway = createLuckinGateway({ token: 'synthetic', client, journalPath: options.journalPath, now: options.now, delivery: options.delivery });
  return { gateway, calls };
}
async function prepare(gateway) {
  await gateway.nearby({ latitude: 30, longitude: 104 });
  const { products } = await gateway.products({ storeId: 12, query: '拿铁' });
  return gateway.preview({ selectionId: products[0].selectionId });
}

test('MCP transport handles JSON/SSE and never leaks credentials', async () => {
  const payload = { code: 0, success: true, data: [shop] };
  for (const sse of [false, true]) {
    const client = createLuckinClient({ token: 'synthetic-secret', fetchImpl: async (url, init) => {
      assert.equal(url, 'https://gwmcp.lkcoffee.com/order/user/mcp');
      assert.equal(init.headers.Authorization, 'Bearer synthetic-secret');
      const { id } = JSON.parse(init.body);
      const response = JSON.stringify({ jsonrpc: '2.0', id, result: { content: [{ type: 'text', text: JSON.stringify(payload) }] } });
      return new Response(sse ? `event: message\ndata: ${response}\n\n` : response, { headers: { 'content-type': sse ? 'text/event-stream' : 'application/json' } });
    } });
    assert.deepEqual(await client.call('queryShopList', { latitude: 30, longitude: 104 }), [shop]);
    await assert.rejects(client.call('arbitrary-tool', {}), /不支持/);
  }
  const denied = createLuckinClient({ token: 'synthetic-secret', fetchImpl: async () => new Response('', { status: 401 }) });
  await assert.rejects(denied.call('previewOrder', {}), /授权/);
  const failed = createLuckinClient({ token: 'synthetic-secret', fetchImpl: async () => { throw new Error('synthetic-secret'); } });
  await assert.rejects(failed.call('previewOrder', {}), (error) => !error.message.includes('synthetic-secret'));
});

test('catalog, attribute validation and preview never create an order', async () => {
  const { gateway, calls } = fixture();
  await assert.rejects(gateway.nearby({ latitude: 999, longitude: 104 }), /有效/);
  const draft = await prepare(gateway);
  assert.equal(draft.priceCents, 990);
  assert.equal(draft.specification, '冰·大杯');
  assert.equal(calls.some((call) => call.name === 'createOrder'), false);
  const item = await gateway.detail({ storeId: 12, productId: 34 });
  await assert.rejects(gateway.switchAttribute({ selectionId: item.selectionId, groupId: 1, optionId: 999 }), /不可选/);
  await gateway.switchAttribute({ selectionId: item.selectionId, groupId: 1, optionId: 3 });
  assert.equal(calls.at(-1).args.attrOperationParam.subAttr.operation, 3);
});

test('confirmed order preserves 64-bit ID, is deduplicated and uses shop coordinates', async () => {
  const { gateway, calls } = fixture(); const draft = await prepare(gateway);
  await assert.rejects(gateway.order({ draftId: draft.draftId, priceCents: 990 }), /确认/);
  await assert.rejects(gateway.order({ draftId: draft.draftId, priceCents: 1, confirmed: true }), /价格/);
  const input = { draftId: draft.draftId, priceCents: 990, confirmed: true };
  const [a, b] = await Promise.all([gateway.order(input), gateway.order(input)]);
  assert.equal(a.orderId, created.orderIdStr); assert.deepEqual(a, b);
  assert.equal(a.status, 'awaiting_payment'); assert.equal(a.pickupCode, '');
  assert.equal(calls.filter((call) => call.name === 'createOrder').length, 1);
  assert.deepEqual(calls.find((call) => call.name === 'createOrder').args, {
    deptId: 12, productList: [{ amount: 1, productId: 34, skuCode: 'SKU-ICE' }], longitude: 104, latitude: 30, couponCodeList: ['TEST-COUPON'],
  });
  assert.equal(gateway.canOpenPayment(a.payUrl), true);
  assert.equal((await gateway.orderStatus(a.orderId)).pickupCode, 'A123');
  assert.equal(gateway.canOpenPayment(a.payUrl), false, 'paid orders cannot reopen payment');
  await assert.rejects(gateway.orderStatus('unowned-order'), /本机/);
});

test('changed price/coupons and expired drafts stop before creating a real order', async () => {
  let previews = 0;
  const { gateway, calls } = fixture({ call: (name) => name === 'previewOrder' && ++previews > 1 ? { ...quote, discountPrice: 10.9 } : undefined });
  const draft = await prepare(gateway);
  await assert.rejects(gateway.order({ draftId: draft.draftId, priceCents: 990, confirmed: true }), /已变化/);
  assert.equal(calls.some((call) => call.name === 'createOrder'), false);
  let clock = 0; const expired = fixture({ now: () => clock }); const old = await prepare(expired.gateway); clock = 300001;
  await assert.rejects(expired.gateway.order({ draftId: old.draftId, priceCents: 990, confirmed: true }), /过期/);
});

test('ambiguous order is journaled before request and remains blocked after restart', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'neuro-luckin-')); const journalPath = join(dir, 'orders.json');
  try {
    const { gateway, calls } = fixture({ journalPath, call: (name) => {
      if (name === 'createOrder') { assert.equal(JSON.parse(readFileSync(journalPath))[0].state, 'submitting'); throw new Error('timeout'); }
    } });
    const draft = await prepare(gateway), input = { draftId: draft.draftId, priceCents: 990, confirmed: true };
    await assert.rejects(gateway.order(input), /不会自动重试/);
    await assert.rejects(gateway.order(input), /核实/);
    assert.equal(calls.filter((call) => call.name === 'createOrder').length, 1);
    const restarted = fixture({ journalPath }).gateway;
    const next = await prepare(restarted);
    await assert.rejects(restarted.order({ draftId: next.draftId, priceCents: 990, confirmed: true }), /核实/);
    assert.throws(() => restarted.resolveUnknown({ draftId: draft.draftId }), /核实/);
    assert.equal(restarted.resolveUnknown({ draftId: draft.draftId, confirmedNoOrder: true }), true);
    assert.equal((await restarted.order({ draftId: next.draftId, priceCents: 990, confirmed: true })).needPay, true);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('only official payment destinations are accepted', () => {
  for (const url of ['file:///C:/Windows/a.exe', 'https://lkcoffee.com.evil.example/pay', 'javascript:alert(1)', 'weixin://something/else', 'https://user:password@open.lkcoffee.com/pay']) assert.equal(paymentUrl(url), '');
  assert.ok(paymentUrl(created.payOrderUrl)); assert.ok(paymentUrl(created.payOrderQrCodeUrl));
});

test('ambiguous successful order can be recovered only with matching official shop and product', async () => {
  let correct = false;
  const { gateway } = fixture({ call: (name, args) => {
    if (name === 'createOrder') throw new Error('timeout');
    if (name === 'queryOrderDetailInfo') return {
      orderId: args.orderId, orderStatus: 10, orderStatusName: '待付款', orderPayAmount: 9.9,
      shopInfo: { ...shop, deptId: correct ? 12 : 999 },
      orderCommodityList: [{ commodityId: 34 }],
    };
  } });
  const draft = await prepare(gateway);
  await assert.rejects(gateway.order({ draftId: draft.draftId, priceCents: 990, confirmed: true }));
  await assert.rejects(gateway.recover({ draftId: draft.draftId, orderId: created.orderIdStr }), /不符/);
  correct = true;
  const order = await gateway.recover({ draftId: draft.draftId, orderId: created.orderIdStr });
  assert.equal(order.status, 'awaiting_payment'); assert.equal(order.priceCents, 990);
  assert.equal(gateway.history()[0].state, 'confirmed');
});

test('concurrent distinct drafts cannot issue two createOrder calls', async () => {
  let finish;
  const { gateway, calls } = fixture({ call: (name) => name === 'createOrder' ? new Promise((resolve) => { finish = () => resolve(structuredClone(created)); }) : undefined });
  const first = await prepare(gateway), second = await prepare(gateway);
  const pending = gateway.order({ draftId: first.draftId, priceCents: 990, confirmed: true });
  await assert.rejects(gateway.order({ draftId: second.draftId, priceCents: 990, confirmed: true }), /正在提交/);
  for (let i = 0; i < 10 && !finish; i++) await new Promise((resolve) => setImmediate(resolve));
  assert.ok(finish); finish(); await pending;
  assert.equal(calls.filter((call) => call.name === 'createOrder').length, 1);
});

test('native location validates provider data and reports permission errors without coordinates', async () => {
  const { locate } = createRequire(import.meta.url)('../desktop/location.cjs');
  const exec = (_file, _args, options, callback) => {
    assert.equal(options.windowsHide, true);
    callback(null, JSON.stringify({ latitude: 30, longitude: 104, accuracy: 25 }));
  };
  assert.deepEqual(await locate({ exec }), { latitude: 30, longitude: 104, accuracy: 25 });
  await assert.rejects(locate({ exec: (_f, _a, _o, callback) => callback(new Error('Denied')) }), /位置服务/);
  await assert.rejects(locate({ exec: (_f, _a, _o, callback) => callback(null, '{"latitude":999,"longitude":104}') }), /有效位置/);
});

test('delivery binds recipient to coffee order and cannot dispatch before official ready state', async () => {
  let state = 10, creates = 0;
  const recipient = { name: '测试', mobile: '13800000000', city: '成都市', addr: '测试地址12345', addrDetail: '8楼' };
  const delivery = {
    configuration: () => ({ configured: true }),
    quote: async (input) => ({ quoteId: 'synthetic-quote', feeCents: 1500, recipient: input.recipient }),
    status: async () => null,
    create: async (input) => { creates++; assert.equal(input.coffeeOrderId, created.orderIdStr); assert.equal(input.pickupCode, 'T123'); return { state: 'confirmed', deliveryId: 'TEST-DELIVERY' }; },
  };
  const { gateway, calls } = fixture({ delivery, call: (name) => name === 'queryOrderDetailInfo' ? { orderId: created.orderIdStr, orderStatus: state, takeMealCodeInfo: { code: 'T123' } } : undefined });
  await gateway.nearby({ latitude: 30, longitude: 104 });
  const item = await gateway.detail({ storeId: 12, productId: 34 });
  const draft = await gateway.preview({ selectionId: item.selectionId, fulfilment: 'delivery', recipient });
  assert.deepEqual(draft.recipient, recipient);
  assert.equal(draft.deliveryQuote.feeCents, 1500);
  assert.equal(calls.some((c) => c.name === 'createOrder'), false);
  const order = await gateway.order({ draftId: draft.draftId, priceCents: 990, confirmed: true });
  assert.deepEqual(order.recipient, recipient);
  await assert.rejects(gateway.deliveryPreview({ orderId: order.orderId }), /先完成/);
  await assert.rejects(gateway.deliveryCreate({ orderId: order.orderId }), /未出餐/);
  state = 30;
  await assert.rejects(gateway.deliveryCreate({ orderId: order.orderId }), /未出餐/);
  assert.equal(creates, 0);
  state = 60;
  await gateway.deliveryPreview({ orderId: order.orderId });
  assert.equal((await gateway.deliveryCreate({ orderId: order.orderId })).delivery.deliveryId, 'TEST-DELIVERY');
  assert.equal(creates, 1);
  await assert.rejects(gateway.deliveryPreview({ orderId: 'other' }), /本机/);
});
