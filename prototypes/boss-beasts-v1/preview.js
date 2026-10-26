'use strict';
const canvas=document.querySelector('canvas'),ctx=canvas.getContext('2d'),$=id=>document.getElementById(id),images={};
const state={kind:'both',view:'side',action:'walk',playing:true,t:0,last:0,pose:null};
const TAU=Math.PI*2,parts=['torso','head','neck','shoulder','fore_upper','fore_lower','fore_paw','hip','hind_lower','hind_ankle','hind_paw'];
const profiles={bear:{cycle:2.6,idle:3.8,stride:52,lift:22,stance:.74,thigh:52,shin:50,ankle:24,distalAngle:.34,sink:4.5},wolf:{cycle:1.9,idle:2.8,stride:70,lift:32,stance:.68,thigh:55,shin:51,ankle:34,distalAngle:.62,sink:2.5}};
async function load(path){const im=new Image();im.src=path;await im.decode();images[path]=im;}
const asset=(k,v,p)=>images[`assets/${k}/${v}/${p}.png`];
function sprite(im,x,y,w,h,angle=0,ax=.5,ay=.5){if(typeof rigCapture!=='undefined')rigCapture.push({src:im.src,x,y,w,h,angle,ax,ay,iw:im.width,ih:im.height});ctx.save();ctx.translate(x,y);ctx.rotate(angle);ctx.drawImage(im,-w*ax,-h*ay,w,h);ctx.restore();}
function piece(k,v,p,x,y,w,h,a=0,ax=.5,ay=.5){sprite(asset(k,v,p),x,y,w,h,a,ax,ay);}
function bone(a,b,color,label=''){if(!$('bones').checked)return;ctx.save();ctx.strokeStyle=color;ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(...a);ctx.lineTo(...b);ctx.stroke();ctx.fillStyle=color;ctx.beginPath();ctx.arc(...a,3,0,TAU);ctx.fill();if(label){ctx.font='11px system-ui';ctx.textAlign='left';ctx.fillText(label,a[0]+5,a[1]-5);}ctx.restore();}
function segment(k,v,p,a,b,width){const dx=b[0]-a[0],dy=b[1]-a[1],length=Math.hypot(dx,dy);piece(k,v,p,a[0],a[1],width,length+width*.43,Math.atan2(-dx,dy),.5,.16);}
function ik(a,b,l1,l2,bend){const dx=b[0]-a[0],dy=b[1]-a[1],d=Math.hypot(dx,dy),dist=Math.min(Math.max(d,Math.abs(l1-l2)+.001),l1+l2-.001),angle=Math.atan2(dy,dx),offset=Math.acos(Math.max(-1,Math.min(1,(l1*l1+dist*dist-l2*l2)/(2*l1*dist))));return[a[0]+Math.cos(angle+bend*offset)*l1,a[1]+Math.sin(angle+bend*offset)*l1];}
const wrap=x=>(x%1+1)%1,smooth=x=>x*x*(3-2*x);
// Body-following camera: planted feet and ground move at the same constant speed.
function foot(phase,p){const q=wrap(phase);if(q<=p.stance)return{x:p.stride*(.5-q/p.stance),y:0,q,swing:0,planted:true};const u=(q-p.stance)/(1-p.stance);return{x:p.stride*(-.5+smooth(u)),y:-p.lift*Math.sin(Math.PI*u)**2,q,swing:Math.sin(Math.PI*u),planted:false};}
function poseTime(k,t){if(state.pose==='neutral')return 0;if(state.pose!==null)return({contact:0,down:.14,passing:.84}[state.pose]||0)*profiles[k].cycle;return t;}
function solve(k,t){const p=profiles[k],bear=k==='bear',walk=state.action==='walk'&&state.pose!=='neutral';t=poseTime(k,t);const phase=t/p.cycle,breath=Math.sin(t*TAU/p.idle),bodyY=-139+(walk?p.sink*Math.cos((phase-.14)*TAU*2):breath*1.1),pitch=walk?(bear?.012:.008)*Math.sin(phase*TAU):.003*breath;const legs=[];
 for(const rear of [true,false])for(const far of [true,false]){const x=rear?-81:74,floor=far?-13:0,offset=rear?(far?.5:0):(far?.25:.75),step=walk?foot(phase+offset,p):{x:0,y:0,q:0,swing:0,planted:true},hip=[x,bodyY+(rear?30:20)+(far?-5:0)],sole=[x+step.x,floor+step.y];
  if(rear){const heel=[sole[0]-11,sole[1]-(bear?12:15)],angle=p.distalAngle-(bear?.08:.28)*step.swing,hock=[heel[0]-Math.sin(angle)*p.ankle,heel[1]-Math.cos(angle)*p.ankle],knee=ik(hip,hock,p.thigh,p.shin,-1);legs.push({rear,far,hip,knee,hock,heel,sole,step});}
  else{const knee=ik(hip,sole,bear?63:66,bear?61:68,1);legs.push({rear,far,hip,knee,sole,step});}
 }return{p,t,walk,phase,bodyY,pitch,legs};}
