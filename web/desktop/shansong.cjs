// FlashEx V3: https://cdn.ishansong.com/iss-new-pc/images/docs/shansong_api_V3.0.9.pdf
// No default production URL: use the HTTPS endpoint assigned to the merchant.
const fs = require('node:fs');
const path = require('node:path');
const { createHash, randomUUID } = require('node:crypto');

function recipientData(input = {}) {
  const result = {};
  for (const [key, label, min, max] of [['name', '收货人', 1, 40], ['mobile', '手机号', 11, 11], ['city', '城市', 2, 40], ['addr', '收货地址', 6, 200], ['addrDetail', '楼栋门牌', 1, 100]]) {
    const value = typeof input[key] === 'string' ? input[key].trim() : '';
    if (value.length < min || value.length > max || /[\x00-\x1f]/.test(value)) throw new Error(`请填写有效的${label}`);
    result[key] = value;
  }
  if (!/^1[3-9]\d{9}$/.test(result.mobile)) throw new Error('请填写有效的中国大陆手机号');
  return result;
}

function createShansongDelivery({ config = {}, journalPath, fetchImpl = fetch, now = Date.now } = {}) {
  const required = ['baseUrl', 'partnerNo', 'key', 'merchantId', 'mobile', 'name', 'token'];
  const missing = required.filter((key) => typeof config[key] !== 'string' || !config[key].trim());
  let baseUrl = '';
  if (!missing.length) {
    const url = new URL(config.baseUrl);
    if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash
      || !['ishansong.com', 'bingex.com'].some((d) => url.hostname === d || url.hostname.endsWith(`.${d}`))
      || url.pathname.replace(/\/$/, '') !== '/openapi/order/v3') throw new Error('闪送接口需为平台分配的官方 HTTPS V3 地址');
    baseUrl = url.href.replace(/\/$/, '');
  }
  const configured = !missing.length;
  const quotes = new Map(), pending = new Map();
  let rows = [];
  if (journalPath && fs.existsSync(journalPath)) {
    try {
      rows = JSON.parse(fs.readFileSync(journalPath, 'utf8'));
      if (!Array.isArray(rows) || rows.some((r) => !r || typeof r.coffeeOrderId !== 'string' || typeof r.orderNo !== 'string' || !['submitting', 'unknown', 'confirmed'].includes(r.state))) throw new Error();
    } catch { throw new Error('闪送订单记录无法读取，请恢复记录后再发单，避免重复扣费'); }
  }
  const save = () => {
    if (!journalPath) return;
    fs.mkdirSync(path.dirname(journalPath), { recursive: true });
    fs.writeFileSync(`${journalPath}.tmp`, JSON.stringify(rows, null, 2), { mode: 0o600 });
    fs.renameSync(`${journalPath}.tmp`, journalPath);
  };
  const ensure = () => { if (!configured) throw new Error('闪送尚未开通：请配置本机 shansong-config.json 中的商户接口凭据并充值后重启'); };
  const signature = (orderNo) => createHash('md5').update(`${config.partnerNo}${orderNo}${config.mobile}${config.key}`, 'utf8').digest('hex').toUpperCase();
  async function request(operation, orderNo, order, issOrderNo = '') {
    ensure();
    const sig = signature(orderNo);
    const url = new URL(`${baseUrl}/${operation}`);
    const init = { method: order ? 'POST' : 'GET', redirect: 'error', signal: AbortSignal.timeout(25000), headers: { 'Content-Type': 'application/json' } };
    if (order) init.body = JSON.stringify({ partnerNo: config.partnerNo, signature: sig, order: { ...order, merchant: { id: config.merchantId, mobile: config.mobile, name: config.name, token: config.token } } });
    else url.search = new URLSearchParams({ partnerno: config.partnerNo, orderno: orderNo, mobile: config.mobile, issorderno: issOrderNo, signature: sig }).toString();
    try {
      const response = await fetchImpl(url.href, init);
      if (!response.ok) throw new Error(`闪送服务暂不可用（${response.status}）`);
      const data = await response.json();
      if (data?.status !== 'OK' || data.errCode !== 0) throw new Error(`闪送未确认操作（${Number(data?.errCode) || '未知错误'}），请在闪送商户平台核实`);
      return data.data;
    } catch (error) {
      // Fetch errors may contain URLs/addresses. Only surface our controlled errors.
      if (/^闪送(服务暂不可用|未确认操作)/.test(error.message)) throw error;
      throw new Error('闪送请求失败或超时，请检查网络并核实订单');
    }
  }
  function orderData({ store, recipient, productName, pickupCode = '' }, orderNo) {
    const receiver = recipientData(recipient);
    if (!store?.name || !store?.address) throw new Error('门店地址不完整，无法呼叫闪送');
    // V3 reverse-geocodes addresses when coords are omitted. Never send WGS/GCJ coords as BD09.
    return { orderNo, sender: { name: String(store.name).slice(0, 40), mobile: receiver.mobile, city: receiver.city, addr: store.address, addrDetail: '瑞幸咖啡门店取餐；联系收货人确认取餐信息' },
      receiverList: [receiver], goods: '咖啡', weight: 1, addition: 0, appointTime: null,
      remark: `${productName}；取餐码：${pickupCode || '出餐后提供'}；请保持直立，轻拿轻放。`.slice(0, 250) };
  }
  function price(data) {
    if (!Number.isSafeInteger(data?.amount) || data.amount < 0 || !Number.isSafeInteger(data.cutAmount ?? 0) || (data.cutAmount ?? 0) < 0 || (data.cutAmount ?? 0) > data.amount) throw new Error('闪送报价数据不完整');
    return data.amount - (data.cutAmount ?? 0);
  }
  const view = (r) => ({ state: r.state, orderNo: r.orderNo, deliveryId: r.deliveryId || '', feeCents: r.feeCents,
    status: r.status || 'pending', statusText: r.state !== 'confirmed' ? '闪送发单结果待核实，请勿重复呼叫' : r.statusText || '闪送已创建，等待骑手接单',
    courier: r.courier || '', courierName: r.courierName || '' });
  return {
    configuration: () => ({ provider: 'shansong', configured, message: configured ? '闪送商户服务已配置，费用由商户余额支付' : '闪送待开通：需要商户账号、接口凭据和余额' }),
    async quote(input) {
      ensure();
      const orderNo = `ND${randomUUID().replaceAll('-', '')}`;
      const payload = orderData(input, orderNo);
      const data = await request('calc', orderNo, payload);
      const quote = { quoteId: randomUUID(), feeCents: price(data), expiresAt: now() + 120000 };
      quotes.set(quote.quoteId, { ...quote, payload, pickupCode: input.pickupCode || '', coffeeOrderId: input.coffeeOrderId || null });
      return { ...quote, recipient: payload.receiverList[0] };
    },
    create({ quoteId, coffeeOrderId, pickupCode, feeCents, confirmed, acceptBilling } = {}) {
      if (confirmed !== true || acceptBilling !== true) return Promise.reject(new Error('请确认配送地址、报价及闪送余额扣费方式'));
      if (pending.has(coffeeOrderId)) return pending.get(coffeeOrderId);
      const task = (async () => {
        ensure();
        const existing = rows.find((r) => r.coffeeOrderId === coffeeOrderId);
        if (existing) {
          if (existing.state !== 'confirmed') throw new Error(`闪送结果待核实，商户订单号 ${existing.orderNo}，请勿重复发单`);
          return view(existing);
        }
        const q = quotes.get(quoteId);
        if (!q || q.coffeeOrderId !== coffeeOrderId || !coffeeOrderId || now() > q.expiresAt) throw new Error('配送报价已过期，请重新查询');
        if (!q.pickupCode || q.pickupCode !== pickupCode) throw new Error('取餐码已变化，请重新查询配送报价');
        if (q.feeCents !== feeCents) throw new Error('配送报价不一致，请重新确认');
        const refreshed = price(await request('calc', q.payload.orderNo, q.payload));
        if (refreshed !== q.feeCents) throw new Error('配送费已变化，请重新查询并确认');
        const row = { coffeeOrderId, orderNo: q.payload.orderNo, feeCents, state: 'submitting', at: now() };
        rows.push(row); save(); // Persist BEFORE a request that can debit the merchant balance.
        try {
          const id = await request('save', row.orderNo, q.payload);
          if (typeof id !== 'string' || !/^[\w-]{3,100}$/.test(id)) throw new Error('闪送未返回可核实的配送单号');
          row.deliveryId = id; row.state = 'confirmed'; save(); return view(row);
        } catch (error) { row.state = 'unknown'; save(); throw new Error(`${error.message}。请在闪送商户平台按 ${row.orderNo} 核实，不会自动重发。`); }
      })();
      pending.set(coffeeOrderId, task);
      task.finally(() => pending.delete(coffeeOrderId)).catch(() => {});
      return task;
    },
    async status(coffeeOrderId) {
      const row = rows.find((r) => r.coffeeOrderId === coffeeOrderId);
      if (!row) return null;
      if (row.state !== 'confirmed') return view(row);
      const data = await request('info', row.orderNo, null, row.deliveryId);
      const status = { 20: 'waiting', 30: 'assigned', 42: 'arrived', 44: 'delivering', 60: 'completed', 64: 'cancelled' }[data?.orderStatus];
      if (!status) throw new Error('闪送返回未知配送状态，请在商户平台核实');
      Object.assign(row, { status, statusText: String(data.orderStatusTxt || '闪送状态已更新'), courier: String(data.courier || ''), courierName: String(data.courierName || '') });
      save(); return view(row);
    },
    async recover({ coffeeOrderId, deliveryId } = {}) {
      const row = rows.find((r) => r.coffeeOrderId === coffeeOrderId);
      if (!row || row.state === 'confirmed' || pending.has(coffeeOrderId) || typeof deliveryId !== 'string' || !/^[\w-]{3,100}$/.test(deliveryId)) throw new Error('请填写商户平台中与本单匹配的闪送单号');
      // Query verifies the merchant order number + platform order number pair with FlashEx.
      await request('info', row.orderNo, null, deliveryId);
      row.deliveryId = deliveryId; row.state = 'confirmed'; save();
      return this.status(coffeeOrderId);
    },
  };
}
module.exports = { createShansongDelivery, recipientData };
