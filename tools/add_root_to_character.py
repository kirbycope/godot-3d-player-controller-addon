import bpy
import sys
import argparse
from pathlib import Path

def add_root_bone(source_file: Path, dest_file: Path):
    """
    Imports a character mesh, injects a Root bone at the origin,
    parents the Hips to it, and exports a Godot-ready GLB.
    """
    if not source_file.exists():
        print(f"[Error] Source file not found: {source_file}")
        return

    dest_file.parent.mkdir(parents=True, exist_ok=True)
    
    print(f"Processing character model: {source_file.name}...")
    
    # 1. Clear scene
    bpy.ops.wm.read_factory_settings(use_empty=True)
    
    # 2. Import Character
    if source_file.suffix.lower() == '.fbx':
        bpy.ops.import_scene.fbx(filepath=str(source_file))
    else:
        bpy.ops.import_scene.gltf(filepath=str(source_file))
        
    # 3. Find Armature
    armature = next((obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE'), None)
    if not armature:
        print("[Error] No armature found in the character file.")
        return
        
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode='EDIT')
    
    # 4. Find Hips (Accounting for 'mixamorig_Hips' from your bone map)
    hips_bone = armature.data.edit_bones.get("mixamorig_Hips") or next(
        (b for b in armature.data.edit_bones if 'Hips' in b.name), None
    )
    
    if not hips_bone:
        print("[Error] Could not locate Hips bone to parent.")
        return
        
    # 5. Create the Root Bone at Origin
    root_bone = armature.data.edit_bones.new('Root')
    root_bone.head = (0, 0, 0)
    root_bone.tail = (0, 0, 0.1) # Point slightly upwards in Blender space
    
    # Establish hierarchy
    hips_bone.parent = root_bone
    
    # 6. Switch back to Object Mode and Export
    bpy.ops.object.mode_set(mode='OBJECT')
    
    bpy.ops.export_scene.gltf(
        filepath=str(dest_file),
        export_format='GLB',
        use_selection=False,
        export_yup=True
    )
    print(f"[Success] Exported modified character with Root bone to: {dest_file}")

if __name__ == "__main__":
    if "--" in sys.argv:
        argv = sys.argv[sys.argv.index("--") + 1:]
    else:
        argv = []
        
    parser = argparse.ArgumentParser(description="Inject Root Bone into Character Base Mesh")
    parser.add_argument("--source", default="addons/3d_player_controller/assets/mixamo/characters/y_bot.fbx", help="Path to raw character FBX")
    parser.add_argument("--dest", default="addons/3d_player_controller/assets/mixamo/characters/y_bot_root.glb", help="Path to output GLB")
    
    args = parser.parse_args(argv)
    
    bake_source = Path.cwd() / args.source
    bake_dest = Path.cwd() / args.dest
    
    add_root_bone(bake_source, bake_dest)

    # blender --background --python tools/add_root_to_character.py