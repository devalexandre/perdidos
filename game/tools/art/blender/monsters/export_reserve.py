"""Export regional art-only models alongside native .blend files.
Run: xvfb-run -a .tools/blender/blender -b --python .../export_reserve.py -- [species ...]
Each file contains editable meshes, pivot rig, materials and five baked timeline clips.
The native render_monster.py also accepts each species module (stages 1,3,4).
"""
import sys, json, math
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import bpy
from mathutils import Vector
import reserve_species as S
COLORS=json.loads((HERE/'reserve/materials.json').read_text())
OUT=HERE/'blend'
PREVIEW=HERE/'reserve/previews'
OUT.mkdir(exist_ok=True); PREVIEW.mkdir(exist_ok=True)
selected=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(S.SPECIES)
report=[]
for species in selected:
 for stage in S.STAGES:
    rig=S.build(species,stage)
    assert all(info['mat'] in COLORS for info in rig.part_info[1:]), species
    for obj in rig.meshes:
        info=rig.part_info[int(obj['pid'])]
        color=COLORS[info['mat']]
        mat=bpy.data.materials.get('color_'+info['mat']) or bpy.data.materials.new('color_'+info['mat'])
        mat.diffuse_color=(*color,1)
        obj.data.materials.clear(); obj.data.materials.append(mat)
        obj['palette_material']=info['mat']
        assert len(obj.data.vertices)>0
    sc=bpy.context.scene
    sc.render.fps=10
    clips={}; start=1
    for anim,n in S.ANIMS:
        clips[anim]=[start,start+n-1]
        sc.timeline_markers.new(anim,frame=start)
        for i in range(n):
            rig.reset_pose(); S.pose(rig,anim,i,n,stage)
            for obj in rig.nodes.values():
                for prop in ('location','rotation_euler','scale'):
                    assert all(math.isfinite(v) for v in getattr(obj,prop))
                    obj.keyframe_insert(data_path=prop,frame=start+i,group=anim)
        start+=n+4
    sc.frame_start=1; sc.frame_end=start-5
    sc['animation_clips']=json.dumps(clips)
    sc['species_id']=species; sc['stage']=stage; sc['runtime_enabled']=False
    sc['display_name']=S.SPECIES[species][{1:1,3:2,4:3}[stage]]
    sc['provenance']=S.SPECIES[species][7]
    sc.frame_set(1)
    bpy.context.view_layer.update()
    points=[obj.matrix_world @ Vector(v) for obj in rig.meshes for v in obj.bound_box]
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    target=(lo+hi)/2
    data=bpy.data.cameras.new('ReviewCamera'); cam=bpy.data.objects.new('ReviewCamera',data)
    sc.collection.objects.link(cam); sc.camera=cam
    cam.location=target+Vector((3,-6,4))
    cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    data.type='ORTHO'; data.ortho_scale=max(hi-lo)*1.65
    sc.render.engine='BLENDER_WORKBENCH'
    sc.display.shading.light='STUDIO'; sc.display.shading.color_type='MATERIAL'
    sc.display.shading.show_shadows=True; sc.display.shading.show_cavity=True
    sc.display.shading.cavity_type='BOTH'; sc.display.shading.show_object_outline=True
    sc.display.shading.background_type='WORLD'; sc.world.color=(.065,.075,.1)
    sc.render.film_transparent=False
    sc.render.resolution_x=384; sc.render.resolution_y=384; sc.render.resolution_percentage=100
    sc.render.image_settings.file_format='PNG'; sc.view_settings.view_transform='Standard'
    # Keep the saved rig in canonical orientation; the review camera is separate.
    bpy.context.preferences.filepaths.save_version=0
    path=OUT/f'{species}_s{stage}.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)
    sc.render.filepath=str(PREVIEW/f'{species}_s{stage}.png')
    bpy.ops.render.render(write_still=True)
    report.append(dict(id=species,stage=stage,meshes=len(rig.meshes),clips=clips,blend=str(path.relative_to(HERE)),preview=str(Path(sc.render.filepath).relative_to(HERE))))
    print('[reserve] READY',species,stage,flush=True)
(HERE/'reserve'/('report_'+selected[0]+'.json')).write_text(json.dumps(report,indent=2))