function beast(k,v,t){const bear=k==='bear',s=solve(k,t),{p,bodyY,pitch,phase,walk,legs}=s;t=s.t;
 function drawLeg(l){ctx.save();if(l.far)ctx.globalAlpha=.92;
  if(l.rear){segment(k,'side','hind_ankle',l.hock,l.heel,bear?26:19);segment(k,'side','hind_lower',l.knee,l.hock,bear?34:23);segment(k,'side','hip',l.hip,l.knee,bear?51:40);piece(k,'side','hind_paw',l.sole[0]+5,l.sole[1],bear?57:43,bear?28:23,0,.5,1);}
  else{segment(k,'side','fore_lower',l.knee,[l.sole[0],l.sole[1]-7],bear?37:24);segment(k,'side','fore_upper',l.hip,l.knee,bear?47:31);piece(k,'side','fore_paw',l.sole[0]+5,l.sole[1],bear?57:43,bear?28:23,0,.5,1);}
  ctx.restore();}
 ctx.save();if($('mirror').checked)ctx.scale(-1,1);
 if(k==='wolf')piece(k,'side','tail',-123,bodyY+4,102,112,Math.sin(walk?phase*TAU:t*TAU/p.idle)*.045,.92,.12);
 legs.filter(l=>l.far).forEach(drawLeg);legs.filter(l=>!l.far&&l.rear).forEach(drawLeg);
 piece(k,'side','torso',-5,bodyY,bear?250:280,bear?151:125,pitch);
 legs.filter(l=>!l.far&&!l.rear).forEach(drawLeg);
 const shoulder=legs.find(l=>!l.rear&&!l.far);piece(k,'side','shoulder',shoulder.hip[0],shoulder.hip[1]-8,bear?66:49,bear?65:52);
 const hx=bear?119:139,hy=bodyY-15,headTurn=(walk?.014:.022)*Math.sin(walk?phase*TAU:t*TAU/p.idle);piece(k,'side','neck',hx-35,hy+18,bear?104:90,bear?88:82,pitch);piece(k,'side','head',hx,hy-5,bear?139:135,bear?125:121,headTurn);
 for(const l of legs){if(l.rear){bone(l.hip,l.knee,'#ffd487',l.far?'':'髋');bone(l.knee,l.hock,'#a8e4ed',l.far?'':'膝');bone(l.hock,l.heel,'#f8b8ab',l.far?'':'飞节');bone(l.heel,l.sole,'#e7edac');}else{bone(l.hip,l.knee,'#ffd487');bone(l.knee,l.sole,'#a8e4ed');}if($('bones').checked){ctx.strokeStyle=l.step.planted?'#375c39':'#a06539';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(l.sole[0]-16,l.sole[1]);ctx.lineTo(l.sole[0]+22,l.sole[1]);ctx.stroke();}}
 ctx.restore();return{duration:p.cycle};}
