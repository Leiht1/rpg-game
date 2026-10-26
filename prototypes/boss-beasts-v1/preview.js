'use strict';
const canvas=document.querySelector('canvas'),ctx=canvas.getContext('2d'),$=id=>document.getElementById(id),images={};
const state={kind:'wolf',view:'side',action:'walk',playing:true,t:0,last:0,pose:null};
const TAU=Math.PI*2,parts=['torso','head','neck','shoulder','fore_upper','fore_lower','fore_paw','hip','hind_lower','hind_ankle','hind_paw'];
const profiles={bear:{cycle:2.6,idle:3.8,stride:52,lift:22,stance:.74,thigh:52,shin:50,ankle:24,distalAngle:.34,sink:4.5},wolf:{cycle:1.9,idle:2.8,stride:70,lift:32,stance:.68,thigh:63,shin:60,ankle:34,distalAngle:.62,sink:2.5}};
async function load(path){const im=new Image();im.src=path;await im.decode();images[path]=im;}
const revisedParts=new Set(['torso','tail','fore_upper','hip','fore_paw','hind_paw','fore_lower','hind_lower','hind_ankle']);
const lowerParts=new Set(['fore_lower','hind_lower','hind_ankle','fore_paw','hind_paw']);
const furParts=new Set(['fore_lower','hind_lower','hind_ankle']);
const buildParts=new Set(['fore_upper','hip','fore_lower','hind_lower','hind_ankle','fore_paw','hind_paw']);
const unifiedParts=new Set(['fore_lower','hind_lower','hind_ankle','fore_paw','hind_paw']);
const partPath=(k,v,p)=>`assets/${k}/${unifiedParts.has(p)?'side-v11':buildParts.has(p)?'side-v10':revisedParts.has(p)?'side-v5':v}/${p}.png`;
const lowerJoints={"hip":{"a":[0.41935483870967744,0.15572232645403378],"b":[0.5967741935483871,0.8405253283302064]},"fore_upper":{"a":[0.4244791666666667,0.10940499040307101],"b":[0.6119791666666666,0.8886756238003839]},"fore_lower":{"a":[0.4726890756302521,0.08664259927797834],"b":[0.5504201680672269,0.9187725631768953]},"hind_lower":{"a":[0.47619047619047616,0.08888888888888889],"b":[0.5992063492063492,0.9166666666666666]},"hind_ankle":{"a":[0.4483695652173913,0.11013215859030837],"b":[0.5543478260869565,0.9074889867841409]}};
// Source joint pairs set one uniform scale: no independently squashed/repeated limb artwork.
function lowerPart(p,a,b){const im=asset('wolf','side',p),j=lowerJoints[p],cross=p==='hip'||p==='hind_lower'||p==='hind_ankle'?1.12:p==='fore_lower'?1.10:1,sx=(j.b[0]-j.a[0])*im.width*cross,sy=(j.b[1]-j.a[1])*im.height,dx=b[0]-a[0],dy=b[1]-a[1],scale=Math.hypot(dx,dy)/Math.hypot(sx,sy);sprite(im,a[0],a[1],im.width*scale*cross,im.height*scale,Math.atan2(dy,dx)-Math.atan2(sy,sx),j.a[0],j.a[1]);}
function pawArt(l){const p=l.rear?'hind_paw':'fore_paw',im=asset('wolf','side',p),w=l.rear?34:33,h=w*im.height/im.width,ay=1-5/im.height,x=l.sole[0]+(l.rear?-9:-2);return{p,x,y:l.sole[1],w,h,ay,socket:[x,l.sole[1]+(.50-ay)*h]};}
const asset=(k,v,p)=>images[partPath(k,v,p)];
function sprite(im,x,y,w,h,angle=0,ax=.5,ay=.5){if(typeof rigCapture!=='undefined')rigCapture.push({src:im.src,x,y,w,h,angle,ax,ay,iw:im.width,ih:im.height});ctx.save();ctx.translate(x,y);ctx.rotate(angle);ctx.drawImage(im,-w*ax,-h*ay,w,h);ctx.restore();}
function piece(k,v,p,x,y,w,h,a=0,ax=.5,ay=.5){sprite(asset(k,v,p),x,y,w,h,a,ax,ay);}
function bone(a,b,color,label=''){if(!$('bones').checked)return;ctx.save();ctx.strokeStyle=color;ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(...a);ctx.lineTo(...b);ctx.stroke();ctx.fillStyle=color;ctx.beginPath();ctx.arc(...a,3,0,TAU);ctx.fill();if(label){ctx.font='11px system-ui';ctx.textAlign='left';ctx.fillText(label,a[0]+5,a[1]-5);}ctx.restore();}
function segment(k,v,p,a,b,width,top=.16,extra=.43){const dx=b[0]-a[0],dy=b[1]-a[1],length=Math.hypot(dx,dy);piece(k,v,p,a[0],a[1],width,length+width*extra,Math.atan2(-dx,dy),.5,top);}
function ik(a,b,l1,l2,bend){const dx=b[0]-a[0],dy=b[1]-a[1],d=Math.hypot(dx,dy),dist=Math.min(Math.max(d,Math.abs(l1-l2)+.001),l1+l2-.001),angle=Math.atan2(dy,dx),offset=Math.acos(Math.max(-1,Math.min(1,(l1*l1+dist*dist-l2*l2)/(2*l1*dist))));return[a[0]+Math.cos(angle+bend*offset)*l1,a[1]+Math.sin(angle+bend*offset)*l1];}
const wrap=x=>(x%1+1)%1,smooth=x=>x*x*(3-2*x);
// Body-following camera: planted feet and ground move at the same constant speed.
function foot(phase,p){const q=wrap(phase);if(q<=p.stance)return{x:p.stride*(.5-q/p.stance),y:0,q,swing:0,planted:true};const u=(q-p.stance)/(1-p.stance);return{x:p.stride*(-.5+smooth(u)),y:-p.lift*Math.sin(Math.PI*u)**2,q,swing:Math.sin(Math.PI*u),planted:false};}
function poseTime(k,t){if(state.pose==='neutral')return 0;if(state.pose!==null)return({contact:0,down:.14,passing:.84}[state.pose]||0)*profiles[k].cycle;return t;}
function solve(k,t){const p=profiles[k],bear=k==='bear',walk=state.action==='walk'&&state.pose!=='neutral';t=poseTime(k,t);const phase=t/p.cycle,breath=Math.sin(t*TAU/p.idle),bodyY=-139+(walk?p.sink*Math.cos((phase-.14)*TAU*2):breath*1.1),pitch=.125+(walk?(bear?.012:.008)*Math.sin(phase*TAU):.003*breath);const torsoY=bodyY-79*(Math.sin(pitch)-Math.sin(.045));const legs=[];
 for(const rear of [true,false])for(const far of [true,false]){const x=rear?(far?-103:-94):74,floor=far?-13:0,offset=rear?(far?.5:0):(far?.25:.75),step=walk?foot(phase+offset,p):{x:0,y:0,q:0,swing:0,planted:true},hip=[x,bodyY+(rear?12:20)+(far?-5:0)-(rear?(74-x)*(Math.sin(pitch)-Math.sin(.045)):0)],sole=[x+step.x,floor+step.y];
  if(rear){const heel=[sole[0]-11,sole[1]-(bear?12:15)],angle=p.distalAngle-(bear?.08:.28)*step.swing,hock=[heel[0]-Math.sin(angle)*p.ankle,heel[1]-Math.cos(angle)*p.ankle],knee=ik(hip,hock,p.thigh,p.shin,-1);legs.push({rear,far,hip,knee,hock,heel,sole,step});}
  else{const knee=ik(hip,sole,bear?63:66,bear?61:62,1);legs.push({rear,far,hip,knee,sole,step});}
 }return{p,t,walk,phase,bodyY,torsoY,pitch,legs};}
