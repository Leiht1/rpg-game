// Focused geometry checks for the isolated side-view preview; no game or saves.
const fs=require('fs'),vm=require('vm'),path=require('path'),assert=require('assert');
const root=path.resolve('prototypes/boss-beasts-v1'),noop=()=>{};
const controls={},el=()=>({value:'1',checked:false,dataset:{},classList:{toggle:noop},matches:()=>false});
const ctx=new Proxy({},{get:()=>noop,set:()=>true});
class Img{async decode(){const b=fs.readFileSync(path.join(root,this.src));this.width=b.readUInt32BE(16);this.height=b.readUInt32BE(20);}}
const box={document:{querySelector:()=>({getContext:()=>ctx}),getElementById:id=>controls[id]||(controls[id]=el()),querySelectorAll:()=>[]},Image:Img,console,requestAnimationFrame:noop,window:{}};
vm.createContext(box);vm.runInContext(fs.readFileSync(path.join(root,'preview.js'),'utf8'),box);
let checks=0;const check=(v,m)=>{assert(v,m);checks++},dist=(a,b)=>Math.hypot(a[0]-b[0],a[1]-b[1]);
for(const k of ['bear','wolf']){
 const solve=(t,pose=null)=>vm.runInContext(`state.action='walk';state.pose=${JSON.stringify(pose)};solve('${k}',${t})`,box);
 const p=solve(0).p;let prev;
 for(let i=0;i<=1000;i++){
  const s=solve(i/1000*p.cycle);
  for(let j=0;j<2;j++){
   const l=s.legs[j],floor=l.far?-13:0;
   check(Math.abs(dist(l.hip,l.knee)-p.thigh)<1e-7,`${k} thigh length`);
   check(Math.abs(dist(l.knee,l.hock)-p.shin)<1e-7,`${k} shin reach`);
   check(Math.abs(dist(l.hock,l.heel)-p.ankle)<1e-7,`${k} ankle length`);
   check(l.knee[0]>l.hock[0]&&l.heel[0]>l.hock[0],`${k} knee/hock branch`);
   check(l.step.planted?l.sole[1]===floor:l.sole[1]<=floor,`${k} ground contact`);
   if(prev){const old=prev.legs[j];check(dist(l.knee,old.knee)<3,`${k} continuous knee`);
    if(l.step.planted&&old.step.planted&&l.step.q>old.step.q)check(Math.abs(l.sole[0]-old.sole[0]+p.stride/p.stance/1000)<1e-7,`${k} planted world position`);
   }
  }prev=s;
 }
 const neutral=solve(0,'neutral'),contact=solve(0,'contact'),down=solve(0,'down'),passing=solve(0,'passing');
 check(neutral.legs.every(l=>l.step.planted),'neutral four supports');
 check(contact.legs[1].step.planted&&contact.legs[1].step.x===p.stride/2,'contact forward landing');
 check(down.bodyY>contact.bodyY&&down.legs[1].step.planted,'down loaded support');
 check(!passing.legs[1].step.planted&&passing.legs[1].sole[1]<-15,'passing rear clearance');
}
console.log(`SIDE_HIND_QA ${checks} geometry, contact, continuity and key-pose checks passed`);
