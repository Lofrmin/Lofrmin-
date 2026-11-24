import {readFile,writeFile,mkdir,readdir,copyFile} from 'node:fs/promises';
import {resolve,extname,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..'),assets={};
const types={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.jpg':'image/jpeg','.png':'image/png'};
async function visit(dir,prefix=''){for(const item of await readdir(dir,{withFileTypes:true})){const path=resolve(dir,item.name),url=prefix+'/'+item.name;if(item.isDirectory())await visit(path,url);else assets[url]={type:types[extname(path)]||'application/octet-stream',data:(await readFile(path)).toString('base64')}}}
await visit(resolve(root,'public'));await mkdir(resolve(root,'dist/server'),{recursive:true});await mkdir(resolve(root,'dist/.openai'),{recursive:true});
const core=(await readFile(resolve(root,'src/core.mjs'),'utf8')).replaceAll('export ','');
await writeFile(resolve(root,'dist/server/index.js'),core+'\nconst ASSETS='+JSON.stringify(assets)+';\n'+await readFile(resolve(root,'src/worker.mjs'),'utf8'));
await copyFile(resolve(root,'.openai/hosting.json'),resolve(root,'dist/.openai/hosting.json'));console.log('Worker build complete, '+Object.keys(assets).length+' assets embedded');
