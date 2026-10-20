"""Author a real editable Godot rig from the single newly painted neutral atlas.

This is an offline authoring tool. Runtime uses saved Skeleton2D, Polygon2D
weights and AnimationPlayer resources; no sprite cutting or runtime IK.
"""
from pathlib import Path
import hashlib
import json
import math
import shutil
import numpy as np
from PIL import Image
from scipy.ndimage import label

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT.parents[1]
ASSETS = ROOT / 'art'
ASSETS.mkdir(exist_ok=True)
TAU = math.tau


def dump(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def f(v):
    return f'{float(v):.7f}'.rstrip('0').rstrip('.') if abs(v) > 1e-9 else '0'


def real(v):
    text = f(v)
    return text if '.' in text else text + '.0'


def arr(kind, values):
    return kind + '(' + ', '.join(f(v) for v in values) + ')'


def vec(v):
    return arr('Vector2', v)


def smooth(a, b, x):
    t = np.clip((x-a)/(b-a), 0, 1)
    return t*t*(3-2*t)


# Explicit ownership boxes: the generated atlas is not assumed to be exact grid cells.
BOXES = {
    'head': (50, 30, 395, 330),
    'base': (460, 70, 675, 350),
    'olive_torso': (780, 70, 1035, 350),
    'teal_torso': (1130, 65, 1365, 350),
    'shorts': (65, 435, 375, 665),
    'arm': (490, 355, 650, 710),
    'leg': (820, 350, 975, 700),
    'boot': (1125, 460, 1410, 660),
    'olive_sleeve': (115, 720, 305, 1020),
    'teal_sleeve': (480, 720, 670, 1040),
    'scarf': (785, 740, 1040, 1000),
    'neutral_reference': (1135, 662, 1370, 1085),
}


def prepare_parts():
    source = Image.open(ROOT / 'source/generated/generated.png').convert('RGBA')
    records = {}
    for name, box in BOXES.items():
        part = source.crop(box)
        a = np.array(part)
        # Keep the complete main painted object including antialiasing. Remove only
        # disconnected source speckles, never slice an anatomical region.
        labs, n = label(a[:, :, 3] > 2)
        counts = np.bincount(labs.ravel())
        keep = counts >= 12
        keep[0] = False
        a[:, :, 3][~keep[labs]] = 0
        part = Image.fromarray(a)
        bbox = part.getbbox()
        part = part.crop(bbox)
        # Two pixels of actual alpha padding for filtered texture edges.
        out = Image.new('RGBA', (part.width+4, part.height+4))
        out.alpha_composite(part, (2, 2))
        out.save(ASSETS / f'{name}.png')
        records[name] = {'ownership_box': box, 'crop_in_box': bbox,
                         'source_size': out.size, 'operation': 'whole newly drawn part; alpha padding; no anatomical cuts'}
    ref_dir = ROOT / 'reference'
    ref_dir.mkdir(exist_ok=True)
    hashes = {}
    for action, count in [('walk', 8), ('idle', 4)]:
        for i in range(count):
            src = GAME / f'assets/hero/final_sprite/side_{action}_{i:02}.png'
            dest = ref_dir / src.name
            shutil.copy2(src, dest)
            hashes[dest.name] = hashlib.sha256(dest.read_bytes()).hexdigest()
    dump(ROOT / 'source/parts_registration.json', records)
    dump(ROOT / 'source/reference_hashes.json', hashes)


# All bones have an unrotated rest transform. Their visual bone angle is separate
# from their transform. Local keyframes rotate the real Bone2D hierarchy.
BONES = [
    ('Pelvis', None, (63, 84), 9, -90),
    ('Spine', 'Pelvis', (0, -9), 13, -90),
    ('Chest', 'Spine', (-1, -13), 6, -90),
    ('Neck', 'Chest', (0, -6), 3, -90),
    ('Head', 'Neck', (0, -3), 19, -90),
    ('Scarf', 'Chest', (4, -5), 10, 60),
    ('FarUpperArm', 'Chest', (4.5, 2), 10.5, 90),
    ('FarForearm', 'FarUpperArm', (0, 10.5), 9, 90),
    ('FarHand', 'FarForearm', (0, 9), 4, 90),
    ('NearUpperArm', 'Chest', (-2.5, 2), 10.5, 90),
    ('NearForearm', 'NearUpperArm', (0, 10.5), 9, 90),
    ('NearHand', 'NearForearm', (0, 9), 4, 90),
    ('FarThigh', 'Pelvis', (2, 0), 10, 90),
    ('FarShin', 'FarThigh', (0, 10), 10, 90),
    ('FarFoot', 'FarShin', (0, 10), 9, 0),
    ('NearThigh', 'Pelvis', (-1, 0), 10, 90),
    ('NearShin', 'NearThigh', (0, 10), 10, 90),
    ('NearFoot', 'NearShin', (0, 10), 9, 0),
]
PARENT = {b[0]: b[1] for b in BONES}
REST_LOCAL = {b[0]: np.array(b[2], dtype=float) for b in BONES}
PATHS = {}
REST_GLOBAL = {}
for name, parent, pos, length, angle in BONES:
    PATHS[name] = (PATHS[parent] + '/' if parent else '') + name
    REST_GLOBAL[name] = REST_LOCAL[name] + (REST_GLOBAL[parent] if parent else np.zeros(2))


def part_mesh(name, art, height, anchor, art_anchor, z, bones, weights, garment=-1, shade=1.0):
    im = Image.open(ASSETS / f'{art}.png')
    scale = height / (im.height-4)
    width = (im.width-4)*scale
    left = anchor[0] - art_anchor[0]*width - 2*scale
    top = anchor[1] - art_anchor[1]*height - 2*scale
    w, h = im.width*scale, im.height*scale
    # Regular UV mesh with internal triangulation; knees/elbows contain many rows.
    cols, rows = 4, 18 if art in ['arm', 'leg'] else 12
    points, uv = [], []
    for iy in range(rows+1):
        for ix in range(cols+1):
            points.append((left + w*ix/cols, top + h*iy/rows))
            uv.append((im.width*ix/cols, im.height*iy/rows))
    triangles = []
    for iy in range(rows):
        for ix in range(cols):
            a = iy*(cols+1)+ix
            b, c, d = a+1, a+cols+1, a+cols+2
            triangles.extend([(a, b, d), (a, d, c)])
    ws = np.array([weights(x, y) for x, y in points])
    assert np.max(np.abs(ws.sum(axis=1)-1)) < 1e-7
    return dict(name=name, art=art, points=points, uv=uv, triangles=triangles,
                bones=bones, weights=ws.T.tolist(), z=z, garment=garment, shade=shade,
                rest_bounds=[left, top, w, h])


def constant(n):
    return lambda x, y: [1.0] if n == 1 else [1.0]+[0.0]*(n-1)


def chain_weights(joint, wrist):
    def weights(x, y):
        fore = float(smooth(joint-2.0, joint+2.0, y))
        hand = float(smooth(wrist-1.2, wrist+1.2, y))
        return [1-fore, fore*(1-hand), fore*hand]
    return weights


def torso_weights(x, y):
    low = float(smooth(70, 82, y))
    upper = float(smooth(73, 62, y))
    return [low, (1-low)*(1-upper), (1-low)*upper]


def make_meshes():
    meshes = []
    for side, z, shade in [('Far', -6, 0.91), ('Near', 3, 1.0)]:
        hip = REST_GLOBAL[side+'Thigh']
        arm = REST_GLOBAL[side+'UpperArm']
        foot = REST_GLOBAL[side+'Foot']
        meshes.append(part_mesh(side+'Leg', 'leg', 24, hip, (.48, 2/24), z,
                                [side+'Thigh', side+'Shin', side+'Foot'], chain_weights(94, 104), shade=shade))
        meshes.append(part_mesh(side+'Boot', 'boot', 12, foot, (.38, 4/12), z+1,
                                [side+'Foot'], constant(1), shade=shade))
        meshes.append(part_mesh(side+'Arm', 'arm', 27.5, arm, (.42, .12), -9 if side=='Far' else 18,
                                [side+'UpperArm', side+'Forearm', side+'Hand'], chain_weights(74.5, 83.5), shade=shade))
        for outfit, art, height in [(0, 'olive_sleeve', 14.7), (1, 'teal_sleeve', 16.0)]:
            meshes.append(part_mesh(side+art.title().replace('_',''), art, height,
                                    arm, (.48, .21), -8 if side=='Far' else 19,
                                    [side+'UpperArm', side+'Forearm', side+'Hand'],
                                    chain_weights(74.5, 83.5), garment=outfit, shade=shade))
    meshes.append(part_mesh('Shorts', 'shorts', 14.5, (63, 83), (.48, .38), 6,
                            ['Pelvis'], constant(1)))
    meshes.append(part_mesh('BaseBody', 'base', 28.0, (65, 56), (.52, .04), 0,
                            ['Pelvis', 'Spine', 'Chest'], torso_weights))
    for outfit, art in [(0, 'olive_torso'), (1, 'teal_torso')]:
        meshes.append(part_mesh(art.title().replace('_',''), art, 27.0, (66, 57), (.52, .05), 7,
                                ['Pelvis', 'Spine', 'Chest'], torso_weights, garment=outfit))
    meshes.append(part_mesh('Scarf', 'scarf', 15.5, (65.5, 56.0), (.38, .20), 12,
                            ['Chest', 'Scarf'], lambda x,y: [1-float(smooth(58,66,y)),float(smooth(58,66,y))]))
    meshes.append(part_mesh('Head', 'head', 37.5, (62, 53), (.53, .94), 15,
                            ['Head'], constant(1)))
    return meshes


def solve_leg(hip, target):
    # The sole travels on a straight stance path. Analytic two-bone IK is baked
    # once into editable angle keys, not evaluated by runtime movement scripts.
    dx, dy = target[0]-hip[0], target[1]-hip[1]
    dist = min(19.98, math.hypot(dx,dy))
    theta = math.atan2(dx,dy)
    bend = math.acos(dist/20)
    upper = -(theta+bend)
    lower = 2*bend  # knee always bends backwards; knee itself points forward.
    return upper, lower


def foot_target(phase, hip_x):
    p = phase % 1.0
    if p < .5:
        # Constant sole speed over the entire stance (hip/body stays centered).
        return np.array([hip_x + 8.0 - 32.0*p, 104.0]), 0.0, True
    q = (p-.5)*2
    # Low swing arc, with a little toe clearance. 2.6 px is deliberately modest.
    q_ease = q*q*(3-2*q)
    return np.array([hip_x-8.0+16.0*q_ease, 104.0-2.0*math.sin(math.pi*q)**1.4]), math.radians(-7*math.sin(math.pi*q)), False


def pose(action, phase):
    vals = {name: {'position': p.copy(), 'rotation': 0.0, 'scale': np.ones(2)} for name,p in REST_LOCAL.items()}
    if action == 'walk':
        bob = 1.8 + .4*math.cos(2*TAU*phase)
        vals['Pelvis']['position'][1] += bob
        vals['Spine']['rotation'] = math.radians(-1.1 + .6*math.sin(TAU*phase))
        vals['Chest']['rotation'] = math.radians(1.1 - .6*math.sin(TAU*phase))
        vals['Head']['rotation'] = math.radians(.6*math.sin(TAU*phase+.3))
        for side, ph in [('Near', phase), ('Far', phase+.5)]:
            hip = REST_GLOBAL[side+'Thigh'] + np.array([0,bob])
            target, foot_angle, _ = foot_target(ph, hip[0])
            upper, lower = solve_leg(hip,target)
            vals[side+'Thigh']['rotation'] = upper
            vals[side+'Shin']['rotation'] = lower
            vals[side+'Foot']['rotation'] = foot_angle-upper-lower
            vals[side+'UpperArm']['rotation'] = math.radians(17*math.cos(TAU*ph))
            vals[side+'Forearm']['rotation'] = math.radians(-8-5*math.sin(TAU*ph))
            vals[side+'Hand']['rotation'] = math.radians(3*math.sin(TAU*ph))
        vals['Scarf']['rotation'] = math.radians(2.2*math.sin(TAU*phase-.6))
    elif action in ['breathe','wave']:
        breath = math.sin(TAU*phase) if action=='breathe' else .25*math.sin(TAU*phase)
        # Pelvis, legs and foot transforms remain exactly at rest.
        vals['Chest']['position'][1] -= .30*breath
        vals['Chest']['scale'] = np.array([1+.007*breath,1+.007*breath])
        vals['Head']['rotation'] = math.radians(.32*breath)
        vals['NearForearm']['rotation'] = math.radians(-4)
        vals['FarForearm']['rotation'] = math.radians(-4)
        vals['Scarf']['rotation'] = math.radians(.8*breath)
        if action=='wave':
            # Ease in, wave twice at the wrist, then return to the same neutral.
            up = float(smooth(0,.22,phase))*(1-float(smooth(.78,1,phase)))
            flutter = math.sin((phase-.22)/.56*TAU*2) if .22<phase<.78 else 0.0
            vals['NearUpperArm']['position'] += np.array([1.4*up,-1.0*up])
            vals['NearUpperArm']['rotation'] = math.radians(-110*up)
            vals['NearForearm']['rotation'] = math.radians(-4-10*up)
            vals['NearHand']['rotation'] = math.radians(up*(-25+22*flutter))
            vals['Head']['rotation'] += math.radians(1.2*up)
    return vals


def transform_globals(vals):
    out = {}
    for name,parent,_,_,_ in BONES:
        angle = vals[name]['rotation']
        c,s = math.cos(angle),math.sin(angle)
        local = np.array([[c,-s,vals[name]['position'][0]], [s,c,vals[name]['position'][1]], [0,0,1]])
        local[:2,:2] = local[:2,:2] @ np.diag(vals[name]['scale'])
        out[name] = out[parent]@local if parent else local
    return out


def animation_resource(action, duration, samples):
    all_poses = [pose(action, i/samples) for i in range(samples+1)]
    lines = [f'[sub_resource type="Animation" id="Animation_{action}"]', f'resource_name = "{action}"',
             f'length = {f(duration)}', 'loop_mode = 1']
    track=0
    for name,_,_,_,_ in BONES:
        for prop in ['position','rotation','scale']:
            values = [p[name][prop] for p in all_poses]
            # Keep reset pose values on every bone/property so switching actions
            # cannot leave behind a waved arm or a breathing scale.
            varying = any(np.max(np.abs(np.asarray(v)-np.asarray(values[0])))>1e-7 for v in values)
            indexes = list(range(samples+1)) if varying else [0]
            times = [duration*i/samples for i in indexes]
            # RESET numeric keys must be FLOATs as well. Integer zero reset keys
            # make AnimationMixer quantize an entire rotation track to radians.
            txtvalues = [real(values[i]) if prop=='rotation' else vec(values[i]) for i in indexes]
            lines.extend([f'tracks/{track}/type = "value"', f'tracks/{track}/path = NodePath("Skeleton2D/{PATHS[name]}:{prop}")',
                          f'tracks/{track}/interp = 1', f'tracks/{track}/loop_wrap = true',
                          f'tracks/{track}/enabled = true', f'tracks/{track}/keys = {{',
                          '"times": '+arr('PackedFloat32Array', times)+',',
                          '"transitions": '+arr('PackedFloat32Array', [1]*len(indexes))+',',
                          '"update": 0,', '"values": ['+', '.join(txtvalues)+']', '}'])
            track+=1
    return '\n'.join(lines)+'\n'


def write_scene(meshes):
    art_names = sorted(set(m['art'] for m in meshes))
    ids = {n:str(i+2) for i,n in enumerate(art_names)}
    lines = ['[gd_scene format=3]', '[ext_resource type="Script" path="res://rig.gd" id="1"]']
    for n in art_names:
        lines.append(f'[ext_resource type="Texture2D" path="res://art/{n}.png" id="{ids[n]}"]')
    for name,duration,samples in [('walk',8/13.8,64),('breathe',1.8,32),('wave',2.4,64),('RESET',.1,1)]:
        lines.append(animation_resource(name,duration,samples))
    lines += ['[sub_resource type="AnimationLibrary" id="AnimationLibrary_main"]', '_data = {',
              ',\n'.join(f'&"{n}": SubResource("Animation_{n}")' for n in ['RESET','walk','breathe','wave']), '}',
              '[node name="HeroRig" type="Node2D"]', 'script = ExtResource("1")',
              '[node name="Skeleton2D" type="Skeleton2D" parent="."]']
    for name,parent,pos,length,angle in BONES:
        nodeparent = 'Skeleton2D' + ('/'+PATHS[parent] if parent else '')
        lines += [f'[node name="{name}" type="Bone2D" parent="{nodeparent}"]', f'position = {vec(pos)}',
                  f'rest = Transform2D(1, 0, 0, 1, {f(pos[0])}, {f(pos[1])})',
                  'auto_calculate_length_and_angle = false',
                  f'length = {f(length)}', f'bone_angle = {f(angle)}']
    lines.append('[node name="Meshes" type="Node2D" parent="."]')
    for m in sorted(meshes,key=lambda m:m['z']):
        lines += [f'[node name="{m["name"]}" type="Polygon2D" parent="Meshes"]', f'z_index = {m["z"]+12}',
                  'texture_filter = 4',
                  f'visible = {"false" if m["garment"]==1 else "true"}',
                  f'color = Color({f(m["shade"])}, {f(m["shade"])}, {f(m["shade"])}, 1)',
                  f'texture = ExtResource("{ids[m["art"]]}")', 'skeleton = NodePath("../../Skeleton2D")',
                  'polygon = '+arr('PackedVector2Array',[v for p in m['points'] for v in p]),
                  'uv = '+arr('PackedVector2Array',[v for p in m['uv'] for v in p]),
                  'polygons = ['+', '.join(arr('PackedInt32Array',tri) for tri in m['triangles'])+']',
                  'bones = ['+', '.join('NodePath("'+PATHS[b]+'"), '+arr('PackedFloat32Array',w) for b,w in zip(m['bones'],m['weights']))+']',
                  f'metadata/outfit = {m["garment"]}']
    lines += ['[node name="AnimationPlayer" type="AnimationPlayer" parent="."]',
              'libraries = { &"": SubResource("AnimationLibrary_main") }']
    (ROOT/'hero_rig.tscn').write_text('\n\n'.join(lines)+'\n',encoding='utf-8')
    dump(ROOT/'source/rig_manifest.json', {'canvas':[128,128], 'foot_origin':[64,112],
         'skeleton': [{'name':n,'parent':p,'rest_position':pos,'length':l} for n,p,pos,l,a in BONES],
         'meshes':[{'name':m['name'],'texture':m['art'],'vertices':len(m['points']),
                    'triangles':len(m['triangles']),'bones':m['bones'],'outfit':m['garment'],
                    'rest_bounds':m['rest_bounds']} for m in meshes],
         'animation_durations':{'walk':8/13.8,'breathe':1.8,'wave':2.4},
         'runtime':'native saved Bone2D keyframes and Polygon2D skin weights; no runtime procedural rig generation'})


def main():
    prepare_parts()
    meshes=make_meshes()
    write_scene(meshes)
    for config in ASSETS.glob('*.png.import'):
        text = config.read_text(encoding='utf-8')
        config.write_text(text.replace('mipmaps/generate=false', 'mipmaps/generate=true'), encoding='utf-8')
    print(f'Authored {len(BONES)} bones, {len(meshes)} weighted meshes, 3 clips + RESET')


if __name__=='__main__':
    main()
