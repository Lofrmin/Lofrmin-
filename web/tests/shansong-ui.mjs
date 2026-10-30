import { createRequire } from 'node:module';
import { mkdirSync } from 'node:fs';
import assert from 'node:assert/strict';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright-core');
const { createLuckinGateway } = require('../desktop/luckin.cjs');
const { createShansongDelivery } = require('../desktop/shansong.cjs');
const { preview } = await import('vite');
let creates = 0, dispatches = 0, orderState = 10, deliveryState = 20, dispatchBody;
let enabled = false;
const delivery = createShansongDelivery({ config: { baseUrl: 'https://open.ishansong.com/openapi/order/v3', partnerNo: 'TEST', key: 'synthetic-key', merchantId: 'TEST-ID', mobile: '13800000000', name: '合成测试', token: 'synthetic-token' }, fetchImpl: async (url, init) => {
  const u = new URL(url);
  let data;
  if (u.pathname.endsWith('/calc')) data = { amount: 1800, cutAmount: 200 };
  else if (u.pathname.endsWith('/save')) { dispatches++; dispatchBody = JSON.parse(init.body); data = 'SYNTHETIC-DELIVERY'; }
  else data = { orderStatus: deliveryState, orderStatusTxt: { 20: '待抢单', 44: '派送中', 60: '已完成' }[deliveryState], courier: '13800000001', courierName: '合成骑手' };
  return Response.json({ status: 'OK', errCode: 0, data });
} });
const shop = { deptId: 12, deptName: '瑞幸合成测试门店', address: '成都市锦江区测试街道2号', latitude: 30, longitude: 104, distance: 0.2 };
const product = { productId: 34, productName: '合成测试拿铁', skuCode: 'TEST-SKU', estimatePrice: 9.9, productAttrs: [] };
const gateway = createLuckinGateway({ token: 'synthetic', delivery, client: { async call(name, args) {
  if (name === 'queryShopList') return [shop];
  if (name === 'searchProductForMcp') return [product];
  if (name === 'queryProductDetailInfo') return product;
  if (name === 'previewOrder') return { discountPrice: 9.9, shopInfo: shop, productInfoList: [{ productId: 34, skuCode: 'TEST-SKU', amount: 1 }], couponCodeList: [] };
  if (name === 'createOrder') { creates++; return { orderIdStr: '123456789', needPay: true, discountPrice: 9.9 }; }
  if (name === 'queryOrderDetailInfo') return { orderId: args.orderId, orderStatus: orderState, orderStatusName: { 10: '待付款', 60: '等待取餐', 80: '已完成' }[orderState], takeMealCodeInfo: { code: 'T123' } };
  throw new Error(`Unexpected ${name}`);
} } });
const server = await preview({ preview: { host: '127.0.0.1', port: 4177, strictPort: true } });
const browser = await chromium.launch({ channel: 'msedge', headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
const errors = []; page.on('pageerror', (e) => errors.push(e.message));
await page.exposeFunction('syntheticCall', (method, input) => {
  if (method === 'locate') return { latitude: 30, longitude: 104 };
  if (method === 'deliveryConfig') return { configured: enabled, message: enabled ? '合成闪送配置' : '闪送待开通：需要商户账号、接口凭据和余额' };
  return gateway[method](input);
});
await page.addInitScript(() => {
  const noop = () => {};
  window.neuroDesktop = {
    selectPet: noop, setNotifications: noop, onSnapshot: noop, onCoffee: noop, autoStart: async () => false,
    snapshot: async () => ({ running: false, status: 'paused' }), screenBrightness: async () => ({ supported: false }),
    coffeeConfig: async () => ({ configured: true, provider: 'luckin', demo: false }),
  };
  for (const [name, method] of Object.entries({ locate: 'locate', deliveryConfig: 'deliveryConfig', nearby: 'nearby', luckinProducts: 'products', luckinDetail: 'detail', luckinPreview: 'preview', luckinHistory: 'history', order: 'order', orderStatus: 'orderStatus', deliveryPreview: 'deliveryPreview', deliveryCreate: 'deliveryCreate', deliveryRecover: 'deliveryRecover' })) {
    window.neuroDesktop[name] = (input) => window.syntheticCall(method, input);
  }
});
async function specification() {
  await page.click('[data-view="desk"]'); await page.click('#coffee-go');
  await page.click('#luckin-locate'); await page.getByRole('button', { name: '选择这家门店' }).click();
  await page.getByRole('button', { name: '选规格', exact: true }).click();
  await page.click('#luckin-delivery');
}
try {
  mkdirSync('artifacts', { recursive: true });
  await page.goto('http://127.0.0.1:4177/'); await page.waitForFunction(() => window.neuro?.coffee.onOffer);
  await specification();
  assert.equal(await page.locator('#luckin-preview').isDisabled(), true);
  assert.match(await page.locator('#coffee-stores').textContent(), /闪送待开通/);
  assert.equal(creates, 0); assert.equal(dispatches, 0);
  enabled = true;
  await page.reload(); await page.waitForFunction(() => window.neuro?.coffee.onOffer);
  await specification();
  await page.click('#luckin-preview');
  await page.waitForFunction(() => document.querySelector('#coffee-status').textContent.includes('收货人'));
  const recipient = { name: '测试收货人', mobile: '13800000000', city: '成都市', addr: '锦江区测试街道1号测试大厦', addrDetail: '8楼前台' };
  for (const [key, value] of Object.entries(recipient)) await page.fill(`#luckin-recipient-${key}`, value);
  await page.click('#luckin-preview'); await page.waitForSelector('#luckin-confirm');
  assert.match(await page.locator('#coffee-stores').textContent(), /闪送预计 ¥16.00.*合计预计 ¥25.90/);
  assert.match(await page.locator('#coffee-stores').textContent(), /8楼前台/);
  assert.equal(creates, 0); assert.equal(dispatches, 0);
  await page.click('#luckin-confirm'); await page.waitForSelector('#luckin-status-refresh');
  assert.equal(creates, 1); assert.equal(dispatches, 0);
  assert.equal(await page.locator('#luckin-delivery-quote').count(), 0);
  orderState = 60;
  await page.click('#luckin-status-refresh'); await page.waitForSelector('#luckin-delivery-quote');
  await page.click('#luckin-delivery-quote'); await page.waitForSelector('#luckin-delivery-confirm');
  assert.equal(await page.locator('#luckin-delivery-confirm').isDisabled(), true);
  await page.setViewportSize({ width: 420, height: 900 });
  assert.equal(await page.locator('#coffee-dialog').evaluate((d) => d.scrollWidth > d.clientWidth), false);
  await page.screenshot({ path: 'artifacts/shansong-confirm-mobile.png', fullPage: true });
  await page.check('#luckin-delivery-billing');
  await page.evaluate(() => { const b = document.querySelector('#luckin-delivery-confirm'); b.click(); b.click(); });
  await page.waitForSelector('#luckin-status-refresh');
  assert.equal(dispatches, 1);
  assert.deepEqual(dispatchBody.order.receiverList, [recipient]); assert.match(dispatchBody.order.remark, /T123/);
  deliveryState = 44; orderState = 80;
  await page.click('#luckin-status-refresh');
  await page.waitForFunction(() => document.querySelector('#coffee-status').textContent.includes('派送中'));
  assert.match(await page.locator('#coffee-stores').textContent(), /合成骑手.*13800000001/);
  await page.screenshot({ path: 'artifacts/shansong-delivering-mobile.png', fullPage: true });
  deliveryState = 60; await page.click('#luckin-status-refresh');
  await page.waitForFunction(() => document.querySelector('#coffee-status').textContent.includes('已完成'));
  await page.reload(); await page.waitForFunction(() => window.neuro?.coffee.onOffer);
  await page.click('[data-view="desk"]'); await page.click('#coffee-go'); await page.click('#luckin-history');
  await page.getByRole('button', { name: /123456789.*查看/ }).click();
  await page.waitForSelector('#luckin-status-refresh');
  assert.match(await page.locator('#coffee-stores').textContent(), /SYNTHETIC-DELIVERY/);
  assert.equal(creates, 1); assert.equal(dispatches, 1); assert.deepEqual(errors, []);
  console.log('FlashEx UI passed: unconfigured gate, validated address, separate prices, paid/ready gate, billing consent, one dispatch, courier/status, history and mobile layout. Synthetic transport only.');
} finally {
  await browser.close(); server.httpServer.closeAllConnections(); await new Promise((resolve) => server.httpServer.close(resolve));
}
