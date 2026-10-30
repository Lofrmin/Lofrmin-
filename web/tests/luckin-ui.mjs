import { createRequire } from 'node:module';
import { mkdirSync } from 'node:fs';
import assert from 'node:assert/strict';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright-core');
const { createLuckinGateway } = require('../desktop/luckin.cjs');
const { preview } = await import('vite');
let creates = 0, nearbyCalls = 0, locateAllowed = false, orderState = 10, sku = 'SKU-ICE';
const shop = { deptId: 12, deptName: '瑞幸测试门店（合成数据）', address: '界面测试地址', latitude: 30, longitude: 104, distance: 0.2 };
const product = () => ({ productId: 34, productName: '测试拿铁', skuCode: sku, estimatePrice: 12.9, productAttrs: [{ attributeId: 1, attributeName: '温度', productSubAttrs: [{ attributeId: 2, attributeName: '冰', selected: sku === 'SKU-ICE', canSelected: 1 }, { attributeId: 3, attributeName: '热', selected: sku === 'SKU-HOT', canSelected: 1 }] }] });
const gateway = createLuckinGateway({ token: 'synthetic', client: { async call(name, args) {
  if (name === 'queryShopList') { nearbyCalls++; return [shop]; }
  if (name === 'searchProductForMcp') return [product()];
  if (name === 'queryProductDetailInfo') return product();
  if (name === 'switchProduct') { sku = 'SKU-HOT'; return product(); }
  if (name === 'previewOrder') return { discountPrice: 9.9, shopInfo: shop, productInfoList: [{ productId: 34, skuCode: sku, name: '测试拿铁', amount: 1, additionDesc: '热·大杯' }], couponCodeList: ['TEST-COUPON'] };
  if (name === 'createOrder') { creates++; assert.equal(args.productList[0].skuCode, 'SKU-HOT'); return { orderIdStr: '7639308439653908490', needPay: true, discountPrice: 9.9, payOrderUrl: 'weixin://wxpay/bizpayurl?pr=synthetic' }; }
  if (name === 'queryOrderDetailInfo') return { orderId: args.orderId, orderStatus: orderState, orderStatusName: { 10: '待付款', 30: '制作中', 60: '等待取餐' }[orderState], takeMealCodeInfo: { code: 'T123' } };
  throw new Error(`Unexpected tool ${name}`);
} } });
const server = await preview({ preview: { host: '127.0.0.1', port: 4176, strictPort: true } });
const browser = await chromium.launch({ channel: 'msedge', headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
const errors = []; page.on('pageerror', (error) => errors.push(error.message));
await page.exposeFunction('luckinCall', async (method, input) => {
  if (method === 'locate') { if (!locateAllowed) throw new Error('Windows 定位未开启，请开启位置服务或手动填写坐标。'); return { latitude: 30, longitude: 104 }; }
  return gateway[method](input);
});
await page.addInitScript(() => {
  const noop = () => {};
  window.neuroDesktop = {
    selectPet: noop, setNotifications: noop, onSnapshot: noop, onCoffee: noop, autoStart: async () => false,
    snapshot: async () => ({ running: false, status: 'paused' }),
    screenBrightness: async () => ({ supported: false, message: 'Synthetic UI test' }),
    coffeeConfig: async () => ({ configured: true, provider: 'luckin', demo: false }),
    locate: () => window.luckinCall('locate'),
    nearby: (input) => window.luckinCall('nearby', input),
    luckinProducts: (input) => window.luckinCall('products', input),
    luckinDetail: (input) => window.luckinCall('detail', input),
    luckinSwitch: (input) => window.luckinCall('switchAttribute', input),
    luckinPreview: (input) => window.luckinCall('preview', input),
    luckinHistory: () => window.luckinCall('history'),
    luckinRecover: (input) => window.luckinCall('recover', input),
    luckinResolve: (input) => window.luckinCall('resolveUnknown', input),
    order: (input) => window.luckinCall('order', input),
    orderStatus: (input) => window.luckinCall('orderStatus', input),
  };
});
try {
  mkdirSync('artifacts', { recursive: true });
  await page.goto('http://127.0.0.1:4176/');
  await page.waitForFunction(() => window.neuro?.coffee.onOffer);
  await page.click('[data-view="desk"]'); await page.click('#coffee-go');
  await page.waitForSelector('#luckin-locate');
  assert.equal(nearbyCalls, 0, 'opening dialog never sends location');
  await page.click('#luckin-locate');
  await page.waitForFunction(() => document.querySelector('#coffee-status').textContent.includes('定位未开启'));
  assert.equal(nearbyCalls, 0, 'denied location never calls the merchant');
  locateAllowed = true;
  await page.click('#luckin-locate'); await page.getByRole('button', { name: '选择这家门店' }).click();
  await page.getByRole('button', { name: '选规格', exact: true }).click();
  await page.getByRole('button', { name: '热', exact: true }).click();
  await page.getByRole('button', { name: '✓ 热', exact: true }).waitFor();
  await page.click('#luckin-preview'); await page.waitForSelector('#luckin-confirm');
  assert.equal(creates, 0, 'preview must never create a merchant order');
  assert.match(await page.locator('#coffee-stores').textContent(), /实际应付 ¥9.90/);
  assert.match(await page.locator('#coffee-stores').textContent(), /热·大杯/);
  await page.screenshot({ path: 'artifacts/luckin-confirmation-test.png', fullPage: true });
  await page.evaluate(() => { const b = document.querySelector('#luckin-confirm'); b.click(); b.click(); });
  await page.waitForSelector('#luckin-status-refresh');
  assert.equal(creates, 1);
  assert.match(await page.locator('#coffee-status').textContent(), /7639308439653908490.*待付款/);
  assert.doesNotMatch(await page.locator('#coffee-stores').textContent(), /取餐码 T123/);
  orderState = 30;
  await page.click('#luckin-status-refresh'); await page.waitForFunction(() => document.querySelector('#coffee-status').textContent.includes('制作中'));
  assert.equal(await page.locator('#coffee-src').textContent(), '制作中');
  orderState = 60;
  await page.click('#luckin-status-refresh'); await page.waitForFunction(() => document.querySelector('#coffee-status').textContent.includes('等待取餐'));
  assert.match(await page.locator('#coffee-stores').textContent(), /取餐码 T123/);
  assert.doesNotMatch(await page.locator('#coffee-dialog').textContent(), /企业餐补直付|无人车/);
  await page.setViewportSize({ width: 420, height: 900 });
  await page.screenshot({ path: 'artifacts/luckin-order-mobile-test.png', fullPage: true });
  assert.equal(await page.locator('#coffee-dialog').evaluate((d) => d.scrollWidth > d.clientWidth), false);
  await page.reload(); await page.waitForFunction(() => window.neuro?.coffee.onOffer);
  await page.click('[data-view="desk"]'); await page.click('#coffee-go'); await page.click('#luckin-history');
  await page.getByRole('button', { name: /7639308439653908490.*查看/ }).click();
  await page.waitForSelector('#luckin-status-refresh');
  assert.equal(creates, 1, 'reopening history never creates another order');
  assert.deepEqual(errors, []);
  console.log('Luckin UI passed: explicit location, denial fallback, product/attribute/quote, one confirmed synthetic order, pending-payment state, real-state mapping, history, mobile layout. No live purchase.');
} finally {
  await browser.close(); server.httpServer.closeAllConnections(); await new Promise((resolve) => server.httpServer.close(resolve));
}
