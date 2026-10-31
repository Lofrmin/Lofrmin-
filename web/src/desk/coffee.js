// Examples are labelled in the UI; only the desktop gateway can place real orders.
export const SAMPLE_STORES = [
  { id: 'sample-1', name: '街角咖啡 · 示例门店', address: '接入服务后显示真实地址', distanceMeters: 260, products: [
    { id: 'americano', name: '经典美式', priceCents: 1800 }, { id: 'latte', name: '燕麦拿铁', priceCents: 2600 },
  ] },
  { id: 'sample-2', name: '日常咖啡 · 示例门店', address: '接入服务后显示真实地址', distanceMeters: 580, products: [
    { id: 'flat-white', name: '馥芮白', priceCents: 2400 },
  ] },
];
export class Coffee {
  constructor() {
    this.order = null; this.listeners = new Set(); this.busy = false; this.pending = null;
    try { this.pending = JSON.parse(localStorage.getItem('nd-pending-order') ?? 'null'); } catch { /* Ignore invalid saved state. */ }
  }
  onChange(fn) { this.listeners.add(fn); return () => this.listeners.delete(fn); }
  emit() { for (const fn of this.listeners) fn(this.order); }
  request() { this.onOffer?.(); }
  async nearby(coords) {
    if (!window.neuroDesktop || !(await window.neuroDesktop.coffeeConfig()).configured) return { stores: SAMPLE_STORES, sample: true };
    const config = await window.neuroDesktop.coffeeConfig();
    return { ...(await window.neuroDesktop.nearby(coords)), sample: false, demo: config.demo === true, merchant: config.demo !== true };
  }
  async submit(store, product) {
    if (this.busy) return null;
    if (!window.neuroDesktop || !(await window.neuroDesktop.coffeeConfig()).configured) throw new Error('咖啡服务尚未接入，示例商品不能下单');
    if (this.pending && (this.pending.storeId !== store.id || this.pending.productId !== product.id)) throw new Error('上一笔订单结果待确认，请先重试同一商品或查看平台订单');
    this.pending ??= { storeId: store.id, productId: product.id, priceCents: product.priceCents, idempotencyKey: crypto.randomUUID() };
    localStorage.setItem('nd-pending-order', JSON.stringify(this.pending));
    this.busy = true;
    try {
      const order = await window.neuroDesktop.order(this.pending);
      this.order = { ...order, done: true };
      this.pending = null;
      localStorage.removeItem('nd-pending-order');
      this.emit();
      return order;
    } finally { this.busy = false; }
  }
}