function beast(k,v,t){const bear=k==='bear',s=solve(k,t),{p,bodyY,torsoY,pitch,phase,walk,legs}=s;t=s.t;
 function drawLeg(l){ctx.save();if(l.far)ctx.globalAlpha=.92;
  const paw=pawArt(l);
  if(l.rear){lowerPart('hind_ankle',l.hock,paw.socket);lowerPart('hind_lower',l.knee,l.hock);lowerPart('hip',l.hip,l.knee);}
  else{lowerPart('fore_lower',l.knee,paw.socket);lowerPart('fore_upper',l.hip,l.knee);}
  piece(k,'side',paw.p,paw.x,paw.y,paw.w,paw.h,0,.22,paw.ay);
  ctx.restore();}
 ctx.save();if($('mirror').checked)ctx.scale(-1,1);

 // Complete rounded tail root is masked by the complete rump, with a small overlap.
 const tailRoot=[-140,-17],tx=-5+tailRoot[0]*Math.cos(pitch)-tailRoot[1]*Math.sin(pitch),ty=torsoY+tailRoot[0]*Math.sin(pitch)+tailRoot[1]*Math.cos(pitch);
 if(k==='wolf')piece(k,'side','tail',tx,ty,118,98,pitch+Math.sin(walk?phase*TAU:t*TAU/p.idle)*.025,.92,.12);
 legs.filter(l=>l.far).forEach(drawLeg);
 piece(k,'side','torso',-5,torsoY,bear?250:280,bear?151:125,pitch);
 // Near thigh belongs on the visible flank; the far thigh stays behind the body.
 legs.filter(l=>!l.far&&l.rear).forEach(drawLeg);

 legs.filter(l=>!l.far&&!l.rear).forEach(drawLeg);
 const shoulder=legs.find(l=>!l.rear&&!l.far);piece(k,'side','shoulder',shoulder.hip[0],shoulder.hip[1]-8,bear?66:49,bear?65:52);
 const hx=bear?119:139,hy=bodyY-15,headTurn=(walk?.014:.022)*Math.sin(walk?phase*TAU:t*TAU/p.idle);piece(k,'side','neck',hx-35,hy+18,bear?104:90,bear?88:82,pitch);piece(k,'side','head',hx,hy-5,bear?139:135,bear?125:121,headTurn);
 for(const l of legs){if(l.rear){bone(l.hip,l.knee,'#ffd487',l.far?'':'髋');bone(l.knee,l.hock,'#a8e4ed',l.far?'':'膝');bone(l.hock,l.heel,'#f8b8ab',l.far?'':'飞节');bone(l.heel,l.sole,'#e7edac');}else{bone(l.hip,l.knee,'#ffd487');bone(l.knee,l.sole,'#a8e4ed');}if($('bones').checked){ctx.strokeStyle=l.step.planted?'#375c39':'#a06539';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(l.sole[0]-16,l.sole[1]);ctx.lineTo(l.sole[0]+22,l.sole[1]);ctx.stroke();}}
 ctx.restore();return{duration:p.cycle};}
