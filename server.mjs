import http from 'node:http';
import {DatabaseSync} from 'node:sqlite';
import {mkdir,readFile,writeFile} from 'node:fs/promises';
import {resolve,extname,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {api,seed,authorizeMedia} from './src/core.mjs';
const root=dirname(fileURLToPath(import.meta.url));
const data=resolve(root,process.env.DATA_DIR||'data');await mkdir(resolve(data,'media'),{recursive:true});
const db=new DatabaseSync(resolve(data,'weiai.sqlite'));db.exec('PRAGMA journal_mode=WAL; CREATE TABLE IF NOT EXISTS app_state (id INTEGER PRIMARY KEY, json TEXT NOT NULL)');
if(!db.prepare('SELECT id FROM app_state WHERE id=1').get())db.prepare('INSERT INTO app_state VALUES (1,?)').run(JSON.stringify(await seed(process.env.WEIAI_DEMO_PASSWORD)));
let queue=Promise.resolve();
const store={read:async()=>JSON.parse(db.prepare('SELECT json FROM app_state WHERE id=1').get().json),update(fn){const task=queue.then(async()=>{const s=await store.read();const result=await fn(s);db.prepare('UPDATE app_state SET json=? WHERE id=1').run(JSON.stringify(s));return result});queue=task.catch(()=>{});return task}};
const media={put:async(id,bytes)=>writeFile(resolve(data,'media',id),bytes)};
const types={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.svg':'image/svg+xml','.jpg':'image/jpeg','.jpeg':'image/jpeg','.png':'image/png','.webp':'image/webp'};
const server=http.createServer(async(req,res)=>{
 try{
  const origin='http://'+req.headers.host,url=new URL(req.url,origin);let chunks=[],size=0;for await(const chunk of req){size+=chunk.length;if(size>7*1024*1024){res.writeHead(413);res.end();return}chunks.push(chunk)}
  const request=new Request(url,{method:req.method,headers:req.headers,...(!['GET','HEAD'].includes(req.method)?{body:Buffer.concat(chunks)}:{})});
  let response=await api(request,store,media);
  if(!response){let path=decodeURIComponent(url.pathname);let file;
   if(path.startsWith('/media/')){const id=path.slice(7);if(!/^[\w.-]+$/.test(id)||!await authorizeMedia(request,store,id)){response=new Response('Forbidden',{status:403})}else file=resolve(data,'media',id)}
   else file=resolve(root,'public',path==='/'?'index.html':'.'+path);
   if(!response){if(!file.startsWith(resolve(root,'public')+'/')&&!file.startsWith(resolve(root,'public')+'\\')&&!path.startsWith('/media/')){response=new Response('Forbidden',{status:403})}else try{response=new Response(await readFile(file),{headers:{'Content-Type':types[extname(file)]||'application/octet-stream','Cache-Control':path.startsWith('/media/')?'private, no-store':'no-cache'}})}catch{response=new Response('Not found',{status:404})}}
  }
  res.writeHead(response.status,Object.assign(Object.fromEntries(response.headers),{'X-Content-Type-Options':'nosniff','Referrer-Policy':'same-origin','Content-Security-Policy':"default-src 'self'; img-src 'self' data: blob:; style-src 'self' 'unsafe-inline'; script-src 'self'; connect-src 'self'; frame-ancestors 'self'"}));res.end(Buffer.from(await response.arrayBuffer()));
 }catch(e){console.error(e);res.writeHead(500);res.end('Server error')}
});
server.listen(Number(process.env.PORT||3000),'127.0.0.1',()=>console.log('Local: http://localhost:'+(process.env.PORT||3000)));
