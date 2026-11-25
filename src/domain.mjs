const vId=()=>crypto.randomUUID(),vNow=()=>new Date().toISOString();
const vText=(v,n=200)=>typeof v==='string'?v.trim().slice(0,n):'';
function vFail(message,status=400){throw Object.assign(new Error(message),{status})}
function vLog(s,u,action,target){s.audit.unshift({id:vId(),actor:u.name,action,target,createdAt:vNow()})}
export function upgrade(s){
 if(s.schemaVersion===2)return s;
 s.projects=[{id:'music',name:'大山里的音乐课堂'}];
 s.schools=s.teams.map(t=>({id:t.id,name:t.school,region:t.location,projectId:'music',children:t.children,photo:t.photo,createdAt:t.createdAt,feedbackDays:30,nextFeedbackAt:new Date(Date.now()+30*86400000).toISOString().slice(0,10),paused:false}));
 s.classrooms=s.teams.map(t=>({id:'room-'+t.id,schoolId:t.id,name:'音乐教室',type:'标准音乐教室',namingUnit:'待补充',donatedAt:'',projectId:'music'}));
 s.assignments=s.users.filter(u=>u.role==='teacher').map(u=>({userId:u.id,classroomId:'room-'+u.teamId}));
 s.sponsors=s.users.filter(u=>u.role==='donor').map(u=>({id:'sponsor-'+u.id,name:u.name,userIds:[u.id]}));
 s.sponsorships=s.sponsors.flatMap(x=>s.users.find(u=>u.id===x.userIds[0]).teamIds.map(id=>({id:vId(),sponsorId:x.id,classroomId:'room-'+id,startAt:'',endAt:'',historyFrom:'',active:true})));
 s.contacts=[];s.reviews=[];s.deliveries=[];
 s.posts.forEach(p=>{p.version=1;p.blocks=p.blocks.map(b=>({...b,schoolIds:b.schoolIds||[]}));if(p.status==='published')s.reviews.push({id:vId(),postId:p.id,version:1,actor:p.author,createdAt:p.publishedAt,legacy:true,snapshot:structuredClone(p)})});
 s.checkins.forEach(c=>{c.classroomId='room-'+c.teamId;c.category='日常课堂';c.activityAt=c.createdAt.slice(0,10)});s.schemaVersion=2;return s;
}
function activeRelations(s,u,at=vNow()){
 const sponsors=s.sponsors.filter(x=>x.userIds.includes(u.id)).map(x=>x.id);
 return s.sponsorships.filter(x=>sponsors.includes(x.sponsorId)&&x.active&&(!x.startAt||x.startAt<=at.slice(0,10))&&(!x.endAt||x.endAt>=at.slice(0,10)));
}
function vRooms(s,u){return activeRelations(s,u).map(x=>x.classroomId)}
export function visiblePost(s,u,p){
 if(u.role==='staff')return structuredClone(p);
 if(u.role!=='donor'||p.status!=='published')return null;
 const rooms=vRooms(s,u),schoolIds=s.classrooms.filter(c=>rooms.includes(c.id)).map(c=>c.schoolId);
 const allowed=p.teamIds.filter(id=>schoolIds.includes(id)&&activeRelations(s,u).some(x=>rooms.includes(x.classroomId)&&s.classrooms.some(c=>c.id===x.classroomId&&c.schoolId===id)&&(!x.historyFrom||p.publishedAt?.slice(0,10)>=x.historyFrom)));
 if(!allowed.length)return null;
 const blocks=p.blocks.filter(b=>(!b.schoolIds?.length||b.schoolIds.some(id=>allowed.includes(id)))&&(!b.classroomIds?.length||b.classroomIds.some(id=>rooms.includes(id)))).map(b=>({...b,schoolIds:(b.schoolIds||[]).filter(id=>allowed.includes(id)),classroomIds:(b.classroomIds||[]).filter(id=>rooms.includes(id))}));
 return {id:p.id,title:p.title,summary:p.summary,teamIds:allowed,blocks,cover:blocks.find(b=>b.type==='image')?.src||'/assets/music.jpg',status:p.status,createdAt:p.createdAt,publishedAt:p.publishedAt,version:p.version,views:[]};
}
export function schoolStats(s,school){const cs=s.checkins.filter(c=>c.teamId===school.id),posts=s.posts.filter(p=>p.status==='published'&&p.teamIds.includes(school.id));return {...school,checkinCount:cs.length,lastCheckinAt:cs.map(c=>c.createdAt).sort().at(-1),feedbackCount:posts.length,lastFeedbackAt:posts.map(p=>p.publishedAt).sort().at(-1),pendingCount:cs.filter(c=>!c.reviewed).length,overdue:!school.paused&&school.nextFeedbackAt<=vNow().slice(0,10)}}
export function teacherReminders(s){return s.assignments.map(a=>{const u=s.users.find(x=>x.id===a.userId),c=s.classrooms.find(x=>x.id===a.classroomId),school=s.schools.find(x=>x.id===c?.schoolId);if(!u||!c||school?.paused)return null;const last=s.checkins.filter(x=>x.userId===u.id&&x.classroomId===c.id).map(x=>x.createdAt).sort().at(-1),days=Math.floor((Date.now()-Date.parse(last||u.createdAt))/86400000);return {id:u.id,name:u.name,teamId:c.schoolId,classroomId:c.id,classroomName:c.name,lastAt:last,days,followups:s.followups.filter(f=>f.teacherId===u.id)}}).filter(x=>x&&x.days>=s.settings.reminderDays)}
export function domainSnapshot(s,u){
 const staff=u.role==='staff',rooms=staff||u.role==='teacher'?s.classrooms:s.classrooms.filter(c=>vRooms(s,u).includes(c.id)),schools=s.schools.filter(x=>rooms.some(c=>c.schoolId===x.id));
 return {schemaVersion:2,projects:s.projects,schools:schools.map(x=>staff?schoolStats(s,x):{id:x.id,name:x.name,region:x.region,projectId:x.projectId,children:x.children,photo:x.photo}),classrooms:rooms,assignments:u.role==='teacher'?s.assignments.filter(x=>x.userId===u.id):staff?s.assignments:[],sponsors:staff?s.sponsors:[],sponsorships:staff?s.sponsorships:[],contacts:staff?s.contacts:[],reviews:staff?s.reviews:[],deliveries:staff?s.deliveries:[],feedbackDue:staff?s.schools.map(x=>schoolStats(s,x)).filter(x=>x.overdue):[]};
}
export async function domainRoute(s,u,path,method,b,hashPassword){
 if(!u)return undefined;
 const staff=()=>{if(u.role!=='staff')vFail('没有操作权限',403)};
 if(path==='/api/teams'&&method==='POST'){b={...b,name:b.school,region:b.location};path='/api/schools'}
 const school=id=>s.schools.find(x=>x.id===id),room=id=>s.classrooms.find(x=>x.id===id);
 if(path==='/api/schools'&&method==='POST'){
  staff();const name=vText(b.name,80),region=vText(b.region,100);if(!name||!region)vFail('请填写学校名称和地区');if(b.id&&!school(b.id))vFail('学校不存在',404);
  const x=b.id?school(b.id):{id:vId(),children:0,photo:'music',createdAt:vNow(),projectId:'music',feedbackDays:30,nextFeedbackAt:new Date(Date.now()+30*86400000).toISOString().slice(0,10),paused:false};
  Object.assign(x,{name,region});if(b.feedbackDays!==undefined){if(!Number.isInteger(b.feedbackDays)||b.feedbackDays<1||b.feedbackDays>365)vFail('反馈周期应为 1–365 天');x.feedbackDays=b.feedbackDays}
  if(b.nextFeedbackAt!==undefined){if(!/^\d{4}-\d{2}-\d{2}$/.test(b.nextFeedbackAt)||!Number.isFinite(Date.parse(b.nextFeedbackAt)))vFail('反馈日期无效');x.nextFeedbackAt=b.nextFeedbackAt}
  if(typeof b.paused==='boolean')x.paused=b.paused;
  if(!b.id)s.schools.push(x);const legacy=s.teams.find(t=>t.id===x.id);if(legacy)Object.assign(legacy,{school:name,location:region});else s.teams.push({id:x.id,name,school:name,location:region,children:0,photo:'music',project:'大山里的音乐课堂',createdAt:x.createdAt});vLog(s,u,'维护学校档案',name);return {ok:true,id:x.id};
 }
 if(path==='/api/classrooms'&&method==='POST'){
  staff();if(!school(b.schoolId)||!vText(b.name)||!vText(b.type))vFail('请填写学校、教室名称和类型');const x=b.id?room(b.id):{id:vId()};if(!x)vFail('教室不存在',404);if(b.id&&x.schoolId!==b.schoolId)vFail('教室不能跨学校移动');if(b.donatedAt&&!/^\d{4}-\d{2}-\d{2}$/.test(b.donatedAt))vFail('捐赠日期无效');Object.assign(x,{schoolId:b.schoolId,name:vText(b.name),type:vText(b.type),namingUnit:vText(b.namingUnit),donatedAt:vText(b.donatedAt),projectId:'music'});if(!b.id)s.classrooms.push(x);vLog(s,u,'维护教室档案',x.name);return {ok:true,id:x.id};
 }
 if(path==='/api/assignments'&&method==='POST'){
  staff();const teacher=s.users.find(x=>x.id===b.userId&&x.role==='teacher');if(!teacher||!Array.isArray(b.classroomIds)||!b.classroomIds.length||b.classroomIds.some(id=>!room(id)))vFail('请选择老师和任教教室');s.assignments=s.assignments.filter(a=>a.userId!==b.userId);s.assignments.push(...[...new Set(b.classroomIds)].map(classroomId=>({userId:b.userId,classroomId})));teacher.teamId=room(b.classroomIds[0]).schoolId;vLog(s,u,'调整老师教室关系',teacher.name);return {ok:true};
 }
 if(path==='/api/sponsors'&&method==='POST'){
  staff();if(!vText(b.name))vFail('请填写捐赠方名称');const userIds=Array.isArray(b.userIds)?b.userIds:[];if(userIds.some(id=>!s.users.some(x=>x.id===id&&x.role==='donor')))vFail('请选择资助人账号');const x=b.id?s.sponsors.find(x=>x.id===b.id):{id:vId()};if(!x)vFail('捐赠方不存在',404);Object.assign(x,{name:vText(b.name),userIds:[...new Set(userIds)]});if(!b.id)s.sponsors.push(x);vLog(s,u,'维护捐赠方',x.name);return {ok:true,id:x.id};
 }
 if(path==='/api/sponsorships'&&method==='POST'){
  staff();if(!s.sponsors.some(x=>x.id===b.sponsorId)||!room(b.classroomId))vFail('请选择捐赠方和教室');for(const key of ['startAt','endAt','historyFrom'])if(b[key]&&!/^\d{4}-\d{2}-\d{2}$/.test(b[key]))vFail('日期格式无效');if(b.startAt&&b.endAt&&b.startAt>b.endAt)vFail('合作结束日期不能早于开始日期');
  const x=b.id?s.sponsorships.find(x=>x.id===b.id):{id:vId()};if(!x)vFail('合作关系不存在',404);Object.assign(x,{sponsorId:b.sponsorId,classroomId:b.classroomId,startAt:vText(b.startAt),endAt:vText(b.endAt),historyFrom:vText(b.historyFrom),active:b.active!==false});if(!b.id)s.sponsorships.push(x);vLog(s,u,'维护捐赠支持范围',x.id);return {ok:true};
 }
 if(path==='/api/contacts'&&method==='POST'){
  staff();if(!s.sponsors.some(x=>x.id===b.sponsorId)||!vText(b.name))vFail('请选择捐赠方并填写联系人姓名');const email=vText(b.email),phone=vText(b.phone);if(email&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))vFail('邮箱格式不正确');if(!email&&!phone)vFail('请至少填写电话或邮箱');const x=b.id?s.contacts.find(x=>x.id===b.id):{id:vId()};if(!x)vFail('联系人不存在',404);Object.assign(x,{sponsorId:b.sponsorId,name:vText(b.name),email,phone,role:b.role==='primary'?'primary':'cc'});if(!b.id)s.contacts.push(x);vLog(s,u,'维护通知联系人',x.name);return {ok:true};
 }
 if(path==='/api/posts'&&method==='POST'){
  staff();if(!Array.isArray(b.teamIds)||!b.teamIds.length||b.teamIds.some(id=>!school(id)))vFail('请选择关联学校');const old=b.id?s.posts.find(p=>p.id===b.id):null;if(b.id&&!old)vFail('图文不存在',404);if(old?.status==='published')vFail('请先撤回已发布图文');
  if(!Array.isArray(b.blocks)||b.blocks.length>100)vFail('正文格式不正确');
  const blocks=b.blocks.map(x=>{const classroomIds=Array.isArray(x.classroomIds)?[...new Set(x.classroomIds)]:[];if(classroomIds.some(id=>!room(id)||!b.teamIds.includes(room(id).schoolId)))vFail('教室专属段落必须属于关联学校');const schoolIds=Array.isArray(x.schoolIds)?[...new Set(x.schoolIds)]:[];if(schoolIds.some(id=>!b.teamIds.includes(id)))vFail('专属段落必须属于关联学校');if(x.type==='image'){if(!/^\/(assets|media)\/[\w.-]+$/.test(x.src))vFail('图片地址无效');return {type:'image',src:x.src,schoolIds,classroomIds}}if(!['text','heading','quote'].includes(x.type))vFail('段落类型不正确');return {type:x.type,text:vText(x.text,15000),schoolIds,classroomIds}});
  const sourceIds=Array.isArray(b.sourceIds)?[...new Set(b.sourceIds)]:[];if(sourceIds.some(id=>!s.checkins.some(c=>c.id===id&&b.teamIds.includes(c.teamId))))vFail('素材与关联学校不一致');if(!vText(b.title)||!blocks.some(x=>x.text||x.src))vFail('请填写标题和正文');
  const p={id:old?.id||vId(),title:vText(b.title,100),summary:vText(b.summary,300),teamIds:[...new Set(b.teamIds)],blocks,sourceIds,status:'draft',version:old?old.version+1:1,createdAt:old?.createdAt||vNow(),author:u.id,cover:blocks.find(x=>x.type==='image')?.src||'/assets/music.jpg',views:[]};if(old)Object.assign(old,p);else s.posts.unshift(p);vLog(s,u,'保存反馈版本',p.title+' v'+p.version);return {ok:true,id:p.id};
 }
 const match=path.match(/^\/api\/posts\/([^/]+)\/(publish|withdraw|view|submit)$/);
 if(match&&method==='POST'){
  const p=s.posts.find(x=>x.id===match[1]);if(!p)vFail('图文不存在',404);const act=match[2];
  if(act==='view'){if(!visiblePost(s,u,p))vFail('没有查看权限',403);if(!p.views.includes(u.id))p.views.push(u.id);return {ok:true}}
  staff();if(act==='withdraw'){p.status='draft';vLog(s,u,'撤回反馈',p.title);return {ok:true}}if(act==='submit'){if(p.status==='published')vFail('已发布的反馈不能重复送审');p.status='pending';vLog(s,u,'提交审核',p.title);return {ok:true}}
  if(p.status==='published')return {ok:true};if(b.reviewed!==true)vFail('请确认已完成人工审核');p.status='published';p.publishedAt=vNow();
  const review={id:vId(),postId:p.id,version:p.version,actor:u.id,actorName:u.name,createdAt:vNow(),snapshot:structuredClone(p)};s.reviews.push(review);
  for(const d of s.users.filter(x=>x.role==='donor'))if(visiblePost(s,d,p)&&!s.notifications.some(n=>n.userId===d.id&&n.postId===p.id&&(n.version||1)===p.version))s.notifications.unshift({id:vId(),userId:d.id,title:'你支持的学校有新反馈',text:p.title,postId:p.id,version:p.version,createdAt:vNow(),read:false});
  const eligibleSponsors=s.sponsors.filter(sp=>s.sponsorships.some(r=>r.sponsorId===sp.id&&r.active&&(!r.startAt||r.startAt<=p.publishedAt.slice(0,10))&&(!r.endAt||r.endAt>=p.publishedAt.slice(0,10))&&s.classrooms.some(c=>c.id===r.classroomId&&p.teamIds.includes(c.schoolId))));
  for(const sp of eligibleSponsors)for(const c of s.contacts.filter(c=>c.sponsorId===sp.id))for(const channel of ['email','phone'].filter(k=>c[k]))if(!s.deliveries.some(d=>d.postId===p.id&&d.contactId===c.id&&d.channel===channel&&d.version===p.version))s.deliveries.push({id:vId(),postId:p.id,version:p.version,sponsorId:sp.id,contactId:c.id,recipient:c[channel],channel,status:'pending',createdAt:vNow(),note:'待人工通知，尚未接入自动发送'});
  for(const id of p.teamIds){const x=school(id);x.nextFeedbackAt=new Date(Date.now()+x.feedbackDays*86400000).toISOString().slice(0,10)}p.sourceIds.forEach(id=>{const c=s.checkins.find(c=>c.id===id);if(c)c.reviewed=true});vLog(s,u,'审核发布反馈版本',p.title+' v'+p.version);return {ok:true};
 }
 if(path==='/api/membership'&&method==='POST'){
  staff();const target=s.users.find(x=>x.id===b.userId&&x.role!=='staff');if(!target||!Array.isArray(b.teamIds)||!b.teamIds.length||b.teamIds.some(id=>!school(id)))vFail('请选择成员和学校');
  if(target.role==='teacher'){target.teamId=b.teamIds[0];s.assignments=s.assignments.filter(a=>a.userId!==target.id);s.assignments.push(...s.classrooms.filter(c=>b.teamIds.includes(c.schoolId)).map(c=>({userId:target.id,classroomId:c.id})))}else {target.teamIds=b.teamIds;let sp=s.sponsors.find(sp=>sp.userIds.includes(target.id));if(!sp){sp={id:vId(),name:target.name,userIds:[target.id]};s.sponsors.push(sp)}s.sponsorships=s.sponsorships.filter(r=>r.sponsorId!==sp.id);s.sponsorships.push(...s.classrooms.filter(c=>b.teamIds.includes(c.schoolId)).map(c=>({id:vId(),sponsorId:sp.id,classroomId:c.id,active:true,startAt:'',endAt:'',historyFrom:''})));}vLog(s,u,'调整成员访问范围',target.name);return {ok:true};
 }
 if(path==='/api/teachers'&&method==='POST'){
  staff();const name=vText(b.name,30),username=vText(b.username,32);if(!name||!(/^[a-zA-Z0-9_-]{3,32}$/).test(username)||s.users.some(x=>x.username===username))vFail('姓名或账号无效，或账号已存在');if(typeof b.password!=='string'||b.password.length<12||b.password.length>128)vFail('初始密码需为 12–128 位');if(!Array.isArray(b.classroomIds)||!b.classroomIds.length||b.classroomIds.some(id=>!room(id)))vFail('请选择任教教室');const x={id:vId(),username,name,role:'teacher',teamId:room(b.classroomIds[0]).schoolId,teamIds:[],createdAt:vNow(),password:await hashPassword(b.password)};s.users.push(x);s.assignments.push(...[...new Set(b.classroomIds)].map(classroomId=>({userId:x.id,classroomId})));vLog(s,u,'添加老师账号',name);return {ok:true};
 }
 if(path==='/api/deliveries'&&method==='POST'){staff();const d=s.deliveries.find(x=>x.id===b.id);if(!d)vFail('通知记录不存在',404);if(!['manual','failed','pending'].includes(b.status)||!vText(b.note))vFail('请选择状态并填写通知记录');d.status=b.status;d.note=vText(b.note,1000);d.updatedAt=vNow();d.actor=u.name;vLog(s,u,'登记通知跟进',d.recipient);return {ok:true}}
 return undefined;
}
