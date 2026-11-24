// The build script places core and embedded static assets before this module.
export default {async fetch(request,env){
 const url=new URL(request.url);
 const store={async read(){let row=await env.DB.prepare('SELECT json,revision FROM app_state WHERE id=1').first();if(!row){const initial=JSON.stringify(await seed(env.WEIAI_DEMO_PASSWORD));await env.DB.prepare('INSERT OR IGNORE INTO app_state (id,json,revision) VALUES (1,?,0)').bind(initial).run();row=await env.DB.prepare('SELECT json,revision FROM app_state WHERE id=1').first()}return {...row,state:JSON.parse(row.json)}},async update(fn){for(let attempt=0;attempt<5;attempt++){const {revision,state}=await this.read();const result=await fn(state),json=JSON.stringify(state);if(new TextEncoder().encode(json).length>1500000)throw Object.assign(new Error('试用数据已达到容量，请联系管理员归档'),{status:409});const r=await env.DB.prepare('UPDATE app_state SET json=?,revision=revision+1 WHERE id=1 AND revision=?').bind(json,revision).run();if(r.meta.changes)return result}throw Object.assign(new Error('操作较多，请重试'),{status:409})}};
 const media={put:(id,bytes,type)=>env.BUCKET.put(id,bytes,{httpMetadata:{contentType:type}})};
 try{
 let response;
 if(url.pathname.startsWith('/api/'))response=await api(request,store,media);
 else if(url.pathname.startsWith('/media/')){const id=url.pathname.slice(7);const authStore={read:async()=>(await store.read()).state};if(!/^[\w.-]+$/.test(id)||!await authorizeMedia(request,authStore,id))response=new Response('Forbidden',{status:403});else{const object=await env.BUCKET.get(id);response=object?new Response(object.body,{headers:{'Content-Type':object.httpMetadata.contentType,'Cache-Control':'private, no-store'}}):new Response('Not found',{status:404})}}
 else {const asset=ASSETS[url.pathname==='/'?'/index.html':url.pathname];response=asset?new Response(Uint8Array.from(atob(asset.data),c=>c.charCodeAt(0)),{headers:{'Content-Type':asset.type,'Cache-Control':'no-cache'}}):new Response('Not found',{status:404})}
 const headers=new Headers(response.headers);headers.set('X-Content-Type-Options','nosniff');headers.set('Referrer-Policy','same-origin');headers.set('Content-Security-Policy',"default-src 'self'; img-src 'self' data: blob:; style-src 'self' 'unsafe-inline'; script-src 'self'; connect-src 'self'; frame-ancestors 'self'");return new Response(response.body,{status:response.status,headers});
 }catch(e){console.error(e);return Response.json({error:'服务暂时不可用，请稍后重试'},{status:503})}
}};
