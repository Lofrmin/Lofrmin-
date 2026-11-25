import {upgrade,visiblePost,domainSnapshot,domainRoute,teacherReminders} from './domain.mjs';
const uid=()=>crypto.randomUUID();
const now=()=>new Date().toISOString();
const ago=d=>new Date(Date.now()-d*86400000).toISOString();
export const day=t=>new Date(t).toLocaleDateString('en-CA',{timeZone:'Asia/Shanghai'});
const fail=(message,status=400)=>{throw Object.assign(new Error(message),{status})};
export async function passwordHash(password,salt=uid()){
 const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(password),'PBKDF2',false,['deriveBits']);
 const bits=await crypto.subtle.deriveBits({name:'PBKDF2',salt:new TextEncoder().encode(salt),iterations:100000,hash:'SHA-256'},key,256);
 return salt+':'+Array.from(new Uint8Array(bits),b=>b.toString(16).padStart(2,'0')).join('');
}
export async function seed(initialPassword){
 if(typeof initialPassword!=='string'||initialPassword.length<12)throw new Error('首次启动前请设置至少 12 位的 WEIAI_DEMO_PASSWORD 环境变量');
 const hash=await passwordHash(initialPassword);
 const users=[['staff','工作人员','staff',null],['teacher','林老师','teacher','t1'],['teacher2','陈老师','teacher','t2'],['teacher3','杨老师','teacher','t3'],['teacher4','吴老师','teacher','t4'],['donor','星光公益伙伴','donor',null],['donor2','暖阳公益伙伴','donor',null]].map(([id,name,role,teamId])=>({id,name,role,teamId,username:id,password:hash,createdAt:ago(30),teamIds:role==='donor'?(id==='donor'?['t1','t2']:['t3']):[]}));
 const teams=[['t1','山间回响团队','贵州 · 黔东南','青禾小学',128,'music'],['t2','向阳花开团队','贵州 · 毕节','向阳小学',96,'dance'],['t3','星河童声团队','贵州 · 铜仁','星河小学',86,'music'],['t4','追光少年团队','贵州 · 黔南','云山小学',112,'hero']].map(([id,name,location,school,children,photo])=>({id,name,location,school,children,photo,project:'大山里的音乐课堂',createdAt:ago(30)}));
 const checkins=[['c1','teacher','t1',0,'第一次合奏，小小的节拍也有大大的力量','今天和孩子们一起练习了节奏合奏。从不敢举手，到主动上台，看到大家的变化很开心。',28,'music'],['c2','teacher2','t2',1,'把歌声唱给大山听','和孩子们完成了一次完整的合唱排练，记录这份认真与热爱。',32,'dance'],['c3','teacher3','t3',9,'音乐课上的一束光','本周学习基础节拍，孩子们用拍手为彼此伴奏。',24,'music'],['c4','teacher4','t4',12,'在音乐里，一起向阳生长','今天开展了乐器体验课，孩子们尝试了手鼓和口风琴。',30,'hero']].map(([id,userId,teamId,d,title,text,students,photo])=>({id,userId,teamId,title,text,students,minutes:40,images:['/assets/'+photo+'.jpg'],createdAt:ago(d),consent:true,likes:[],reviewed:id==='c2'}));
 return {users,teams,checkins,posts:[{id:'p1',title:'山间有回响，每一份热爱都被听见',summary:'从第一次触碰乐器，到一起完成合奏，孩子们的音乐故事正在慢慢生长。',blocks:[{type:'text',text:'这个秋天，音乐教室又热闹了起来。老师带着孩子们从认识节拍开始，一点点找到属于自己的旋律。'},{type:'image',src:'/assets/music.jpg'},{type:'text',text:'每一次认真练习，每一个勇敢举手的瞬间，都是陪伴的意义。谢谢每一位公益伙伴，让这样的课堂持续发生。'}],teamIds:['t1','t2'],cover:'/assets/music.jpg',status:'published',createdAt:ago(2),publishedAt:ago(2),author:'staff',views:[],sourceIds:['c2']},{id:'p2',title:'让孩子们的歌声，走得更远',summary:'星河团队本月课堂回顾。',blocks:[{type:'text',text:'这是一篇仅对星河团队资助伙伴开放的演示动态。'},{type:'image',src:'/assets/dance.jpg'}],teamIds:['t3'],cover:'/assets/dance.jpg',status:'published',createdAt:ago(3),publishedAt:ago(3),author:'staff',views:[],sourceIds:[]}],invites:[],sessions:[],notifications:[{id:uid(),userId:'donor',title:'你关注的团队有新动态',text:'山间有回响，每一份热爱都被听见',postId:'p1',createdAt:ago(2),read:false}],audit:[],followups:[],settings:{reminderDays:7}};
}
function safeUser(u){const {password,...v}=u;return v}
function log(s,u,action,target){s.audit.unshift({id:uid(),actor:u.name,action,target,createdAt:now()});s.audit=s.audit.slice(0,1000)}
function canPost(u,p){return u.role==='staff'||u.role==='donor'&&p.status==='published'&&p.teamIds.some(id=>u.teamIds.includes(id))}
function reminderList(s){return s.users.filter(u=>u.role==='teacher').map(u=>{const last=s.checkins.filter(c=>c.userId===u.id).sort((a,b)=>b.createdAt.localeCompare(a.createdAt))[0];const days=Math.floor((Date.now()-Date.parse(last?.createdAt||u.createdAt))/86400000);return {...safeUser(u),lastAt:last?.createdAt,days,followups:s.followups.filter(f=>f.teacherId===u.id)}}).filter(u=>u.days>=s.settings.reminderDays)}
function snapshot(s,u){
 const domain=domainSnapshot(s,u);
 const staff=u.role==='staff',teacher=u.role==='teacher';
 const teams=s.teams.filter(t=>domain.schools.some(x=>x.id===t.id));
 return {user:safeUser(u),teams,users:staff?s.users.map(safeUser):teacher?s.users.filter(x=>x.role==='teacher').map(safeUser):[],checkins:staff||teacher?s.checkins:[],posts:s.posts.map(p=>visiblePost(s,u,p)).filter(Boolean),invites:staff?s.invites:[],notifications:s.notifications.filter(n=>n.userId===u.id&&(!n.postId||s.posts.some(p=>p.id===n.postId&&visiblePost(s,u,p)))),reminders:staff?teacherReminders(s):[],audit:staff?s.audit:[],settings:staff?s.settings:{},demo:true,...domain};
}
const string=(x,max=500)=>typeof x==='string'?x.trim().slice(0,max):'';
function idsValid(s,ids){return Array.isArray(ids)&&ids.length>0&&ids.every(id=>s.teams.some(t=>t.id===id))}
function cleanBlocks(blocks){
 if(!Array.isArray(blocks)||blocks.length>100)fail('正文格式不正确');
 return blocks.map(b=>b.type==='image'&&/^\/(assets|media)\/[a-zA-Z0-9._-]+$/.test(b.src)?{type:'image',src:b.src}:['text','heading','quote'].includes(b.type)?{type:b.type,text:string(b.text,15000)}:null).filter(Boolean);
}
export async function api(request,store,media){
 const url=new URL(request.url),path=url.pathname,method=request.method;
 if(!path.startsWith('/api/'))return null;
 const headers={'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'};
 try{
  if(!['GET','HEAD'].includes(method)&&request.headers.get('origin')&&request.headers.get('origin')!==url.origin)fail('请求来源不受信任',403);
  if(Number(request.headers.get('content-length'))>6*1024*1024)fail('文件不能超过 5MB',413);
  let body={};if(!['GET','HEAD'].includes(method)){const raw=await request.text();if(raw.length>7*1024*1024)fail('请求过大',413);try{body=raw?JSON.parse(raw):{}}catch{fail('请求格式不正确')}}
  let extraHeaders={};
  const result=await store.update(async s=>{
   upgrade(s);s.sessions=s.sessions.filter(x=>x.expires>Date.now());
   const token=(request.headers.get('cookie')||'').match(/(?:^|;\s*)weiai_session=([^;]+)/)?.[1];
   const session=s.sessions.find(x=>x.token===token),u=s.users.find(x=>x.id===session?.userId);
   const requireRole=(...roles)=>{if(!u)fail('请先登录',401);if(!roles.includes(u.role))fail('没有操作权限',403)};
   if(path==='/api/login'&&method==='POST'){
    const user=s.users.find(x=>x.username===body.username);
    if(!user||await passwordHash(String(body.password),user.password.split(':')[0])!==user.password)fail('账号或密码不正确',401);
    const t=uid()+uid();s.sessions.push({token:t,userId:user.id,expires:Date.now()+86400000});
    extraHeaders['Set-Cookie']=`weiai_session=${t}; HttpOnly; SameSite=Strict; Path=/; Max-Age=86400${url.protocol==='https:'?'; Secure':''}`;
    return snapshot(s,user);
   }
   if(path==='/api/register'&&method==='POST'){
    const invite=s.invites.find(i=>i.code===string(body.code).toUpperCase()&&!i.usedAt&&Date.parse(i.expiresAt)>Date.now()&&!i.revoked);
    if(!invite)fail('邀请码无效、已使用或已过期');
    const username=string(body.username,32),name=string(body.name,30);
    if(!/^[a-zA-Z0-9_-]{3,32}$/.test(username)||!name)fail('请填写姓名及 3–32 位字母数字账号');
    if(s.users.some(x=>x.username===username))fail('账号已存在');
    if(typeof body.password!=='string'||body.password.length<8||body.password.length>128)fail('密码需为 8–128 位');
    const user={id:uid(),username,name,role:invite.role,teamId:invite.role==='teacher'?invite.teamIds[0]:null,teamIds:invite.role==='donor'?invite.teamIds:[],password:await passwordHash(body.password),createdAt:now()};
    s.users.push(user);if(user.role==='teacher')s.assignments.push(...s.classrooms.filter(c=>c.schoolId===user.teamId).slice(0,1).map(c=>({userId:user.id,classroomId:c.id})));else {const sp={id:'sponsor-'+user.id,name:user.name,userIds:[user.id]};s.sponsors.push(sp);s.sponsorships.push(...s.classrooms.filter(c=>user.teamIds.includes(c.schoolId)).map(c=>({id:crypto.randomUUID(),sponsorId:sp.id,classroomId:c.id,active:true,startAt:'',endAt:'',historyFrom:''})));}invite.usedAt=now();invite.usedBy=user.id;log(s,user,'使用邀请码加入',invite.code);return {ok:true};
   }
   if(!u)fail('请先登录',401);
   const domainResult=await domainRoute(s,u,path,method,body,passwordHash);if(domainResult!==undefined)return domainResult;
   if(path==='/api/state'&&method==='GET')return snapshot(s,u);
   if(path==='/api/logout'&&method==='POST'){s.sessions=s.sessions.filter(x=>x.token!==token);extraHeaders['Set-Cookie']='weiai_session=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0';return {ok:true}}
   if(path==='/api/checkins'&&method==='POST'){
    requireRole('teacher');
    const roomId=body.classroomId||s.assignments.find(a=>a.userId===u.id)?.classroomId;const classroom=s.classrooms.find(c=>c.id===roomId);if(!classroom||!s.assignments.some(a=>a.userId===u.id&&a.classroomId===roomId))fail('请选择您任教的教室',403);
    if(s.checkins.some(c=>c.userId===u.id&&(c.classroomId||'room-'+c.teamId)===roomId&&day(c.createdAt)===day(now())))fail('今天已经打卡，明天继续记录吧');
    const title=string(body.title,100),text=string(body.text,4000),images=Array.isArray(body.images)?body.images:[];
    if(!title||!text||!images.length||images.length>9||images.some(x=>!/^\/media\/[\w.-]+$/.test(x)))fail('请填写标题、课堂记录并上传 1–9 张照片');
    if(body.consent!==true)fail('请确认素材已获得使用授权');
    if(!Number.isInteger(body.students)||body.students<1||body.students>1000||!Number.isInteger(body.minutes)||body.minutes<1||body.minutes>480)fail('请填写有效的参与人数和课堂时长');
    s.checkins.unshift({id:uid(),userId:u.id,teamId:classroom.schoolId,classroomId:roomId,category:string(body.category,50)||'日常课堂',activityAt:day(now()),title,text,images,students:body.students,minutes:body.minutes,consent:true,createdAt:now(),likes:[],reviewed:false});log(s,u,'提交课堂打卡',u.teamId);return {ok:true};
   }
   if(path.match(/^\/api\/checkins\/[^/]+\/like$/)&&method==='POST'){
    requireRole('teacher','staff');const c=s.checkins.find(c=>c.id===path.split('/')[3]);if(!c)fail('打卡不存在',404);c.likes=c.likes.includes(u.id)?c.likes.filter(id=>id!==u.id):[...c.likes,u.id];return {ok:true};
   }
   if(path==='/api/posts'&&method==='POST'){
    requireRole('staff');if(!idsValid(s,body.teamIds))fail('请选择关联团队');
    const title=string(body.title,100),blocks=cleanBlocks(body.blocks);if(!title||!blocks.some(b=>b.text||b.src))fail('请填写标题和正文');
    const existing=body.id?s.posts.find(x=>x.id===body.id):null;if(body.id&&!existing)fail('动态不存在',404);if(existing?.status==='published')fail('请先撤回已发布动态再修改');
    const post={id:existing?.id||uid(),title,summary:string(body.summary,300),blocks,teamIds:[...new Set(body.teamIds)],cover:blocks.find(b=>b.type==='image')?.src||'/assets/music.jpg',status:'draft',createdAt:existing?.createdAt||now(),author:u.id,views:[],sourceIds:Array.isArray(body.sourceIds)?body.sourceIds.filter(id=>s.checkins.some(c=>c.id===id)):[]};
    if(existing)Object.assign(existing,post);else s.posts.unshift(post);log(s,u,'保存图文草稿',post.title);return {ok:true,id:post.id};
   }
   if(path.match(/^\/api\/posts\/[^/]+\/(publish|withdraw|view)$/)&&method==='POST'){
    const [, , ,id,action]=path.split('/'),p=s.posts.find(x=>x.id===id);if(!p)fail('动态不存在',404);
    if(action==='view'){if(!canPost(u,p))fail('没有查看权限',403);if(!p.views.includes(u.id))p.views.push(u.id);return {ok:true}}
    requireRole('staff');
    if(action==='withdraw'){p.status='draft';log(s,u,'撤回动态',p.title);return {ok:true}}
    if(p.status==='published')return {ok:true};
    if(body.reviewed!==true)fail('请确认已完成人工审核');
    p.status='published';p.publishedAt=now();p.teamIds.forEach(team=>s.users.filter(x=>x.role==='donor'&&x.teamIds.includes(team)).forEach(d=>{if(!s.notifications.some(n=>n.postId===p.id&&n.userId===d.id))s.notifications.unshift({id:uid(),userId:d.id,title:'你关注的团队有新动态',text:p.title,postId:p.id,createdAt:now(),read:false})}));
    p.sourceIds.forEach(id=>{const c=s.checkins.find(c=>c.id===id);if(c)c.reviewed=true});log(s,u,'审核发布并定向通知',p.title);return {ok:true};
   }
   if(path==='/api/invites'&&method==='POST'){
    requireRole('staff');if(!['teacher','donor'].includes(body.role)||!idsValid(s,body.teamIds)||body.role==='teacher'&&body.teamIds.length!==1)fail('请选择角色及对应团队');
    if(body.role==='teacher'&&!s.classrooms.some(c=>c.schoolId===body.teamIds[0]))fail('请先为该学校添加教室，再邀请老师');
    const code=uid().replaceAll('-','').slice(0,12).toUpperCase();s.invites.unshift({id:uid(),code,role:body.role,teamIds:body.teamIds,createdAt:now(),expiresAt:new Date(Date.now()+7*86400000).toISOString(),usedAt:null});log(s,u,'创建邀请码',code);return {ok:true,code};
   }
   if(path.match(/^\/api\/invites\/[^/]+\/revoke$/)&&method==='POST'){requireRole('staff');const i=s.invites.find(x=>x.id===path.split('/')[3]);if(!i)fail('邀请码不存在',404);i.revoked=true;log(s,u,'撤销邀请码',i.code);return {ok:true}}
   if(path==='/api/settings'&&method==='POST'){requireRole('staff');if(!Number.isInteger(body.reminderDays)||body.reminderDays<1||body.reminderDays>90)fail('提醒周期应为 1–90 天');s.settings.reminderDays=body.reminderDays;log(s,u,'更新未打卡提醒周期',body.reminderDays+' 天');return {ok:true}}
   if(path==='/api/followups'&&method==='POST'){
    requireRole('staff');const teacher=s.users.find(x=>x.id===body.teacherId&&x.role==='teacher');const note=string(body.note,1000);if(!teacher||!note)fail('请填写跟进记录');
    s.followups.unshift({id:uid(),teacherId:teacher.id,note,createdAt:now(),actor:u.name});s.notifications.unshift({id:uid(),userId:teacher.id,title:'课堂记录温馨提醒',text:note,createdAt:now(),read:false});log(s,u,'记录打卡跟进并发送站内提醒',teacher.name);return {ok:true};
   }
   if(path==='/api/notifications/read'&&method==='POST'){s.notifications.filter(n=>n.userId===u.id).forEach(n=>n.read=true);return {ok:true}}
   if(path==='/api/teams'&&method==='POST'){
    requireRole('staff');const name=string(body.name,40),school=string(body.school,60),location=string(body.location,60);if(!name||!school||!location)fail('请完整填写团队资料');const t={id:uid(),name,school,location,children:0,photo:'music',project:'大山里的音乐课堂',createdAt:now()};s.teams.push(t);log(s,u,'新建团队',name);return {ok:true};
   }
   if(path==='/api/membership'&&method==='POST'){
    requireRole('staff');const target=s.users.find(x=>x.id===body.userId&&x.role!=='staff');if(!target||!idsValid(s,body.teamIds))fail('成员或团队无效');if(target.role==='teacher'&&body.teamIds.length!==1)fail('老师需关联一个团队');if(target.role==='teacher')target.teamId=body.teamIds[0];else target.teamIds=body.teamIds;log(s,u,'更新成员团队关系',target.name);return {ok:true};
   }
   if(path==='/api/upload'&&method==='POST'){
    requireRole('teacher','staff');const data=body.data;if(typeof data!=='string'||data.length>7*1024*1024)fail('图片不能超过 5MB');
    const match=data.match(/^data:image\/(jpeg|png|webp);base64,([A-Za-z0-9+/=]+)$/);if(!match)fail('仅支持 JPG、PNG、WebP 图片');
    const bytes=Uint8Array.from(atob(match[2]),c=>c.charCodeAt(0));if(bytes.length>5*1024*1024)fail('图片不能超过 5MB');
    const valid=match[1]==='jpeg'?bytes[0]===255&&bytes[1]===216:match[1]==='png'?bytes[0]===137&&bytes[1]===80&&bytes[2]===78&&bytes[3]===71:String.fromCharCode(...bytes.slice(0,4))==='RIFF'&&String.fromCharCode(...bytes.slice(8,12))==='WEBP';if(!valid)fail('图片文件内容不正确');
    const id=uid()+'.'+match[1];await media.put(id,bytes,'image/'+match[1]);return {url:'/media/'+id};
   }
   fail('接口不存在',404);
  });
  return new Response(JSON.stringify(result),{headers:{...headers,...extraHeaders}});
 }catch(e){return new Response(JSON.stringify({error:e.status?e.message:'服务暂时不可用，请稍后重试'}),{status:e.status||500,headers})}
}
export async function authorizeMedia(request,store,id){
 const s=upgrade(await store.read()),token=(request.headers.get('cookie')||'').match(/(?:^|;\s*)weiai_session=([^;]+)/)?.[1];
 const session=s.sessions.find(x=>x.token===token&&x.expires>Date.now()),u=s.users.find(x=>x.id===session?.userId);if(!u)return false;
 if(u.role==='staff'||u.role==='teacher')return true;
 return s.posts.map(p=>visiblePost(s,u,p)).filter(Boolean).some(p=>p.blocks.some(b=>b.src==='/media/'+id));
}
