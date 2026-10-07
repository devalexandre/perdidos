#!/usr/bin/env python3
"""Build four deterministic cave scenes. Floor, collision and navigation share one footprint."""
from pathlib import Path
import math
import random

import worldgen as wg

wg.install()  # writes go through worldgen (--check = dry run + validation)

GAME = Path(__file__).resolve().parents[2]
BASE = 'cave_reino_encoberto'
def map_id(n): return BASE + (f'_{n}' if n > 1 else '')
# Chamber centers/radii and connecting polylines. X/Z coordinates, surface at y=0.
LAYOUTS = {
1: ([(0,30,9),(-20,12,11),(20,12,10),(-24,-16,12),(24,-16,12),(0,-30,8)],
    [[(0,30),(-20,12),(-24,-16),(0,-30)],[(0,30),(20,12),(24,-16),(0,-30)],[(-24,-16),(-12,-4),(12,-4),(24,-16)]], 3.5),
2: ([(0,30,7),(-26,18,7),(26,18,8),(-26,-24,8),(26,-24,8),(0,-8,9)],
    [[(0,30),(-26,30),(-26,18),(-12,18),(-12,2),(-26,2),(-26,-24)],[(0,30),(26,30),(26,18),(12,18),(12,0),(26,0),(26,-24)],[(-26,-24),(-26,-10),(0,-8),(26,-10),(26,-24)]], 2.5),
3: ([(0,30,8),(-28,8,10),(28,8,9),(-24,-24,10),(24,-24,10),(0,-8,7),(0,-38,6)],
    [[(0,30),(-28,8),(-24,-24)],[(0,30),(28,8),(24,-24)],[(-28,8),(0,-8),(28,8)],[(-24,-24),(0,-38),(24,-24)]], 2.0),
4: ([(0,30,8),(-26,8,10),(26,8,10),(0,-16,22),(-34,-22,7),(34,-22,7)],
    [[(0,30),(-26,8),(-20,-16)],[(0,30),(26,8),(20,-16)],[(-26,8),(-34,-22),(0,-16)],[(26,8),(34,-22),(0,-16)]], 3.0)
}

def dist_segment(p,a,b):
    dx,dz=b[0]-a[0],b[1]-a[1]
    t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/(dx*dx+dz*dz)))
    return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dz)

