// Capture the actual interactive renderer, including its PNGs and joint transforms.
const fs=require('fs'),vm=require('vm'),path=require('path');
const root=path.resolve('prototypes/boss-beasts-v1'),noop=()=>{};
const reportName=process.argv[2]||'wolf-parts-v5';
if(!/^wolf-parts-v[0-9]+$/.test(reportName))throw Error('Invalid report name');
const control=()=>({value:'1',checked:false,dataset:{},classList:{toggle:noop},matches:()=>false});
const controls={},ctx=new Proxy({},{get:()=>noop,set:()=>true});
class Img{async decode(){const b=fs.readFileSync(path.join(root,this.src));this.width=b.readUInt32BE(16);this.height=b.readUInt32BE(20);}}
const box={document:{querySelector:()=>({getContext:()=>ctx}),getElementById:id=>controls[id]||(controls[id]=control()),querySelectorAll:()=>[]},Image:Img,console,requestAnimationFrame:noop,window:{},rigCapture:[]};
vm.createContext(box);vm.runInContext(fs.readFileSync(path.join(root,'preview.js'),'utf8'),box);
setImmediate(()=>{
 const frames=[];
 for(const action of ['idle','walk'])for(let i=0;i<96;i++){
  box.rigCapture=[];
  vm.runInContext(`state.action='${action}';state.pose=null;beast('wolf','side',${i/96*(action==='walk'?1.9:2.8)})`,box);
  frames.push({action,phase:i/96,parts:box.rigCapture});
 }
 fs.mkdirSync('reports/.tmp/'+reportName,{recursive:true});
 fs.writeFileSync('reports/.tmp/'+reportName+'/rig-frames.json',JSON.stringify(frames));
 console.log('Captured 192 frames of the real renderer');
});
