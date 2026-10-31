// Local-only fulfilment fixture. It never represents a merchant order or payment.
const http = require('node:http');
const crypto = require('node:crypto');
const STAGES = [
  ['accepted', '本机演示已接单'],
  ['preparing', '演示咖啡制作中'],
  ['delivering', '演示无人车配送中'],
  ['ready', '演示订单已到达，请取餐'],
];
function startCoffeeDemo({ host = '127.0.0.1', port = 18081, stageMs = 2500 } = {}) {
  const orders = new Map();
  const keys = new Map();
  const server = http.createServer(async (req, res) => {
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    try {
      const url = new URL(req.url, `http://${host}`);
      if (req.method === 'GET' && url.pathname === '/health') return send(res, { ok: true, mode: 'local-demo' });
      if (req.method === 'GET' && url.pathname === '/stores/nearby') {
        const stores = [{ id: 'demo-store', name: 'NeuroDesk 咖啡实验室', address: '本机演示 · 不产生真实订单或扣款', distanceMeters: 120, products: [
          { id: 'americano', name: '经典美式', priceCents: 1800, available: true },
          { id: 'latte', name: '燕麦拿铁', priceCents: 2600, available: true },
        ] }];
        return send(res, { stores, mode: 'local-demo' });
      }
      if (req.method === 'POST' && url.pathname === '/orders') {
        const key = req.headers['idempotency-key'];
        if (typeof key !== 'string' || !/^[\w-]{16,80}$/.test(key)) return send(res, { error: '缺少有效幂等键' }, 400);
        if (keys.has(key)) return send(res, publicOrder(orders.get(keys.get(key))));
        const body = await readJson(req);
        const products = { americano: ['经典美式', 1800], latte: ['燕麦拿铁', 2600] };
        const product = products[body.productId];
        if (body.storeId !== 'demo-store' || !product || body.expectedPriceCents !== product[1] || body.quantity !== 1 || body.fulfilment !== 'pickup') return send(res, { error: '商品、价格或自取参数不匹配' }, 409);
        const order = { orderId: `DEMO-${crypto.randomUUID().slice(0, 8).toUpperCase()}`, storeId: body.storeId, productName: product[0], priceCents: product[1], pickupCode: `D${crypto.randomInt(100, 1000)}`, createdAt: Date.now() };
        orders.set(order.orderId, order); keys.set(key, order.orderId);
        return send(res, publicOrder(order), 202);
      }
      const match = url.pathname.match(/^\/orders\/(DEMO-[\w-]+)$/);
      if (req.method === 'GET' && match && orders.has(match[1])) return send(res, publicOrder(orders.get(match[1])));
      send(res, { error: '订单不存在或接口路径错误' }, 404);
    } catch (error) { send(res, { error: error.message }, 400); }
  });
  function publicOrder(order) {
    const index = Math.min(STAGES.length - 1, Math.floor((Date.now() - order.createdAt) / stageMs));
    const [status, text] = STAGES[index];
    return { orderId: order.orderId, status, pickupCode: order.pickupCode, productName: order.productName, step: index + 1, totalSteps: STAGES.length, statusText: text, mode: 'local-demo' };
  }
  return new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, host, () => resolve({ server, origin: `http://${host}:${server.address().port}` }));
  });
}
function send(res, data, status = 200) { res.writeHead(status); res.end(JSON.stringify(data)); }
async function readJson(req) {
  let text = '';
  for await (const chunk of req) { text += chunk; if (text.length > 16384) throw new Error('请求体过大'); }
  return JSON.parse(text || '{}');
}
module.exports = { startCoffeeDemo };
