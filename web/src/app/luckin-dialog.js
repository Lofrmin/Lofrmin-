const money = (cents) => `¥${(cents / 100).toFixed(2)}`;
const node = (tag, text = '', className = '') => {
  const element = document.createElement(tag); element.textContent = text; element.className = className; return element;
};

export function createLuckinDialog(app, { dialog, list, status }) {
  const bridge = window.neuroDesktop;
  let working = false, timer = 0, coords = null, store = null, selected = null, activeOrder = null;
  let fulfilment = 'pickup', recipient = {}, deliveryConfig = { configured: false, message: '闪送尚未开通' };
  const stop = () => { clearTimeout(timer); timer = 0; };
  dialog.addEventListener('close', stop);
  function clear(message) { stop(); list.replaceChildren(); status.textContent = message; }
  async function action(task) {
    if (working) return;
    working = true;
    const buttons = [...list.querySelectorAll('button:not(:disabled)')];
    buttons.forEach((button) => { button.disabled = true; });
    document.querySelector('#coffee-refresh').disabled = true;
    try { await task(); }
    catch (error) { status.textContent = error.message; }
    finally {
      buttons.filter((button) => button.isConnected).forEach((button) => { button.disabled = false; });
      document.querySelector('#coffee-refresh').disabled = false;
      working = false;
    }
  }
  function button(text, task, parent = list, className = 'btn sm') {
    const b = node('button', text, className); b.type = 'button'; b.addEventListener('click', () => void action(task)); parent.append(b); return b;
  }
  function field(label, placeholder, parent, type = 'text') {
    const wrap = node('label', label, 'luckin-field');
    const input = document.createElement('input'); input.type = type; input.placeholder = placeholder;
    wrap.append(input); parent.append(wrap); return input;
  }
  function card(title, detail) {
    const box = node('article', '', 'coffee-store'); box.append(node('h3', title));
    if (detail) box.append(node('p', detail)); list.append(box); return box;
  }
  async function history() {
    clear('本机瑞幸订单记录 · 实际状态以瑞幸返回为准');
    button('返回选店', location);
    const rows = await bridge.luckinHistory();
    if (!rows.length) list.append(node('p', '还没有通过本机创建的瑞幸订单。', 'note'));
    for (const row of rows) {
      const box = card(`${row.storeName} · ${row.productName}`, new Date(row.at).toLocaleString());
      if (row.order) button(`${row.order.statusText} · ${row.order.orderId} · 查看`, async () => showOrder(await bridge.orderStatus(row.order.orderId)), box);
      else if (['submitting', 'unknown'].includes(row.state)) {
        box.append(node('p', '提交结果待核实，请到瑞幸 App 查看订单。核实前平台暂停新订单。'));
        const orderId = field('若已成功，填写瑞幸订单号', '瑞幸 App 中的完整订单号', box);
        button('关联已成功的瑞幸订单', async () => showOrder(await bridge.luckinRecover({ draftId: row.draftId, orderId: orderId.value.trim() })), box);
        const label = node('label', '', 'luckin-ack'); const check = document.createElement('input'); check.type = 'checkbox';
        label.append(check, document.createTextNode('我已在瑞幸 App 核实：这笔订单没有创建成功')); box.append(label);
        const resolve = button('确认核实，解除待确认状态', async () => {
          await bridge.luckinResolve({ draftId: row.draftId, confirmedNoOrder: check.checked }); await history();
        }, box); resolve.disabled = true;
        check.addEventListener('change', () => { resolve.disabled = !check.checked; });
      } else box.append(node('p', '已由本人核实未下单。'));
    }
  }
  function location() {
    activeOrder = null;
    clear('瑞幸真实点单 · 支持自取 / 闪送取餐配送 · 先选门店');
    list.append(node('p', '点击“使用当前位置查门店”后，系统会定位并将经纬度发送给瑞幸，用于查询附近门店。', 'note'));
    const box = node('div', '', 'luckin-location'); list.append(box);
    const name = field('门店名称（可选）', '例如：科技园', box); name.id = 'luckin-store-name';
    button('使用当前位置查门店', async () => {
      status.textContent = '正在获取当前位置，请允许系统定位…';
      const position = bridge.locate ? { coords: await bridge.locate() } : await new Promise((resolve, reject) => navigator.geolocation.getCurrentPosition(resolve, (error) => reject(new Error(
        error.code === 1 ? '定位未获授权。请在 Windows 设置中开启位置服务，或手动填写坐标。' : '暂时无法定位。请检查 Windows 位置服务，或手动填写坐标。'
      )), { timeout: 15000, maximumAge: 60000, enableHighAccuracy: true }));
      coords = { latitude: position.coords.latitude, longitude: position.coords.longitude };
      await queryStores(name.value);
    }, box, 'btn primary sm').id = 'luckin-locate';
    if (bridge.locationSettings) button('打开 Windows 位置设置', () => bridge.locationSettings(), box);
    const manual = document.createElement('details'); manual.append(node('summary', '定位不可用？手动填写位置')); box.append(manual);
    const longitude = field('经度', '例如 104.12', manual, 'number'); longitude.step = 'any'; longitude.id = 'luckin-longitude';
    const latitude = field('纬度', '例如 30.58', manual, 'number'); latitude.step = 'any'; latitude.id = 'luckin-latitude';
    button('用此位置查询瑞幸门店', async () => {
      if (!longitude.value || !latitude.value) throw new Error('请填写经度和纬度');
      coords = { longitude: Number(longitude.value), latitude: Number(latitude.value) }; await queryStores(name.value);
    }, manual).id = 'luckin-manual-search';
    button('查看本机瑞幸订单', history, box).id = 'luckin-history';
  }
  async function queryStores(name = '') {
    status.textContent = '正在向瑞幸查询附近真实门店…';
    const result = await bridge.nearby({ ...coords, name });
    clear(result.stores.length ? '请选择自取门店，距离和营业时间来自瑞幸。' : '当前位置未返回可用门店，请更换位置或门店名称。');
    button('更换位置 / 查看订单', location);
    for (const s of result.stores) {
      const box = card(s.name, `${s.address} · ${s.hours}${s.distanceMeters === null ? '' : ` · ${(s.distanceMeters / 1000).toFixed(2)} km`}`);
      button('选择这家门店', async () => { store = s; await products(); }, box, 'btn primary sm');
    }
  }
  async function products(query = '咖啡') {
    status.textContent = `正在查询 ${store.name} 的饮品…`;
    const result = await bridge.luckinProducts({ storeId: store.id, query });
    clear(`${store.name} · 展示瑞幸预估价，实际应付以订单预览为准。`);
    button('返回门店', () => queryStores());
    const form = node('form', '', 'luckin-search'); list.append(form);
    const input = field('饮品搜索', '例如：生椰拿铁 / 冰美式', form); input.value = query; input.id = 'luckin-query';
    button('搜索饮品', () => products(input.value), form).id = 'luckin-search';
    form.addEventListener('submit', (event) => { event.preventDefault(); void action(() => products(input.value)); });
    if (!result.products.length) list.append(node('p', '没有找到可选饮品，请换个名称搜索。', 'note'));
    for (const product of result.products) {
      const box = card(product.name, `预估 ${money(product.priceCents)} · 1 杯`);
      button('选规格', async () => {
        selected = await bridge.luckinDetail({ storeId: store.id, productId: product.id }); specification();
      }, box, 'btn primary sm');
    }
  }
  function specification() {
    clear(`${store.name} · ${selected.name} · 预估 ${money(selected.priceCents)}`);
    button('返回饮品', () => products());
    const box = card(selected.name, '每次一杯 · 规格与库存由瑞幸实时返回');
    for (const group of selected.attrs) {
      const wrap = node('fieldset', '', 'luckin-attrs'); wrap.append(node('legend', group.name)); box.append(wrap);
      for (const option of group.options) {
        const b = button(`${option.selected ? '✓ ' : ''}${option.name}`, async () => {
          status.textContent = '正在更新规格…';
          selected = await bridge.luckinSwitch({ selectionId: selected.selectionId, groupId: group.id, optionId: option.id }); specification();
        }, wrap, `btn xs${option.selected ? ' on' : ''}`);
        b.disabled = !option.enabled || option.selected;
      }
    }
    const method = node('fieldset', '', 'luckin-attrs'); method.append(node('legend', '取餐方式')); box.append(method);
    button(`${fulfilment === 'pickup' ? '✓ ' : ''}到店自取`, () => { fulfilment = 'pickup'; specification(); }, method, `btn sm${fulfilment === 'pickup' ? ' on' : ''}`).id = 'luckin-pickup';
    button(`${fulfilment === 'delivery' ? '✓ ' : ''}闪送配送到地址`, () => { fulfilment = 'delivery'; specification(); }, method, `btn sm${fulfilment === 'delivery' ? ' on' : ''}`).id = 'luckin-delivery';
    if (fulfilment === 'delivery') {
      box.append(node('p', deliveryConfig.message, 'note'));
      const form = node('div', '', 'luckin-location'); box.append(form);
      for (const [key, label, placeholder, type] of [
        ['name', '收货人', '姓名', 'text'], ['mobile', '联系手机号', '收货及骑手取餐联系手机号', 'tel'],
        ['city', '配送城市（与门店同城）', '例如：成都市', 'text'], ['addr', '收货地址', '区县、街道、小区 / 大厦', 'text'],
        ['addrDetail', '楼栋门牌 / 工位', '例如：3栋2单元801室 / A座8楼前台', 'text'],
      ]) {
        const input = field(label, placeholder, form, type); input.id = `luckin-recipient-${key}`; input.value = recipient[key] || '';
        input.maxLength = { name: 40, mobile: 11, city: 40, addr: 200, addrDetail: 100 }[key];
        input.addEventListener('input', () => { recipient[key] = input.value; });
      }
      box.append(node('p', '报价时会将门店和收货地址、姓名、电话发送给闪送以校验服务范围。出餐后再确认呼叫，配送费单独从已配置的闪送商户余额扣除。', 'note'));
    }
    const preview = button('查看实际报价', async () => {
      status.textContent = '正在获取瑞幸实时报价与优惠…';
      quotation(await bridge.luckinPreview({ selectionId: selected.selectionId, fulfilment, ...(fulfilment === 'delivery' ? { recipient } : {}) }));
    }, box, 'btn primary sm'); preview.id = 'luckin-preview';
    preview.disabled = fulfilment === 'delivery' && !deliveryConfig.configured;
  }
  function addressText(r) { return `${r.city} ${r.addr} ${r.addrDetail} · ${r.name} ${r.mobile}`; }
  function quotation(draft) {
    clear('请确认以下门店、规格和金额。点击确认会创建真实瑞幸订单。');
    const box = card('确认瑞幸订单', `${draft.storeName} · ${draft.address}`);
    box.append(node('p', `${draft.productName} · ${draft.specification || '官方默认规格'} · ${draft.amount} 杯`));
    box.append(node('strong', `实际应付 ${money(draft.priceCents)}`, 'luckin-total'));
    box.append(node('p', `${draft.fulfilment === 'delivery' ? '闪送取餐配送' : '到店自取'}${draft.couponCodeList.length ? ' · 已计入瑞幸匹配的优惠券' : ''} · 咖啡报价有效期 5 分钟`));
    if (draft.fulfilment === 'delivery') {
      box.append(node('p', `送至：${addressText(draft.recipient)}`));
      box.append(node('p', `闪送预计 ${money(draft.deliveryQuote.feeCents)} · 合计预计 ${money(draft.priceCents + draft.deliveryQuote.feeCents)}`));
      box.append(node('p', '本次确认仅创建咖啡订单。付款并出餐后，重新查询配送费并确认呼叫闪送；发单时按闪送计费从商户余额扣费。尚未安排骑手。', 'note'));
    }
    button('修改规格', specification, box);
    button(`确认下单 · ${money(draft.priceCents)}`, async () => {
      if (app.coffee.busy) return;
      app.coffee.busy = true; status.textContent = '正在创建真实瑞幸订单，请等待结果…';
      try {
        const order = await bridge.order({ draftId: draft.draftId, priceCents: draft.priceCents, confirmed: true });
        app.coffee.order = { ...order, provider: 'luckin', done: true }; app.coffee.emit();
        app.log.add(`瑞幸 · ${order.storeName} · ${order.productName} · ${order.statusText} · 订单 ${order.orderId}`, { tag: '咖啡', color: '#528068' });
        showOrder(order);
      } catch (error) {
        await history(); status.textContent = error.message;
        button('重新选择商品和报价', () => products());
      } finally { app.coffee.busy = false; }
    }, box, 'btn primary sm').id = 'luckin-confirm';
  }
  function showOrder(order) {
    activeOrder = order;
    app.coffee.order = { ...order, provider: 'luckin', done: true }; app.coffee.emit();
    clear(`瑞幸订单 ${order.orderId} · ${order.statusText}${order.delivery ? ` · ${order.delivery.statusText}` : ''}`);
    const box = card(order.storeName, order.address);
    box.append(node('p', `${order.productName} · ${order.specification || ''} · ${money(order.priceCents)}`));
    box.append(node('strong', order.pickupCode ? `取餐码 ${order.pickupCode}` : order.statusText, 'luckin-total'));
    if (order.needPay) {
      box.append(node('p', '请使用微信扫描瑞幸返回的支付二维码。付款结果由瑞幸确认。'));
      if (order.qrUrl.startsWith('https:')) {
        const image = document.createElement('img'); image.src = order.qrUrl; image.alt = '瑞幸官方支付二维码'; image.className = 'luckin-qr'; image.referrerPolicy = 'no-referrer';
        image.addEventListener('error', () => { image.hidden = true; }); box.append(image);
      }
      if (order.payUrl) button('打开官方支付链接', () => bridge.luckinPayment(order.payUrl), box, 'btn primary sm');
      if (order.qrUrl) button('打开官方支付二维码', () => bridge.luckinPayment(order.qrUrl), box);
      if (!order.payUrl && !order.qrUrl) box.append(node('p', '接口未返回可用支付链接，请在瑞幸 App 中完成支付。'));
    }
    if (order.fulfilment === 'delivery') {
      box.append(node('p', `送至：${addressText(order.recipient)}`));
      if (order.delivery) {
        const d = order.delivery;
        box.append(node('strong', d.statusText, 'luckin-total'));
        box.append(node('p', `闪送商户单号 ${d.orderNo}${d.deliveryId ? ` · 配送单号 ${d.deliveryId}` : ''}`));
        if (d.courier) box.append(node('p', `骑手 ${d.courierName} · ${d.courier}`));
        if (d.state !== 'confirmed') {
          box.append(node('p', '请在闪送商户平台按商户单号核实。若已成功，关联配送单号；若失败，请联系平台客服处理，本机不会自动重发。'));
          const id = field('已成功的闪送配送单号', '从商户平台复制', box); id.id = 'luckin-delivery-recover-id';
          button('核实并关联闪送单', async () => showOrder(await bridge.deliveryRecover({ orderId: order.orderId, deliveryId: id.value.trim() })), box);
        }
      } else if (order.status === 'ready' && order.pickupCode && !order.needPay) {
        button('查询配送费并呼叫闪送', async () => deliveryQuotation(order, await bridge.deliveryPreview({ orderId: order.orderId })), box, 'btn primary sm').id = 'luckin-delivery-quote';
      } else box.append(node('p', order.status === 'cancelled' ? '咖啡已取消，未呼叫闪送。' : order.status === 'completed' ? '咖啡订单已完成，未新发配送单，请核实取餐情况。' : '尚未呼叫骑手。请先付款，等待出餐和取餐码后在此确认呼叫闪送。', 'note'));
      if (order.deliveryError) box.append(node('p', `配送查询失败：${order.deliveryError}。请刷新或到闪送商户平台核实。`, 'note'));
    }
    const refresh = async () => showOrder(await bridge.orderStatus(order.orderId));
    button('刷新支付 / 取餐 / 配送状态', refresh, box).id = 'luckin-status-refresh';
    button('本机订单记录', history, box);
    button('再选一杯', location, box);
    if (dialog.open && (!['completed', 'cancelled', 'ready'].includes(order.status) || (order.delivery?.state === 'confirmed' && !['completed', 'cancelled'].includes(order.delivery.status)))) {
      timer = setTimeout(() => {
        if (!working && dialog.open) void action(refresh);
      }, 5000);
    }
  }
  function deliveryQuotation(order, quote) {
    clear('确认配送地址和闪送费用；呼叫后会创建真实配送单并从商户余额扣费。');
    const box = card('确认呼叫闪送', `取餐：${order.storeName} · ${order.address} · 取餐码 ${order.pickupCode}`);
    box.append(node('p', `送至：${addressText(quote.recipient)}`));
    box.append(node('strong', `配送预计 ${money(quote.feeCents)}`, 'luckin-total'));
    box.append(node('p', '报价有效期 2 分钟，发单前再次核价。闪送接口按发单时价格计费，最终扣费以闪送商户账单为准。咖啡费用已另行支付。', 'note'));
    const label = node('label', '', 'luckin-ack'); const ack = document.createElement('input'); ack.type = 'checkbox'; ack.id = 'luckin-delivery-billing';
    label.append(ack, document.createTextNode('同意将取餐码和配送信息发送给闪送，并按发单时计费从已配置的商户余额扣除配送费')); box.append(label);
    const confirm = button('确认呼叫闪送', async () => {
      try { showOrder(await bridge.deliveryCreate({ orderId: order.orderId, quoteId: quote.quoteId, feeCents: quote.feeCents, confirmed: true, acceptBilling: ack.checked })); }
      catch (error) {
        showOrder(await bridge.orderStatus(order.orderId)); status.textContent = error.message;
      }
    }, box, 'btn primary sm'); confirm.id = 'luckin-delivery-confirm'; confirm.disabled = true;
    ack.addEventListener('change', () => { confirm.disabled = !ack.checked; });
    button('暂不呼叫，返回订单', () => showOrder(order), box);
  }
  return { open(config) {
    deliveryConfig = config || deliveryConfig;
    document.querySelector('#coffee-heading').textContent = '瑞幸咖啡 · 真实点单';
    document.querySelector('#coffee-sample').hidden = false;
    document.querySelector('#coffee-sample').textContent = '瑞幸官方服务';
    document.querySelector('#coffee-refresh').textContent = '重新选择 / 刷新';
    document.querySelector('#coffee-footer-note').textContent = '咖啡按瑞幸官方页面付款；可到店自取，或出餐后另行确认呼叫闪送配送。';
    if (activeOrder) showOrder(activeOrder); else location();
  } };
}
