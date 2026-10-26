// Install only the final approved part references and their unchanged baked clips.
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=path.resolve('.'),prototype=path.join(root,'prototypes/boss-beasts-v1');
const destination=path.join(root,'assets/exploration/wolf-v1');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
fs.mkdirSync(destination,{recursive:true});
const sourceScene=path.join(prototype,'godot/wolf.tscn');
let scene=fs.readFileSync(sourceScene,'utf8');
const refs=[...scene.matchAll(/\[ext_resource type="Texture2D" path="res:\/\/([^\"]+)"/g)];
const records=[];
for(const [,relative]of refs){
 const source=path.resolve(prototype,relative);
 if(!source.startsWith(prototype+path.sep))throw Error('Source outside candidate');
 const name=path.basename(source),bytes=fs.readFileSync(source);
 if(records.some(r=>r.file===name))throw Error('Duplicate part name');
 fs.writeFileSync(path.join(destination,name),bytes);
 const resource='res://assets/exploration/wolf-v1/'+name;
 scene=scene.replaceAll('res://'+relative,resource);
 scene=scene.replaceAll('metadata/part = "'+relative+'"','metadata/part = "'+resource+'"');
 records.push({file:name,source:path.relative(root,source).replaceAll('\\','/'),sha256:sha(bytes)});
}
if(records.length!==12)throw Error('Expected the approved 12 unique parts');
scene=scene.replace(/load_steps=(\d+)/,(_,n)=>'load_steps='+(Number(n)+1));
scene=scene.replace(/^(\[gd_scene[^\n]+\n)/,'$1[ext_resource type="Script" path="res://scripts/guardian_wolf_visual.gd" id="driver"]\n');
scene=scene.replace('[node name="RuinWolfKingCandidate" type="Node2D"]','[node name="RuinGuardianWolf" type="Node2D"]\nscript = ExtResource("driver")\ntexture_filter = 2');
scene=scene.replace('autoplay = "side_walk"','autoplay = "side_idle"');
if(scene.includes('res://prototypes/')||scene.includes('res://assets/wolf/'))throw Error('Candidate runtime dependency');
fs.writeFileSync(path.join(destination,'wolf.tscn'),scene);
const provenance={approval:'approved_current_v11',date:'2026-10-26',quote:'先暂定这版吧，接入游戏，然后将项目推送到远端',scope:'Current V11 side-view wolf with approved idle/walk clips; left is mirrored. No approval of future art or new attack clips.',route:'host_image:imagegen + existing accepted parts',source_records:['art/wolf-unify-v11/provenance.json','art/wolf-build-v10/provenance.json','prototypes/boss-beasts-v1/assets/provenance.json'],scene_source:'prototypes/boss-beasts-v1/godot/wolf.tscn',scene_sha256:sha(Buffer.from(scene)),parts:records};
fs.writeFileSync(path.join(destination,'provenance.json'),JSON.stringify(provenance,null,2)+'\n');
console.log('Installed',records.length,'approved PNGs and the unchanged two-clip pose data');
