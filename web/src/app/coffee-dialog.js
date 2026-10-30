import { toast } from '../ui/toast.js';
import { createLuckinDialog } from './luckin-dialog.js';
const $ = (s) => document.querySelector(s);
const money = (cents) => (cents / 100).toFixed(2);

export function bindCoffeeDialog(app) {
  const dialog = $('#coffee-dialog'), list = $('#coffee-stores'), status = $('#coffee-status');
  let loading = false, loaded = false;
  let orderPoll;
  let provider;
  const luckin = window.neuroDesktop ? createLuckinDialog(app, { dialog, list, status }) : null;
  const render = ({ stores, sample, demo, merchant }) => {
    list.replaceChildren();
    $('#coffee-sample').hidden = !sample && !demo;
    $('#coffee-sample').textContent = sample ? '示例预览' : demo ? '本机演示' : merchant ? '商户服务' : '商户服务';
    status.textContent = sample ? '服务尚未接入 · 以下为界面示例，位置、门店和价格均为示例' : demo ? '本机演示服务 · 门店、取餐码和进度均为模拟，不会扣款' : stores.length ? '企业餐补直付 · 园区无人车配送到工位 · 点击即提交一杯' : '附近暂无可下单门店，请稍后重试';
    for (const [index, store] of stores.entries()) {
      const card = document.createElement('article'); card.className = 'coffee-store';
      const header = document.createElement('header');
      const name = document.createElement('h3'); name.textContent = store.name;
      const distance = document.createElement('span'); distance.textContent = `${index === 0 ? '最近 · ' : ''}${store.distanceMeters < 1000 ? `${store.distanceMeters} m` : `${(store.distanceMeters / 1000).toFixed(1)} km`}${sample ? '（示例）' : ''}`;
      header.append(name, distance);
      const address = document.createElement('p'); address.textContent = store.address;
      card.append(header, address);
      for (const product of store.products) {
        const row = document.createElement('div'); row.className = 'coffee-product';
        const cup = document.createElement('span'); cup.className = 'product-art'; cup.textContent = '☕';
        const text = document.createElement('div');
        const title = document.createElement('b'); title.textContent = product.name;
        const info = document.createElement('small'); info.textContent = `企业餐补直付 · 标准杯 · 1 杯`; text.append(title, info);
        const button = document.createElement('button'); button.className = 'btn primary sm';
        button.textContent = sample ? `¥${money(product.priceCents)} · 待接入` : `¥${money(product.priceCents)} · 立即下单`;
        button.disabled = sample;
        button.addEventListener('click', async () => {
          if (app.coffee.busy) return;
          const buttons = [...list.querySelectorAll('button')]; buttons.forEach((b) => { b.disabled = true; });
          button.textContent = '正在提交…';
          status.textContent = '正在向门店提交订单，请稍候';
          try {
            const order = await app.coffee.submit(store, product);
            if (!order) return;
            const showProgress = (progress) => {
              status.textContent = `${demo ? '【本机演示】' : ''}${progress.statusText}（${progress.step}/${progress.totalSteps}）· ${order.productName} · 订单 ${order.orderId}${progress.pickupCode ? ` · 取餐码 ${progress.pickupCode}` : ''}`;
            };
            showProgress({ ...order, statusText: order.status === 'paid' ? '已支付' : '门店已接单', step: 1, totalSteps: 4 });
            app.log.add(`${demo ? '本机演示 · ' : ''}${order.storeName} · ${order.productName} · 订单 ${order.orderId}`, { tag: '咖啡', color: '#528068' });
            button.textContent = '已下单 ✓';
            loaded = false;
            clearInterval(orderPoll);
            orderPoll = setInterval(async () => {
              try {
                const progress = await window.neuroDesktop.orderStatus(order.orderId);
                showProgress(progress);
                if (['ready', 'completed', 'cancelled'].includes(progress.status)) clearInterval(orderPoll);
              } catch (error) { clearInterval(orderPoll); status.textContent = `${order.orderId} 已提交，进度查询失败：${error.message}`; }
            }, 2000);
          } catch (error) {
            status.textContent = `${error.message}。若提交超时，请查看平台订单或点击原商品重试。`;
            button.textContent = '重试此订单'; button.disabled = false;
          }
        });
        row.append(cup, text, button); card.append(row);
      }
      list.append(card);
    }
  };
  const load = async () => {
    if (loading || app.coffee.busy) return;
    loading = true; $('#coffee-refresh').disabled = true;
    status.textContent = '正在查找附近的咖啡…';
    try {
      const config = window.neuroDesktop ? await window.neuroDesktop.coffeeConfig() : { configured: false, demo: false };
      provider = config.provider;
      if (provider === 'luckin') {
        if (!config.configured) throw new Error('尚未配置瑞幸授权，请更新本机 Token。');
        luckin.open(await window.neuroDesktop.deliveryConfig?.()); loaded = false; return;
      }
      let coords;
      if (config.configured && !config.demo) {
        if (config.location) {
          // The park gateway is venue-specific; real merchant adapters keep using system geolocation.
          coords = config.location;
        } else {
          status.textContent = '正在获取你的位置…';
          coords = await new Promise((resolve, reject) => navigator.geolocation.getCurrentPosition((p) => resolve({ latitude: p.coords.latitude, longitude: p.coords.longitude }), () => reject(new Error('无法获取位置，请开启系统定位权限后重试')), { timeout: 15000, maximumAge: 300000 }));
        }
      } else if (config.configured) coords = { latitude: 0, longitude: 0 };
      render(await app.coffee.nearby(coords)); loaded = true;
    } catch (error) { list.replaceChildren(); status.textContent = error.message; }
    finally { loading = false; $('#coffee-refresh').disabled = false; }
  };
  const open = () => {
    if (!dialog.open) dialog.showModal();
    if (!loaded && !app.coffee.busy) void load();
  };
  app.coffee.onOffer = open;
  $('#coffee-close').addEventListener('click', () => dialog.close());
  $('#coffee-refresh').addEventListener('click', () => {
    if (provider !== 'luckin' && app.coffee.pending) return toast('上一笔订单待确认，请先重试原商品或查看平台订单', 'warn');
    void load();
  });
  window.neuroDesktop?.onCoffee(open);
  $('#coffee-later').addEventListener('click', () => dialog.close());
}
