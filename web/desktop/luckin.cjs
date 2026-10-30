const fs = require('node:fs');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const { validCoords } = require('./coffee.cjs');
const ENDPOINT = 'https://gwmcp.lkcoffee.com/order/user/mcp';
const TOOLS = new Set(['queryShopList', 'searchProductForMcp', 'queryProductDetailInfo', 'switchProduct', 'previewOrder', 'createOrder', 'queryOrderDetailInfo']);

function createLuckinClient({ token, fetchImpl = fetch } = {}) {
  let id = 0;
  return { async call(name, args) {
    if (!token) throw new Error('尚未配置瑞幸授权，请在本机配置 Token。');
    if (!TOOLS.has(name)) throw new Error('不支持的瑞幸操作');
    try {
      const requestId = ++id;
      const response = await fetchImpl(ENDPOINT, {
        method: 'POST', redirect: 'error',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', Accept: 'application/json, text/event-stream' },
        body: JSON.stringify({ jsonrpc: '2.0', id: requestId, method: 'tools/call', params: { name, arguments: args } }),
        signal: AbortSignal.timeout(25000),
      });
      if ([401, 403].includes(response.status)) throw new Error('瑞幸授权已过期或无效，请更新本机 Token。');
      if (!response.ok) throw new Error(`瑞幸服务暂不可用（${response.status}）`);
      const text = await response.text();
      const messages = response.headers.get('content-type')?.includes('text/event-stream')
        ? text.split(/\r?\n\r?\n/).map((event) => event.split(/\r?\n/).filter((line) => line.startsWith('data:')).map((line) => line.slice(5).trim()).join('\n')).filter(Boolean).map((data) => JSON.parse(data))
        : [JSON.parse(text)];
      const rpc = messages.find((item) => item.id === requestId);
      if (!rpc || rpc.error) throw new Error(rpc?.error?.message || '瑞幸接口响应不完整');
      const result = rpc.result;
      const data = result?.structuredContent || JSON.parse(result?.content?.find((item) => item.type === 'text')?.text || 'null');
      if (result?.isError || !data || data.success !== true || data.code !== 0) throw new Error(data?.msg || '瑞幸未确认本次操作');
      return data.data;
    } catch (error) {
      // Never propagate request headers or the credential into renderer errors/logs.
      const detail = String(error.message || '网络错误').split(token).join('[已隐藏]').slice(0, 300);
      throw new Error(/timeout|aborted/i.test(detail) ? '瑞幸请求超时，请稍后查询确认。' : detail);
    }
  } };
}

const cents = (value) => {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0 || value > 100000) throw new Error('瑞幸价格数据不完整，请重新查询。');
  return Math.round(value * 100);
};
const integer = (value) => Number.isSafeInteger(value) && value > 0;
function paymentUrl(value) {
  if (typeof value !== 'string' || value.length > 8192) return '';
  try {
    const url = new URL(value);
    if (url.username || url.password) return '';
    if (url.protocol === 'weixin:' && url.hostname === 'wxpay' && url.pathname === '/bizpayurl') return url.href;
    if (url.protocol === 'https:' && ['lkcoffee.com', 'luckincoffeecdn.com'].some((domain) => url.hostname === domain || url.hostname.endsWith(`.${domain}`))) return url.href;
  } catch { /* Ignore invalid upstream URL. */ }
  return '';
}
function createJournal(file) {
  let rows = [];
  if (file && fs.existsSync(file)) {
    try { rows = JSON.parse(fs.readFileSync(file, 'utf8')); if (!Array.isArray(rows)) throw new Error(); }
    catch { throw new Error('瑞幸订单记录无法读取，请先恢复订单记录，避免重复下单。'); }
  }
  return {
    rows,
    save() {
      if (!file) return;
      fs.mkdirSync(path.dirname(file), { recursive: true });
      fs.writeFileSync(`${file}.tmp`, JSON.stringify(rows, null, 2), { mode: 0o600 });
      fs.renameSync(`${file}.tmp`, file);
    },
  };
}