function text(s,x,y,size=16,color='#354b40'){ctx.fillStyle=color;ctx.font=`${size}px system-ui`;ctx.textAlign='center';ctx.fillText(s,x,y);}
function render(){ctx.clearRect(0,0,1232,480);ctx.fillStyle='#bec9b7';ctx.fillRect(0,0,1232,480);ctx.fillStyle='#b4c1ad';ctx.fillRect(0,350,1232,130);const kinds=['wolf'];if(kinds.length===2){ctx.strokeStyle='#8e9f8b';ctx.beginPath();ctx.moveTo(616,34);ctx.lineTo(616,440);ctx.stroke();}
 for(let i=0;i<kinds.length;i++){const k=kinds[i],center=kinds.length===2?i*616+310:620,zoom=+$('zoom').value,s=solve(k,state.t);ctx.save();ctx.translate(center,385);ctx.scale(zoom,zoom);ctx.fillStyle='#52634c33';ctx.beginPath();ctx.ellipse(0,-2,170,23,0,0,TAU);ctx.fill();
  // These ground ticks are a moving contact reference, not creature motion or a game scene.
  const distance=s.walk?s.t*s.p.stride/(s.p.stance*s.p.cycle):0,dir=$('mirror').checked?-1:1;ctx.strokeStyle='#81957980';ctx.lineWidth=1;for(let j=-8;j<=8;j++){const x=dir*(j*40-(distance%40));if(x < -215||x>215)continue;ctx.beginPath();ctx.moveTo(x,1);ctx.lineTo(x+dir*14,1);ctx.stroke();}
  beast(k,'side',state.t);const player=images['assets/player.png'],height=82;sprite(player,-252,0,height*player.width/player.height,height,0,.5,1);text('玩家',-252,25,12);ctx.restore();text(k==='bear'?'远古守护熊 · 厚重承压':'遗迹狼王 · 低伏追踪',center,38,19);}
 $('info').textContent='仅左右侧视 · 玩家 82 px；狼约 2.65 倍。地面短线与支撑脚同步，表示镜头跟随下的接地。';const k='wolf',period=state.action==='walk'?profiles[k].cycle:profiles[k].idle;if(!$('scrub').matches(':active'))$('scrub').value=wrap(state.t/period)*1000;}
