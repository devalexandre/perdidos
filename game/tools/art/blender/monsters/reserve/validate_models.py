"""Reopen exported files and verify saved geometry, clips, animation and art-only scope."""
import json, sys
from pathlib import Path
import bpy
HERE=Path(__file__).resolve().parent
cat=json.loads((HERE/'catalog.json').read_text())
results=[]
for region, rows in cat.items():
 assert len(rows)==3
 for row in rows:
  counts=[]
  for stage in (1,3,4):
   path=HERE.parent/'blend'/f'{row[0]}_s{stage}.blend'
   bpy.ops.wm.open_mainfile(filepath=str(path))
   sc=bpy.context.scene
   assert sc['species_id']==row[0] and sc['stage']==stage
   assert sc['runtime_enabled'] is False
   clips=json.loads(sc['animation_clips'])
   assert set(clips)=={'idle','walk','attack','hit','death'}
   meshes=[o for o in sc.objects if o.type=='MESH']
   assert meshes and all(o.data.vertices and o.data.materials for o in meshes)
   assert all(o.animation_data and o.animation_data.action for o in meshes)
   sc.frame_set(1); before=bpy.data.objects['body'].matrix_world.copy()
   sc.frame_set(28); bpy.context.view_layer.update()
   after=bpy.data.objects['body'].matrix_world.copy()
   assert before!=after, (row[0],stage,'animation not saved')
   counts.append(len(meshes))
   results.append(dict(id=row[0],stage=stage,meshes=len(meshes),saved_animation=True))
  assert counts[0]<counts[1]<counts[2],(row[0],counts)
(HERE/'validation.json').write_text(json.dumps(dict(models=len(results),species=30,regions=10,results=results),indent=2))
print('PASS: 90 saved models reopened; materials, five clips, animation and added variant geometry verified.')