function text(s,x,y,size=16,color='#354b40'){ctx.fillStyle=color;ctx.font=`${size}px system-ui`;ctx.textAlign='center';ctx.fillText(s,x,y);}
function render(){ctx.clearRect(0,0,1232,480);ctx.fillStyle='#bec9b7';ctx.fillRect(0,0,1232,480);ctx.fillStyle='#b4c1ad';ctx.fillRect(0,350,1232,130);const kinds=state.kind==='both'?['bear','wolf']:[state.kind];if(kinds.length===2){ctx.strokeStyle='#8e9f8b';ctx.beginPath();ctx.moveTo(616,34);ctx.lineTo(616,440);ctx.stroke();}
 for(let i=0;i<kinds.length;i++){const k=kinds[i],center=kinds.length===2?i*616+310:620,zoom=+$('zoom').value,s=solve(k,state.t);ctx.save();ctx.translate(center,385);ctx.scale(zoom,zoom);ctx.fillStyle='#52634c33';ctx.beginPath();ctx.ellipse(0,-2,170,23,0,0,TAU);ctx.fill();
  // These ground ticks are a moving contact reference, not creature motion or a game scene.
  const distance=s.walk?s.t*s.p.stride/(s.p.stance*s.p.cycle):0,dir=$('mirror').checked?-1:1;ctx.strokeStyle='#81957980';ctx.lineWidth=1;for(let j=-8;j<=8;j++){const x=dir*(j*40-(distance%40));if(x < -215||x>215)continue;ctx.beginPath();ctx.moveTo(x,1);ctx.lineTo(x+dir*14,1);ctx.stroke();}
  beast(k,'side',state.t);const player=images['assets/player.png'],height=82;sprite(player,-252,0,height*player.width/player.height,height,0,.5,1);text('玩家',-252,25,12);ctx.restore();text(k==='bear'?'远古守护熊 · 厚重承压':'遗迹狼王 · 低伏追踪',center,38,19);}
 $('info').textContent='仅左右侧视 · 玩家 82 px；熊约 2.7 倍、狼约 2.65 倍。地面短线与支撑脚同步，表示镜头跟随下的接地。';const k=state.kind==='wolf'?'wolf':'bear',period=state.action==='walk'?profiles[k].cycle:profiles[k].idle;if(!$('scrub').matches(':active'))$('scrub').value=wrap(state.t/period)*1000;}
function tick(now){if(state.playing&&state.last)state.t+=Math.min((now-state.last)/1000,.05)*+$('speed').value;state.last=now;render();requestAnimationFrame(tick);}
function play(p){state.playing=p;$('play').textContent=p?'暂停':'播放';if(p)state.pose=null;}
document.querySelectorAll('[data-kind]').forEach(b=>b.onclick=()=>{state.kind=b.dataset.kind;if(state.kind==='both')$('zoom').value='1';document.querySelectorAll('[data-kind]').forEach(x=>x.classList.toggle('active',x===b));});
$('action').onchange=()=>{state.action=$('action').value;state.t=0;state.pose=null;};$('play').onclick=()=>play(!state.playing);
$('scrub').oninput=()=>{play(false);state.pose=null;const k=state.kind==='wolf'?'wolf':'bear';state.t=+$('scrub').value/1000*(state.action==='walk'?profiles[k].cycle:profiles[k].idle);};
document.querySelectorAll('[data-phase]').forEach(b=>b.onclick=()=>{play(false);state.action='walk';$('action').value='walk';state.pose=b.dataset.phase;state.t=({neutral:0,contact:0,down:.14,passing:.84}[state.pose]||0)*(state.kind==='wolf'?profiles.wolf.cycle:profiles.bear.cycle);});
$('zoom').onchange=()=>{if(state.kind==='both'&&+$('zoom').value>1){state.kind='bear';document.querySelectorAll('[data-kind]').forEach(x=>x.classList.toggle('active',x.dataset.kind==='bear'));}};
Promise.all(['bear','wolf'].flatMap(k=>[...parts,...(k==='wolf'?['tail']:[])].map(p=>load(`assets/${k}/side/${p}.png`))).concat(load('assets/player.png'))).then(()=>{$('status').textContent='本轮仅修侧视后腿与步态。髋—膝—飞节—脚掌独立；Neutral 为四足站稳，Contact / Down / Passing 为近侧后腿参照。';window.previewReady=true;requestAnimationFrame(tick);}).catch(e=>{$('status').textContent='素材加载失败：'+e;console.error(e);});
