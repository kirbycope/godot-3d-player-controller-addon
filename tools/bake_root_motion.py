import bpy
import sys
import argparse
from pathlib import Path

def bake_root_motion(source_dir: Path, dest_dir: Path):
    if not source_dir.exists():
        print(f"[Error] Source directory not found: {source_dir}")
        return
        
    dest_dir.mkdir(parents=True, exist_ok=True)
    files = [f for f in source_dir.iterdir() if f.suffix.lower() in {".fbx", ".glb", ".gltf"}]

    for file_path in files:
        print(f"Processing: {file_path.name}...")
        bpy.ops.wm.read_factory_settings(use_empty=True)
        
        if file_path.suffix.lower() == '.fbx':
            bpy.ops.import_scene.fbx(filepath=str(file_path))
        else:
            bpy.ops.import_scene.gltf(filepath=str(file_path))
            
        armature = next((obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE'), None)
        if not armature: continue
            
        bpy.context.view_layer.objects.active = armature
        bpy.ops.object.mode_set(mode='EDIT')
        
        # 1. Create Root Bone aligned upright
        hips_bone = next((b for b in armature.data.edit_bones if 'Hips' in b.name), None)
        if not hips_bone: continue
            
        root_bone = armature.data.edit_bones.new('Root')
        root_bone.head = (0, 0, 0)
        root_bone.tail = (0, 0, 0.1) 
        
        hips_bone.parent = root_bone
        hips_name = hips_bone.name
        
        bpy.ops.object.mode_set(mode='POSE')
        
        # 2. Correct Axis Mapping for Godot
        action = armature.animation_data.action if armature.animation_data else None
        if action is None and bpy.data.actions:
            # Some imports do not bind the action to the armature automatically.
            armature.animation_data_create()
            action = bpy.data.actions[0]
            armature.animation_data.action = action
            print(f"  [Info] No active armature action; using fallback action: {action.name}")

        if action:
            action.name = "mixamo_com"
            fcurves = action.fcurves
            
            # Identify Mixamo Hips Local Tracks: 0=X (Side), 1=Y (Up/Down), 2=Z (Forward/Back)
            chips_loc = {fc.array_index: fc for fc in fcurves if fc.data_path == f'pose.bones["{hips_name}"].location'}
            
            # Create Target Root Tracks
            root_x_curve = fcurves.new(data_path='pose.bones["Root"].location', index=0) # Maps to Godot X
            root_y_curve = fcurves.new(data_path='pose.bones["Root"].location', index=2) # Maps to Godot Y (Vertical)
            root_z_curve = fcurves.new(data_path='pose.bones["Root"].location', index=1) # Maps to Godot Z
            
            # --- Transfer Side-to-Side (X to X) ---
            if 0 in chips_loc:
                for kp in chips_loc[0].keyframe_points:
                    root_x_curve.keyframe_points.insert(kp.co.x, kp.co.y)
                    kp.co.y = 0 
                chips_loc[0].update()
            
            # Determine if vertical extraction needed. Name filter standard pipeline practice.
            # Math heuristics break on foot-bobs and crouches. Explicit tags safe.
            is_vertical_anim = any(tag in file_path.name.lower() for tag in ["braced", "climb", "hang", "hop", "jump", "pull_up"])
            print(f"  [Info] vertical extraction: {'on' if is_vertical_anim else 'off'}")
            
            # --- Transfer Up/Down (Hips Local Y [1] to Root Local Z [2]) ---
            if 1 in chips_loc and is_vertical_anim:
                for kp in chips_loc[1].keyframe_points:
                    root_y_curve.keyframe_points.insert(kp.co.x, -kp.co.y)
                    kp.co.y = 0 
                chips_loc[1].update()
            
            # --- Transfer Forward/Backward (Hips Local Z [2] to Root Local Y [1]) ---
            if 2 in chips_loc:
                for kp in chips_loc[2].keyframe_points:
                    root_z_curve.keyframe_points.insert(kp.co.x, kp.co.y)
                    kp.co.y = 0 
                chips_loc[2].update()
                
            root_x_curve.update()
            root_y_curve.update()
            root_z_curve.update()
        else:
            print("  [Warn] No animation action found; skipping root-motion extraction for this file.")
                    
        # 3. Export to Godot
        output_path = dest_dir / f"{file_path.stem}.glb"
        bpy.ops.export_scene.gltf(
            filepath=str(output_path),
            export_format='GLB',
            export_yup=True
        )
        print(f"  -> [Success] Exported: {output_path.name}")

if __name__ == "__main__":
    if "--" in sys.argv:
        argv = sys.argv[sys.argv.index("--") + 1:]
    else:
        argv = []
        
    parser = argparse.ArgumentParser(description="Headless Blender Mixamo Root Motion Baker")
    parser.add_argument("--source", default="addons/3d_player_controller/assets/mixamo/animations/source/", help="Path to source files")
    parser.add_argument("--dest", default="addons/3d_player_controller/assets/mixamo/animations/root_motion/", help="Path to output files")
    
    args = parser.parse_args(argv)
    
    source_p = Path.cwd() / args.source
    dest_p = Path.cwd() / args.dest
    
    bake_root_motion(source_p, dest_p)

# blender --background --python tools/bake_root_motion.py