def build(n):
    rooms, routes, width = LAYOUTS[n]
    cells=set()
    for x in range(-44,44,2):
        for z in range(-48,42,2):
            p=(x+1,z+1)
            if any(math.hypot(p[0]-cx,p[1]-cz)<r for cx,cz,r in rooms) or any(dist_segment(p,a,b)<width for route in routes for a,b in zip(route,route[1:])):
                cells.add((x,z))
    # Explicit blocked pillars in wide chambers, not just decorative obstacles.
    pillars = [(-20,12),(20,12)] if n==1 else ([(0,-8)] if n==2 else ([(0,-16)] if n==4 else []))
    cells={p for p in cells if all(math.hypot(p[0]+1-x,p[1]+1-z)>3.2 for x,z in pillars)}
    resources=[]; nodes=[]
    def res(kind,key,body): resources.append(f'[sub_resource type="{kind}" id="{key}"]\n{body}\n')
    def node(name,kind,parent='.',body=''): nodes.append(f'[node name="{name}" type="{kind}"'+(f' parent="{parent}"' if parent else '')+f']\n{body}\n')
    def marker(name,pos,parent='.',meta=''):
        node(name,'Marker3D',parent,f'position = Vector3({pos[0]}, 0, {pos[1]})\n'+meta)
    node(map_id(n),'Node3D','',f'script = ExtResource("cave")\nmap_id = &"{map_id(n)}"\nfloor_number = {n}')
    res('Environment','environment',f'''background_mode = 1
background_color = Color(0.008, 0.016, 0.027, 1)
ambient_light_source = 2
ambient_light_color = Color(0.38, 0.57, 0.7, 1)
ambient_light_energy = {0.65-n*0.045}
fog_enabled = true
fog_light_color = Color(0.025, 0.06, 0.08, 1)
fog_density = 0.002''')
    node('WorldEnvironment','WorldEnvironment',body='environment = SubResource("environment")')
    node('Floor','Node3D'); node('Decor','Node3D'); node('Interactables','Node3D'); node('Spawns','Node3D'); node('NpcPoints','Node3D')
    # Merge floor tiles by row for inexpensive geometry/collisions; nav tiles retain shared edges.
    row_id=0
    for z in sorted({z for x,z in cells}):
        xs=sorted(x for x,zz in cells if zz==z); runs=[]
        for x in xs:
            if runs and runs[-1][-1]+2==x: runs[-1].append(x)
            else: runs.append([x])
        for run in runs:
            key=f'floor_{row_id}'; length=len(run)*2
            res('BoxMesh',key,f'size = Vector3({length}, 3, 2)')
            res('BoxShape3D',key+'_shape',f'size = Vector3({length}, 3, 2)')
            node(key,'StaticBody3D','Floor',f'position = Vector3({run[0]+length/2}, -1.5, {z+1})\ncollision_layer = 1\ncollision_mask = 0')
            node('Surface','MeshInstance3D','Floor/'+key,f'mesh = SubResource("{key}")\nmaterial_override = ExtResource("gravel")')
            node('Collision','CollisionShape3D','Floor/'+key,f'shape = SubResource("{key}_shape")')
            row_id+=1
    verts=[]; vertex_ids={}; polys=[]
    for x,z in sorted(cells):
        poly=[]
        for v in [(x,z),(x,z+2),(x+2,z+2),(x+2,z)]:
            if v not in vertex_ids: vertex_ids[v]=len(verts); verts.append(v)
            poly.append(vertex_ids[v])
        polys.append('PackedInt32Array('+', '.join(map(str,poly))+')')
    res('NavigationMesh','nav','cell_size = 0.2\ncell_height = 0.2\nvertices = PackedVector3Array('+', '.join(f'{x}, 0, {z}' for x,z in verts)+')\npolygons = Array[PackedInt32Array](['+', '.join(polys)+'])')
    node('NavigationRegion3D','NavigationRegion3D',body='navigation_mesh = SubResource("nav")')
    marker('SpawnPoint',(0,30)); marker('CaveReturn',(0,30))
    marker('WestArrival',(-24,-18) if n==1 else (-24,-20))
    marker('EastArrival',(24,-18) if n==1 else (24,-20))
    marker('NorthArrival',(-24,-18) if n==1 else (-24,-20))
    if n==1: marker('CaveHowl',(0,-30))
    node('Viewpoint1','Marker3D',body='position = Vector3(0, 62, 52)\nrotation_degrees = Vector3(-52, 0, 0)')
    # Rock silhouettes on the unwalkable side of each boundary; deep floors expose the abyss.
    rng=random.Random(731+n)
    boundary=sorted({(x+dx,z+dz) for x,z in cells for dx,dz in [(2,0),(-2,0),(0,2),(0,-2)] if (x+dx,z+dz) not in cells})
    for i,(x,z) in enumerate(boundary):
        if i%3: continue
        sy=rng.uniform(7.0,11.0) if n<3 else rng.uniform(2.0,4.0)
        node(f'Rock{i}','MeshInstance3D','Decor',f'position = Vector3({x+1}, -0.4, {z+1})\nscale = Vector3(2.4, {sy}, 2.4)\nrotation_degrees = Vector3(0, {rng.randrange(360)}, 0)\nmesh = ExtResource("rock")\nmaterial_override = ExtResource("rock_mat")')
    for i,(x,z) in enumerate(pillars):
        node(f'Pillar{i}','MeshInstance3D','Decor',f'position = Vector3({x}, -0.5, {z})\nscale = Vector3(3, 8, 3)\nmesh = ExtResource("rock")\nmaterial_override = ExtResource("rock_mat")')
    res('StandardMaterial3D','crystal_mat','albedo_color = Color(0.1, 0.7, 0.72, 1)\nemission_enabled = true\nemission = Color(0.07, 0.42, 0.55, 1)\nemission_energy_multiplier = 1.4')
    for i,(x,z,r) in enumerate(rooms):
        node(f'Crystal{i}','MeshInstance3D','Decor',f'position = Vector3({x+r-2}, 0, {z})\nmesh = ExtResource("crystal")\nmaterial_override = SubResource("crystal_mat")')
        node(f'Glow{i}','OmniLight3D','Decor',f'position = Vector3({x}, 4, {z})\nlight_color = Color(0.15, 0.65, 0.85, 1)\nlight_energy = 1.3\nomni_range = {r+8}')
        if n<3:
            node(f'Moss{i}','MeshInstance3D','Decor',f'position = Vector3({x-r+3}, 0, {z})\nmesh = ExtResource("fern")\nmaterial_override = ExtResource("moss")')
            node(f'Mushrooms{i}','MeshInstance3D','Decor',f'position = Vector3({x+r-3}, 0, {z+2})\nmesh = ExtResource("mushroom")\nmaterial_override = SubResource("crystal_mat")')
    if n<3:
        node('EntranceLight','SpotLight3D',body=f'position = Vector3(0, 16, 30)\nrotation_degrees = Vector3(-90, 0, 0)\nlight_color = Color(0.7, 0.8, 0.65, 1)\nlight_energy = {3 if n==1 else 1}\nspot_range = 28\nspot_angle = 28')
    res('BoxShape3D','portal_shape','size = Vector3(4, 4, 3)')
    def portal(name,id,pos,dest,spawn,label,gate=False):
        node(name,'Area3D','Interactables',f'''position = Vector3({pos[0]}, 1, {pos[1]})
collision_layer = 2
collision_mask = 0
monitoring = false
monitorable = false
metadata/interact_id = &"{id}"
metadata/target_id = "m:{id}"
metadata/interact_type = &"portal"
metadata/target_map = &"{dest}"
metadata/target_spawn = &"{spawn}"
metadata/approach_position = Vector3({pos[0]}, 0, {pos[1]})
metadata/one_way = {'true' if gate else 'false'}
metadata/requires_boss_victory = {'true' if gate else 'false'}''')
        node('Shape','CollisionShape3D','Interactables/'+name,'shape = SubResource("portal_shape")')
        node('Name','Label3D','Interactables/'+name,f'position = Vector3(0, 3, 0)\nbillboard = 1\nfont_size = 42\npixel_size = 0.015\ntext = "{label}"')
    portal('ReturnPortal','cave_return',(0,34),'enchanted_forest_roots' if n==1 else map_id(n-1),'CaveReturn' if n==1 else 'WestArrival', 'Superfície ↑' if n==1 else f'↑ F{n-1}')
    if n<4:
        for side,x in [('West',-24),('East',24)]:
            portal(side+'Descent',f'cave_deeper_{n}' if side=='West' else f'cave_east_{n}',(x,-24),map_id(n+1),'SpawnPoint' if side=='West' else 'EastEntry',f'↓ F{n+1} · '+('Oeste' if side=='West' else 'Leste'))
    marker('EastEntry',(22,12) if n==1 else ((26,18) if n==2 else ((28,8) if n==3 else (26,8))))
    if n>1:
        portal('EastReturn','cave_east_return',(32,18) if n==2 else (34,8),map_id(n-1),'EastArrival',f'↑ F{n-1} · Leste')
    if n==4:
        node('BossLairs','Node3D')
        marker('werewolf',(0,-24),'BossLairs','metadata/monster_id = &"cave_werewolf"\nmetadata/radius_cells = 7\nmetadata/respawn_sec = 600.0')
        portal('SurfaceEscapePortal','cave_surface_escape',(34,-22),'enchanted_forest_roots','CaveReturn','Fenda de Luz · Superfície',True)
        res('CylinderMesh','altar','top_radius = 3\nbottom_radius = 4\nheight = 1.5')
        node('AncientAltar','MeshInstance3D','Decor','position = Vector3(0, -0.2, -16)\nmesh = SubResource("altar")\nmaterial_override = ExtResource("rock_mat")')
    safe_entries=[(0,30),(-24,-18 if n==1 else -20),(24,-18 if n==1 else -20),
                  (22,12) if n==1 else ((26,18) if n==2 else (28,8))]
    floor_spawns = {
        1: [('cave_bat', 1, 3), ('cave_skeleton', 1, 2), ('cave_firefly', 1, 3), ('cave_bat', 1, 2), ('cave_skeleton', 1, 3)],
        2: [('cave_skeleton', 1, 3), ('cave_zombie', 1, 2), ('cave_bat', 2, 3), ('cave_skeleton', 2, 2), ('cave_zombie', 1, 2)],
        3: [('cave_skeleton', 2, 3), ('cave_zombie', 2, 3), ('cave_werewolf', 1, 2), ('cave_bat', 2, 3), ('cave_zombie', 2, 2)],
        4: [('cave_werewolf', 2, 2), ('cave_skeleton', 2, 3), ('cave_zombie', 2, 3), ('cave_werewolf', 2, 2), ('cave_bat', 2, 3)],
    }
    for i,(x,z,r) in enumerate(rooms[1:]):
        if n==4 and i==1: continue
        sp_list = floor_spawns[n]
        species, stage, count = sp_list[i % len(sp_list)]
        candidates=[(cx+1,cz+1) for cx,cz in cells
                    if math.hypot(cx+1-x,cz+1-z)<r-1
                    and all(math.hypot(cx+1-a,cz+1-b)>14 for a,b in safe_entries)]
        if not candidates: continue
        pack=min(candidates,key=lambda p:math.hypot(p[0]-x-4,p[1]-z))
        marker(f'Pack{i}',pack,'Spawns',f'metadata/monster_id = &"{species}"\nmetadata/stage = {stage}\nmetadata/count = {count}\nmetadata/radius_cells = 3\nmetadata/respawn_sec = 120.0')
    ext='''[ext_resource type="Script" path="res://scripts/shared/cave_level.gd" id="cave"]
[ext_resource type="Material" path="res://assets/environment/painted/materials/mat_ground_gravel.tres" id="gravel"]
[ext_resource type="Material" path="res://assets/environment/painted/materials/mat_rock.tres" id="rock_mat"]
[ext_resource type="Material" path="res://assets/environment/painted/materials/mat_rock_moss.tres" id="moss"]
[ext_resource type="ArrayMesh" path="res://assets/environment/painted/meshes/rock_moss_a.res" id="rock"]
[ext_resource type="ArrayMesh" path="res://assets/environment/painted/meshes/crystal_cluster.res" id="crystal"]
[ext_resource type="ArrayMesh" path="res://assets/environment/painted/meshes/fern.res" id="fern"]
[ext_resource type="ArrayMesh" path="res://assets/environment/painted/meshes/pk_mushroom.res" id="mushroom"]
'''
    (GAME/'scenes/maps'/f'{map_id(n)}.tscn').write_text(f'[gd_scene load_steps={len(resources)+9} format=3]\n\n'+ext+'\n'+'\n'.join(resources+nodes))
    print(map_id(n),len(cells),'walkable tiles',row_id,'floor strips')

if __name__=='__main__':
    for n in range(1,5): build(n)
    wg.finish([map_id(n) for n in range(1, 5)], 'cave')