function createLuckinGateway({ token, client = createLuckinClient({ token }), journalPath, now = Date.now, delivery } = {}) {
  const stores = new Map(), selections = new Map(), drafts = new Map(), inFlight = new Map();
  const journal = createJournal(journalPath);
  const getStore = (id) => { const store = stores.get(id); if (!store) throw new Error('请重新查询并选择瑞幸门店'); return store; };
  const getSelection = (id) => { const selected = selections.get(id); if (!selected || now() - selected.at > 30 * 60000) throw new Error('商品选择已过期，请重新选择'); return selected; };
  function selection(store, data) {
    if (!integer(data?.productId) || typeof data.skuCode !== 'string' || !data.skuCode) throw new Error('瑞幸商品数据不完整');
    const item = {
      selectionId: randomUUID(), storeId: store.id, id: data.productId, name: String(data.productName || ''), skuCode: data.skuCode,
      priceCents: cents(data.estimatePrice ?? data.initialPrice),
      attrs: (data.productAttrs || []).map((group) => ({ id: group.attributeId, name: String(group.attributeName), options: (group.productSubAttrs || []).map((option) => ({ id: option.attributeId, name: String(option.attributeName), selected: option.selected === true, enabled: option.canSelected !== 0 })) })),
      at: now(),
    };
    selections.set(item.selectionId, item);
    return item;
  }
  function previewData(store, item, data) {
    const p = data?.productInfoList?.[0];
    if (!p || data.productInfoList.length !== 1 || p.productId !== item.id || p.skuCode !== item.skuCode || p.amount !== 1 || data.shopInfo?.deptId !== store.id) throw new Error('瑞幸预览与所选门店/商品不一致，请重新选择');
    return {
      draftId: randomUUID(), storeId: store.id, storeName: store.name, address: store.address,
      productId: item.id, productName: String(p.name || item.name), skuCode: item.skuCode,
      specification: String(p.additionDesc || ''), amount: 1, priceCents: cents(data.discountPrice),
      couponCodeList: Array.isArray(data.couponCodeList) ? data.couponCodeList.filter((code) => typeof code === 'string') : [],
      expiresAt: now() + 5 * 60000,
    };
  }
  const productList = (item) => [{ amount: 1, productId: item.productId ?? item.id, skuCode: item.skuCode }];
  const gateway = {
    configured: Boolean(token),
    async nearby({ latitude, longitude, name = '' } = {}) {
      if (!validCoords({ latitude, longitude })) throw new Error('请允许定位，或填写有效的经纬度');
      if (typeof name !== 'string' || name.length > 100) throw new Error('门店名称过长');
      const data = await client.call('queryShopList', { latitude, longitude, ...(name.trim() ? { deptName: name.trim() } : {}) });
      if (!Array.isArray(data)) throw new Error('瑞幸门店数据格式不正确');
      const result = data.filter((s) => integer(s.deptId) && validCoords(s) && typeof s.deptName === 'string').map((s) => ({
        id: s.deptId, name: s.deptName, address: String(s.address || ''), latitude: s.latitude, longitude: s.longitude,
        distanceMeters: Number.isFinite(s.distance) ? Math.round(s.distance * 1000) : null,
        hours: `${s.workTimeStart || ''}–${s.workTimeEnd || ''}`,
      })).sort((a, b) => (a.distanceMeters ?? Infinity) - (b.distanceMeters ?? Infinity));
      result.forEach((store) => stores.set(store.id, store));
      return { stores: result };
    },
    async products({ storeId, query = '咖啡' } = {}) {
      const store = getStore(storeId);
      if (typeof query !== 'string' || !query.trim() || query.length > 100) throw new Error('请输入 1–100 字的饮品名称');
      const data = await client.call('searchProductForMcp', { deptId: store.id, query: query.trim() });
      if (!Array.isArray(data)) throw new Error('瑞幸商品数据格式不正确');
      return { products: data.map((p) => selection(store, p)) };
    },
    async detail({ storeId, productId } = {}) {
      const store = getStore(storeId);
      if (!integer(productId)) throw new Error('商品编号无效');
      return selection(store, await client.call('queryProductDetailInfo', { deptId: store.id, productId }));
    },
    async switchAttribute({ selectionId, groupId, optionId } = {}) {
      const item = getSelection(selectionId), store = getStore(item.storeId);
      const group = item.attrs.find((g) => g.id === groupId), option = group?.options.find((o) => o.id === optionId && o.enabled);
      if (!option) throw new Error('该规格暂不可选，请刷新商品');
      return selection(store, await client.call('switchProduct', { deptId: store.id, productId: item.id, skuCode: item.skuCode, amount: 1, attrOperationParam: { attributeId: groupId, subAttr: { attributeId: optionId, operation: 3 } } }));
    },
    deliveryConfig: () => delivery?.configuration() || { provider: 'shansong', configured: false, message: '闪送尚未配置' },
    async preview({ selectionId, fulfilment = 'pickup', recipient } = {}) {
      if (!['pickup', 'delivery'].includes(fulfilment)) throw new Error('请选择到店自取或闪送配送');
      const item = getSelection(selectionId), store = getStore(item.storeId);
      const draft = previewData(store, item, await client.call('previewOrder', { deptId: store.id, productList: productList(item) }));
      draft.fulfilment = fulfilment;
      if (fulfilment === 'delivery') {
        if (!delivery) throw new Error('闪送尚未配置');
        draft.deliveryQuote = await delivery.quote({ store, recipient, productName: draft.productName });
        draft.recipient = draft.deliveryQuote.recipient;
      }
      drafts.set(draft.draftId, draft);
      return draft;
    },
    order(input = {}) {
      if (input.confirmed !== true) return Promise.reject(new Error('请先确认门店、规格和实际付款价格'));
      if (inFlight.has(input.draftId)) return inFlight.get(input.draftId);
      if (inFlight.size) return Promise.reject(new Error('正在提交订单，请等待当前订单结果'));
      const promise = (async () => {
        const saved = journal.rows.find((row) => row.draftId === input.draftId);
        if (saved?.order) return saved.order;
        if (journal.rows.some((row) => row.state === 'submitting' || row.state === 'unknown')) throw new Error('有一笔订单结果待核实，请先在瑞幸 App 查看订单，并在本平台核实后再下单。');
        const draft = drafts.get(input.draftId);
        if (!draft || now() > draft.expiresAt) throw new Error('订单报价已过期，请重新预览');
        if (input.priceCents !== draft.priceCents) throw new Error('确认价格不一致，请重新预览');
        const store = getStore(draft.storeId);
        const refreshed = previewData(store, { id: draft.productId, skuCode: draft.skuCode, name: draft.productName }, await client.call('previewOrder', { deptId: store.id, productList: productList(draft) }));
        if (refreshed.priceCents !== draft.priceCents || JSON.stringify(refreshed.couponCodeList) !== JSON.stringify(draft.couponCodeList)) throw new Error('价格或优惠已变化，请重新预览并确认');
        const attempt = { draftId: draft.draftId, state: 'submitting', at: now(), storeName: draft.storeName, productName: draft.productName, draft };
        journal.rows.push(attempt); journal.save();
        try {
          const data = await client.call('createOrder', { deptId: store.id, productList: productList(draft), longitude: store.longitude, latitude: store.latitude, couponCodeList: draft.couponCodeList });
          const id = data?.orderIdStr || (Number.isSafeInteger(data?.orderId) ? String(data.orderId) : typeof data?.orderId === 'string' ? data.orderId : '');
          if (!/^\d{3,40}$/.test(id) || typeof data.needPay !== 'boolean') throw new Error('瑞幸未返回可核实的订单编号或支付状态');
          const order = {
            orderId: id, status: data.needPay ? 'awaiting_payment' : 'accepted', needPay: data.needPay,
            priceCents: cents(data.discountPrice), payUrl: paymentUrl(data.payOrderUrl), qrUrl: paymentUrl(data.payOrderQrCodeUrl),
            storeName: draft.storeName, address: draft.address, productName: draft.productName, specification: draft.specification,
            fulfilment: draft.fulfilment, recipient: draft.recipient,
            pickupCode: '', statusText: data.needPay ? '待付款' : '订单已创建，请刷新确认制作状态',
          };
          attempt.state = 'confirmed'; attempt.order = order; journal.save();
          return order;
        } catch (error) {
          attempt.state = 'unknown'; journal.save();
          throw new Error(`${error.message}。为避免重复下单，请先在瑞幸 App 核实订单，平台不会自动重试。`);
        }
      })();
      inFlight.set(input.draftId, promise);
      promise.finally(() => inFlight.delete(input.draftId)).catch(() => {});
      return promise;
    },
    async orderStatus(orderId) {
      const row = journal.rows.find((entry) => entry.order?.orderId === orderId);
      if (!row) throw new Error('请从本机订单记录选择订单');
      const data = await client.call('queryOrderDetailInfo', { orderId });
      if (String(data?.orderId) !== orderId) throw new Error('瑞幸订单返回编号不一致');
      const status = { 10: 'awaiting_payment', 20: 'accepted', 30: 'preparing', 60: 'ready', 80: 'completed', 100: 'cancelled' }[data.orderStatus] || 'processing';
      row.order = { ...row.order, status, needPay: status === 'awaiting_payment', statusText: String(data.orderStatusName || '状态更新中'), pickupCode: ['ready', 'completed', 'preparing', 'accepted'].includes(status) ? String(data.takeMealCodeInfo?.code || '') : '' };
      if (delivery && row.order.fulfilment === 'delivery') {
        try { row.order.delivery = await delivery.status(orderId); row.order.deliveryError = ''; }
        catch (error) { row.order.deliveryError = error.message; }
      }
      row.state = 'confirmed';
      journal.save(); return row.order;
    },
    async deliveryPreview({ orderId } = {}) {
      const order = await gateway.orderStatus(orderId);
      if (!delivery || order.fulfilment !== 'delivery') throw new Error('本单未选择闪送配送');
      if (order.needPay || order.status !== 'ready' || !order.pickupCode) throw new Error('请先完成咖啡付款，等待出餐和官方取餐码后呼叫闪送');
      if (order.delivery) throw new Error('本单已有闪送记录，请查看配送状态，勿重复发单');
      return delivery.quote({ coffeeOrderId: orderId, store: { name: order.storeName, address: order.address }, recipient: order.recipient, productName: order.productName, pickupCode: order.pickupCode });
    },
    async deliveryCreate(input = {}) {
      const order = await gateway.orderStatus(input.orderId);
      if (!delivery || order.fulfilment !== 'delivery' || order.needPay || order.status !== 'ready' || !order.pickupCode) throw new Error('咖啡未出餐或取餐码尚未生成，不能发配送单');
      const result = await delivery.create({ ...input, coffeeOrderId: order.orderId, pickupCode: order.pickupCode });
      const row = journal.rows.find((r) => r.order?.orderId === order.orderId);
      row.order.delivery = result; journal.save(); return row.order;
    },
    async deliveryRecover(input = {}) {
      const row = journal.rows.find((r) => r.order?.orderId === input.orderId);
      if (!delivery || row?.order?.fulfilment !== 'delivery') throw new Error('请从本机配送订单记录核实');
      row.order.delivery = await delivery.recover({ coffeeOrderId: input.orderId, deliveryId: input.deliveryId });
      journal.save(); return row.order;
    },
    history: () => journal.rows.slice(-30).reverse().map((row) => ({ draftId: row.draftId, state: row.state, at: row.at, storeName: row.storeName, productName: row.productName, order: row.order })),
    resolveUnknown({ draftId, confirmedNoOrder } = {}) {
      const row = journal.rows.find((item) => item.draftId === draftId);
      if (!row || row.state === 'confirmed' || inFlight.has(draftId) || confirmedNoOrder !== true) throw new Error('请先在瑞幸 App 核实这笔订单未成功');
      row.state = 'resolved'; journal.save();
      drafts.delete(draftId);
      return true;
    },
    async recover({ draftId, orderId } = {}) {
      const row = journal.rows.find((item) => item.draftId === draftId);
      if (!row || !row.draft || row.state === 'confirmed' || inFlight.has(draftId) || typeof orderId !== 'string' || !/^\d{3,40}$/.test(orderId)) throw new Error('请输入待核实订单在瑞幸 App 中的订单号');
      const data = await client.call('queryOrderDetailInfo', { orderId });
      const products = data?.productInfoList || [];
      const matches = products.some((p) => p.productId === row.draft.productId && p.skuCode === row.draft.skuCode)
        || (data?.orderCommodityList || []).some((p) => p.commodityId === row.draft.productId);
      if (String(data?.orderId) !== orderId || data.shopInfo?.deptId !== row.draft.storeId || !matches) throw new Error('该瑞幸订单与待核实门店/商品不符，请检查订单号');
      row.order = {
        orderId, storeName: row.draft.storeName, address: row.draft.address, productName: row.draft.productName,
        fulfilment: row.draft.fulfilment || 'pickup', recipient: row.draft.recipient,
        specification: row.draft.specification, priceCents: cents(data.orderPayAmount), payUrl: '', qrUrl: '',
      };
      row.state = 'confirmed'; journal.save();
      return gateway.orderStatus(orderId);
    },
    canOpenPayment(url) { return Boolean(paymentUrl(url) && journal.rows.some((row) => row.order?.needPay && [row.order.payUrl, row.order.qrUrl].includes(url))); },
  };
  return gateway;
}
module.exports = { createLuckinClient, createLuckinGateway, paymentUrl };
