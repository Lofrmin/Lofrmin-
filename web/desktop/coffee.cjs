// Credentials stay in the main process. A merchant adapter owns pricing, payment and fulfilment.
const validCoords = (p) => p && Number.isFinite(p.latitude) && Math.abs(p.latitude) <= 90 && Number.isFinite(p.longitude) && Math.abs(p.longitude) <= 180;
function createCoffeeGateway({ baseUrl, token, fetchImpl = fetch } = {}) {
  let catalog = [];
  const orders = new Map();
  if (baseUrl) {
    const url = new URL(baseUrl);
    if (url.protocol !== 'https:' && !(url.protocol === 'http:' && ['localhost', '127.0.0.1'].includes(url.hostname))) throw new Error('咖啡接口必须使用 HTTPS 或本机 HTTP');
    baseUrl = url.href.replace(/\/$/, '');
  }
  async function request(path, init = {}) {
    if (!baseUrl) throw new Error('尚未接入咖啡服务，当前仅可预览推荐流程');
    const response = await fetchImpl(`${baseUrl}${path}`, { ...init, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...init.headers }, signal: AbortSignal.timeout(20000) });
    if (!response.ok) throw new Error(`咖啡服务暂不可用（${response.status}）`);
    return response.json();
  }
  return {
    configured: Boolean(baseUrl),
    async nearby(coords) {
      if (!validCoords(coords)) throw new Error('请先获取有效位置');
      const data = await request(`/stores/nearby?latitude=${coords.latitude}&longitude=${coords.longitude}`);
      if (!Array.isArray(data.stores)) throw new Error('门店数据格式不正确');
      catalog = data.stores.filter((s) => s && typeof s.id === 'string' && typeof s.name === 'string' && Number.isFinite(s.distanceMeters) && s.distanceMeters >= 0 && Array.isArray(s.products)).map((s) => ({
        id: s.id, name: s.name, distanceMeters: s.distanceMeters, address: String(s.address ?? ''),
        products: s.products.filter((p) => p && typeof p.id === 'string' && typeof p.name === 'string' && Number.isSafeInteger(p.priceCents) && p.priceCents > 0 && p.available === true).map((p) => ({ id: p.id, name: p.name, priceCents: p.priceCents, available: true })),
      })).filter((s) => s.products.length).sort((a, b) => a.distanceMeters - b.distanceMeters);
      return { stores: catalog };
    },
    async orderStatus(orderId) {
      if (typeof orderId !== 'string' || !/^[\w-]{3,120}$/.test(orderId)) throw new Error('订单编号无效');
      const order = await request(`/orders/${encodeURIComponent(orderId)}`);
      if (order.orderId !== orderId || typeof order.status !== 'string') throw new Error('订单状态格式不正确');
      return { orderId, status: order.status, pickupCode: String(order.pickupCode ?? ''), step: Number(order.step) || 1, totalSteps: Number(order.totalSteps) || 4, statusText: String(order.statusText ?? '订单处理中') };
    },
    async order(input) {
      if (!input || typeof input.idempotencyKey !== 'string' || !/^[\w-]{16,80}$/.test(input.idempotencyKey)) throw new Error('订单标识无效');
      if (orders.has(input.idempotencyKey)) return orders.get(input.idempotencyKey);
      const store = catalog.find((s) => s.id === input.storeId);
      const product = store?.products.find((p) => p.id === input.productId);
      if (!product || input.priceCents !== product.priceCents) throw new Error('商品或价格已变化，请重新获取门店');
      // The adapter must persist idempotency keys, including across app restarts.
      const pending = request('/orders', { method: 'POST', headers: { 'Idempotency-Key': input.idempotencyKey }, body: JSON.stringify({ storeId: store.id, productId: product.id, quantity: 1, expectedPriceCents: product.priceCents, fulfilment: 'pickup' }) }).then((order) => {
        if (typeof order.orderId !== 'string' || !order.orderId || !['accepted', 'paid'].includes(order.status)) throw new Error('服务未确认订单，请检查平台订单记录');
        return { orderId: order.orderId, status: order.status, pickupCode: String(order.pickupCode ?? ''), storeName: store.name, productName: product.name };
      });
      pending.catch(() => orders.delete(input.idempotencyKey));
      orders.set(input.idempotencyKey, pending);
      return pending;
    },
  };
}
module.exports = { createCoffeeGateway, validCoords };