function renderReview(page){ctx.clearRect(0,0,1232,480);ctx.fillStyle='#bec9b7';ctx.fillRect(0,0,1232,480);for(let i=0;i<8;i++){const n=page*8+i;ctx.save();ctx.translate((i%4)*308+155,Math.floor(i/4)*240+205);ctx.scale(.58,.58);beast('wolf','side',n/24*profiles.wolf.cycle);ctx.restore();text('行走 '+n+'/24',(i%4)*308+154,Math.floor(i/4)*240+230,12);}}
function tick(now){if(typeof location!=='undefined'&&new URLSearchParams(location.search).has('review')){renderReview(Number(new URLSearchParams(location.search).get('review')));return;}if(state.playing&&state.last)state.t+=Math.min((now-state.last)/1000,.05)*+$('speed').value;state.last=now;render();requestAnimationFrame(tick);}
function play(p){state.playing=p;$('play').textContent=p?'暂停':'播放';if(p)state.pose=null;}
document.querySelectorAll('[data-kind]').forEach(b=>b.onclick=()=>{state.kind=b.dataset.kind;if(state.kind==='both')$('zoom').value='1';document.querySelectorAll('[data-kind]').forEach(x=>x.classList.toggle('active',x===b));});
$('action').onchange=()=>{state.action=$('action').value;state.t=0;state.pose=null;};$('play').onclick=()=>play(!state.playing);
$('scrub').oninput=()=>{play(false);state.pose=null;const k='wolf';state.t=+$('scrub').value/1000*(state.action==='walk'?profiles[k].cycle:profiles[k].idle);};
document.querySelectorAll('[data-phase]').forEach(b=>b.onclick=()=>{play(false);state.action='walk';$('action').value='walk';state.pose=b.dataset.phase;state.t=({neutral:0,contact:0,down:.14,passing:.84}[state.pose]||0)*(state.kind==='wolf'?profiles.wolf.cycle:profiles.bear.cycle);});
$('zoom').onchange=()=>{if(state.kind==='both'&&+$('zoom').value>1){state.kind='bear';document.querySelectorAll('[data-kind]').forEach(x=>x.classList.toggle('active',x.dataset.kind==='bear'));}};
Promise.all(['wolf'].flatMap(k=>[...parts,...(k==='wolf'?['tail']:[])].map(p=>load(partPath(k,'side',p)))).concat(load('assets/player.png'))).then(()=>{$('status').textContent='后腿加粗、前小腿略缩短、臀部再抬高；灰色毛束与描边按当前大腿统一。髋—膝—飞节—脚掌独立；Neutral 为四足站稳，Contact / Down / Passing 为近侧后腿参照。';window.previewReady=true;const q=typeof URLSearchParams==='undefined'?{has:()=>false}:new URLSearchParams(typeof location==='undefined'?'':location.search);if(q.has('pose')){state.playing=false;state.pose=q.get('pose');}if(q.has('time')){state.playing=false;state.t=Number(q.get('time'));}if(q.has('mirror'))$('mirror').checked=true;if(q.has('zoom'))$('zoom').value=q.get('zoom');render();requestAnimationFrame(tick);}).catch(e=>{$('status').textContent='素材加载失败：'+e;console.error(e);});
