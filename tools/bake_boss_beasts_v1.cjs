// Bake the SAME preview poses to isolated Node2D + AnimationPlayer scenes.
const fs=require('fs'),vm=require('vm'),path=require('path');
const root=path.resolve('prototypes/boss-beasts-v1');
const controls={bones:{checked:false},mirror:{checked:false},zoom:{value:'1'},speed:{value:'1'},scrub:{matches:()=>false}};
const noop=()=>{};const ctx=new Proxy({},{get:()=>noop,set:()=>true});
const el=()=>({value:'1',checked:false,dataset:{},classList:{toggle:noop},matches:()=>false});
const doc={querySelector:()=>({getContext:()=>ctx,width:1232,height:480}),getElementById:id=>controls[id]||(controls[id]=el()),querySelectorAll:()=>[]};
class Img{async decode(){const b=fs.readFileSync(path.join(root,this.src));this.width=b.readUInt32BE(16);this.height=b.readUInt32BE(20);}}
const sandbox={document:doc,Image:Img,console,requestAnimationFrame:noop,window:{},rigCapture:[]};vm.createContext(sandbox);vm.runInContext(fs.readFileSync(path.join(root,'preview.js'),'utf8'),sandbox);
setImmediate(()=>{
 const num=x=>Number(x.toFixed(6));const vec=(x,y)=>`Vector2(${num(x)}, ${num(y)})`;
 for(const k of ['wolf']){
  let clips=[];const ext=new Map();
  for(const v of ['side'])for(const action of ['idle','walk']){
   const duration=action==='idle'?(k==='bear'?3.8:2.8):(k==='bear'?2.6:1.9),frames=[];
   for(let n=0;n<=96;n++){sandbox.rigCapture=[];vm.runInContext(`state.action='${action}';beast('${k}','${v}',${n/96*duration})`,sandbox);frames.push(sandbox.rigCapture);}
   for(const p of frames[0])if(!ext.has(p.src))ext.set(p.src,ext.size+1);
   clips.push({name:v+'_'+action,duration,frames});
  }
  // Only the two side-view clips remain active; left uses the mirrored root.
  let nodes=[],base=0;
  for(const v of ['side']){const clip=clips.find(c=>c.name===v+'_idle');clip.base=base;for(let i=0;i<clip.frames[0].length;i++)nodes.push({v,i,p:clip.frames[0][i],id:base+i});base+=clip.frames[0].length;}
  let lines=['[gd_scene load_steps='+ (ext.size+clips.length+2)+' format=3]'];
  for(const [src,id]of ext)lines.push(`[ext_resource type="Texture2D" path="res://${src}" id="tex${id}"]`);
  for(const [ci,c]of clips.entries()){
   lines.push(`[sub_resource type="Animation" id="clip${ci}"]`,`resource_name = "${c.name}"`,`length = ${c.duration}`,'loop_mode = 1');let track=0;
   function add(p,values,times){let n=track++;lines.push(`tracks/${n}/type = "value"`,`tracks/${n}/path = NodePath("${p}")`,`tracks/${n}/interp = 1`,`tracks/${n}/loop_wrap = true`,`tracks/${n}/keys = {"times": PackedFloat32Array(${times.join(',')}), "transitions": PackedFloat32Array(${times.map(()=>1).join(',')}), "update": 0, "values": [${values.join(',')}]}`);}
   for(const node of nodes){let active=c.name.startsWith(node.v+'_');add(`Part${node.id}:visible`,[active?'true':'false'],[0]);if(!active)continue;let ps=c.frames.map(f=>f[node.i]),times=ps.map((_,n)=>num(n/96*c.duration));add(`Part${node.id}:position`,ps.map(p=>vec(p.x,p.y)),times);add(`Part${node.id}:rotation`,ps.map(p=>num(p.angle)),times);add(`Part${node.id}/Sprite:scale`,ps.map(p=>vec(p.w/p.iw,p.h/p.ih)),times);add(`Part${node.id}/Sprite:offset`,ps.map(p=>vec((.5-p.ax)*p.iw,(.5-p.ay)*p.ih)),times);}
  }
  lines.push('[sub_resource type="AnimationLibrary" id="library"]','_data = {'+clips.map((c,i)=>`"${c.name}": SubResource("clip${i}")`).join(',')+'}',`[node name="${k==='bear'?'AncientGuardianBear':'RuinWolfKing'}Candidate" type="Node2D"]`);
  for(const n of nodes){const p=n.p;lines.push(`[node name="Part${n.id}" type="Node2D" parent="."]`,`visible = ${n.v==='side'?'true':'false'}`,`position = ${vec(p.x,p.y)}`,`rotation = ${num(p.angle)}`,`metadata/part = "${p.src}"`,`[node name="Sprite" type="Sprite2D" parent="Part${n.id}"]`,`texture = ExtResource("tex${ext.get(p.src)}")`,`scale = ${vec(p.w/p.iw,p.h/p.ih)}`,`offset = ${vec((.5-p.ax)*p.iw,(.5-p.ay)*p.ih)}`);}
  lines.push('[node name="AnimationPlayer" type="AnimationPlayer" parent="."]','libraries = {&"": SubResource("library")}','autoplay = "side_walk"');
  fs.mkdirSync(path.join(root,'godot'),{recursive:true});fs.writeFileSync(path.join(root,'godot',k+'.tscn'),lines.join('\n'));console.log(k,nodes.length,'layered joint nodes; 2 side clips × 97 samples; textures',ext.size);
 }
});

