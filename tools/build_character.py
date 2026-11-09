import bpy
import math

PROJECT = "/projects/shadow-of-the-king"
GLB = PROJECT + "/assets/player.glb"
PREVIEW = PROJECT + "/assets/player_preview.png"
WALK_PREVIEW = PROJECT + "/assets/player_walk_preview.png"
CAST_PREVIEW = PROJECT + "/assets/player_cast_preview.png"

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

for block in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
    for item in list(block):
        if item.users == 0:
            block.remove(item)

scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = False
scene.render.resolution_x = 480
scene.render.resolution_y = 480
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.film_transparent = False
scene.view_settings.view_transform = 'AgX'

world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
bg.inputs[0].default_value = (0.01, 0.015, 0.02, 1.0)
bg.inputs[1].default_value = 0.6


def make_mat(name, color, metallic=0.0, roughness=0.8, emission=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = emission
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


cloak = make_mat("Cloak", (0.03, 0.08, 0.09, 1), 0.0, 0.9, (0.05, 0.22, 0.25, 1), 0.45)
armor = make_mat("Armor", (0.08, 0.10, 0.11, 1), 0.6, 0.5, (0.02, 0.08, 0.09, 1), 0.25)
leather = make_mat("Leather", (0.12, 0.08, 0.05, 1), 0.0, 0.9)
skin = make_mat("Skin", (0.55, 0.43, 0.34, 1), 0.0, 0.7)
blindfold = make_mat("Blindfold", (0.55, 0.65, 0.62, 1), 0.0, 0.8, (0.2, 0.7, 0.8, 1), 1.2)
hair = make_mat("Hair", (0.04, 0.035, 0.03, 1), 0.0, 1.0)
metal = make_mat("Metal", (0.40, 0.42, 0.45, 1), 0.9, 0.3)
gold = make_mat("Gold", (0.70, 0.50, 0.15, 1), 0.9, 0.25, (0.4, 0.25, 0.05, 1), 0.3)
wood = make_mat("Wood", (0.18, 0.12, 0.07, 1), 0.0, 0.9)

parts = []


def finish(obj, mat, smooth=False):
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = smooth
    parts.append(obj)
    return obj


def add_box(name, size, loc, mat, rot=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, mat)


def add_cyl(name, radius, depth, loc, mat, rot=(0.0, 0.0, 0.0), verts=8, scale=(1.0, 1.0, 1.0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, mat)


def add_cone(name, radius1, radius2, depth, loc, mat, rot=(0.0, 0.0, 0.0), verts=8):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius1, radius2=radius2, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    return finish(obj, mat)


def add_sphere(name, radius, loc, mat, segments=12, rings=8, scale=(1.0, 1.0, 1.0), smooth=True):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=radius, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, mat, smooth)


def add_torus(name, major_radius, minor_radius, loc, mat, rot=(0.0, 0.0, 0.0), major_segments=24, minor_segments=8):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=major_segments,
        minor_segments=minor_segments,
        location=loc,
        rotation=rot,
    )
    obj = bpy.context.object
    obj.name = name
    return finish(obj, mat, True)


for side in (-1, 1):
    x = side * 0.13
    add_cyl("Thigh_%d" % side, 0.075, 0.34, (x, 0.0, -0.32), leather)
    add_cyl("Calf_%d" % side, 0.065, 0.34, (x, 0.0, -0.64), leather)
    add_box("Boot_%d" % side, (0.17, 0.27, 0.16), (x, -0.05, -0.83), leather)
    add_box("Knee_%d" % side, (0.13, 0.10, 0.12), (x, -0.09, -0.43), armor)
    add_box("ShinArmor_%d" % side, (0.13, 0.10, 0.22), (x, -0.09, -0.63), armor)

add_box("Pelvis", (0.32, 0.22, 0.18), (0.0, 0.0, -0.10), cloak)
add_box("Belt", (0.34, 0.23, 0.06), (0.0, 0.0, 0.0), leather)
add_box("Buckle", (0.06, 0.03, 0.05), (0.0, -0.12, 0.0), gold)
add_box("Tabard", (0.22, 0.035, 0.40), (0.0, -0.135, -0.22), cloak)
add_box("TabardTrim", (0.22, 0.02, 0.04), (0.0, -0.155, -0.42), gold)

add_cyl("TorsoCyl", 0.17, 0.48, (0.0, 0.0, 0.28), cloak, scale=(1.0, 0.72, 1.0))
add_box("ChestPlate", (0.28, 0.06, 0.28), (0.0, -0.13, 0.33), armor)
add_box("Shoulders", (0.42, 0.22, 0.12), (0.0, 0.0, 0.50), cloak)
add_box("Collar", (0.36, 0.20, 0.10), (0.0, 0.02, 0.56), cloak)

for side in (-1, 1):
    x = side * 0.32
    hand_x = 0.38 if side > 0 else -0.34
    add_cyl("UpperArm_%d" % side, 0.055, 0.34, (x, 0.0, 0.30), leather)
    add_cyl("Forearm_%d" % side, 0.05, 0.32, (side * 0.34, -0.02, -0.03), leather)
    add_sphere("Hand_%d" % side, 0.065, (hand_x, -0.04, -0.23), leather, 10, 8)
    add_cyl("Bracer_%d" % side, 0.06, 0.14, (side * 0.34, -0.02, -0.11), armor)
    add_box("ShoulderPad_%d" % side, (0.16, 0.20, 0.14), (side * 0.27, 0.0, 0.50), armor)

add_cyl("Neck", 0.07, 0.12, (0.0, 0.0, 0.56), skin)
add_sphere("HeadSphere", 0.17, (0.0, -0.04, 0.72), skin, 16, 12)
add_box("Nose", (0.05, 0.05, 0.06), (0.0, -0.20, 0.69), skin)
add_torus("BlindfoldBand", 0.172, 0.026, (0.0, -0.04, 0.75), blindfold)
add_sphere("BlindfoldPad", 1.0, (0.0, -0.20, 0.75), blindfold, 16, 10, (0.17, 0.035, 0.075))
add_box("Beard", (0.16, 0.06, 0.09), (0.0, -0.17, 0.61), hair)

add_box("HoodBack", (0.34, 0.12, 0.28), (0.0, 0.11, 0.74), cloak)
add_cone("HoodTop", 0.19, 0.03, 0.13, (0.0, 0.02, 0.91), cloak)
for side in (-1, 1):
    add_box("HoodSide_%d" % side, (0.04, 0.16, 0.24), (side * 0.18, 0.08, 0.73), cloak)
add_box("HoodBrim", (0.32, 0.05, 0.04), (0.0, -0.12, 0.86), cloak)

add_box("Cape", (0.42, 0.05, 0.92), (0.0, 0.16, -0.05), cloak)
add_box("CapeCollar", (0.44, 0.15, 0.10), (0.0, 0.05, 0.55), cloak)
for side in (-1, 1):
    add_box("CapeSide_%d" % side, (0.05, 0.18, 0.78), (side * 0.22, 0.05, 0.0), cloak)
add_sphere("Clasp", 0.035, (0.0, -0.10, 0.52), gold, 10, 8)
for i, x in enumerate((-0.14, 0.0, 0.14)):
    add_box("CapeTatter_%d" % i, (0.10, 0.04, 0.20), (x, 0.16, -0.56), cloak, rot=(0.0, 0.0, (i - 1) * 0.12))

for side in (-1, 1):
    add_box("Pouch_%d" % side, (0.11, 0.08, 0.12), (side * 0.17, -0.11, -0.08), leather)

add_cyl("StaffShaft", 0.025, 1.45, (0.42, -0.04, -0.175), wood)
add_sphere("StaffKnob", 0.06, (0.42, -0.04, 0.57), gold, 12, 8)
add_sphere("StaffBell", 0.035, (0.42, -0.04, 0.64), gold, 10, 8)

add_box("SwordBlade", (0.05, 0.02, 0.65), (-0.20, 0.20, 0.25), metal)
add_box("SwordGuard", (0.14, 0.04, 0.04), (-0.20, 0.20, 0.57), gold)
add_sphere("SwordPommel", 0.035, (-0.20, 0.20, 0.62), gold, 10, 8)

add_sphere("BeltBell1", 0.03, (0.21, -0.16, -0.12), gold, 8, 6)
add_sphere("BeltBell2", 0.025, (-0.21, -0.16, -0.12), gold, 8, 6)


def make_empty(name, world_pos, parent=None):
    bpy.ops.object.empty_add(type='PLAIN_AXES', radius=0.05, location=world_pos)
    obj = bpy.context.object
    obj.name = name
    if parent is not None:
        bpy.context.view_layer.update()
        obj.parent = parent
        obj.location = (
            world_pos[0] - parent.matrix_world.translation.x,
            world_pos[1] - parent.matrix_world.translation.y,
            world_pos[2] - parent.matrix_world.translation.z,
        )
    return obj


root = make_empty("Root", (0.0, 0.0, 0.0))
hips = make_empty("Hips", (0.0, 0.0, -0.12), root)
torso = make_empty("Torso", (0.0, 0.0, 0.02), hips)
head = make_empty("Head", (0.0, 0.0, 0.56), torso)
arm_l = make_empty("ArmL", (-0.32, 0.0, 0.47), torso)
arm_r = make_empty("ArmR", (0.32, 0.0, 0.47), torso)
leg_l = make_empty("LegL", (-0.13, 0.0, -0.15), hips)
leg_r = make_empty("LegR", (0.13, 0.0, -0.15), hips)
shin_l = make_empty("ShinL", (-0.13, 0.0, -0.43), leg_l)
shin_r = make_empty("ShinR", (0.13, 0.0, -0.43), leg_r)
staff = make_empty("Staff", (0.42, -0.04, 0.0), arm_r)
head_marker = make_empty("HeadMarker", (0.0, 0.0, 0.72), head)

GROUPS = [
    ("Hips", ["Pelvis", "Belt", "Buckle", "Tabard", "TabardTrim", "Pouch_-1", "Pouch_1", "BeltBell1", "BeltBell2"], hips),
    ("Torso", ["TorsoCyl", "ChestPlate", "Shoulders", "Collar", "Cape", "CapeCollar", "CapeSide_-1", "CapeSide_1", "Clasp", "CapeTatter_0", "CapeTatter_1", "CapeTatter_2", "SwordBlade", "SwordGuard", "SwordPommel"], torso),
    ("Head", ["Neck", "HeadSphere", "Nose", "BlindfoldBand", "BlindfoldPad", "Beard", "HoodBack", "HoodTop", "HoodSide_-1", "HoodSide_1", "HoodBrim"], head),
    ("ArmL", ["UpperArm_-1", "Forearm_-1", "Hand_-1", "Bracer_-1", "ShoulderPad_-1"], arm_l),
    ("ArmR", ["UpperArm_1", "Forearm_1", "Hand_1", "Bracer_1", "ShoulderPad_1"], arm_r),
    ("LegL", ["Thigh_-1"], leg_l),
    ("LegR", ["Thigh_1"], leg_r),
    ("ShinL", ["Calf_-1", "Boot_-1", "Knee_-1", "ShinArmor_-1"], shin_l),
    ("ShinR", ["Calf_1", "Boot_1", "Knee_1", "ShinArmor_1"], shin_r),
    ("Staff", ["StaffShaft", "StaffKnob", "StaffBell"], staff),
]

grouped = set()
for _, names, _ in GROUPS:
    grouped.update(names)
for obj in parts:
    if obj.name not in grouped:
        raise RuntimeError("Ungrouped part: " + obj.name)

for group_name, names, empty in GROUPS:
    objs = []
    for part_name in names:
        obj = bpy.data.objects.get(part_name)
        if obj is None:
            raise RuntimeError("Missing part: " + part_name)
        objs.append(obj)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objs:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    mesh = bpy.context.object
    mesh.name = group_name + "Mesh"
    bevel = mesh.modifiers.new(name="Bevel", type='BEVEL')
    bevel.width = 0.012
    bevel.segments = 2
    bevel.limit_method = 'ANGLE'
    bevel.angle_limit = math.radians(40.0)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    bpy.context.scene.cursor.location = empty.matrix_world.translation
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.context.view_layer.update()
    mesh.parent = empty
    mesh.location = (0.0, 0.0, 0.0)
    print("GROUP", group_name, "parts", len(names), "pivot", tuple(round(v, 3) for v in empty.matrix_world.translation))

bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(
    filepath=GLB,
    export_format='GLB',
    use_selection=True,
    export_apply=True,
    export_yup=True,
    export_animations=False,
    export_cameras=False,
    export_lights=False,
)

for obj in scene.objects:
    if obj.type == 'EMPTY' or obj.name.endswith("Mesh"):
        print("NODE", obj.name, "parent", obj.parent.name if obj.parent else "-", "loc", tuple(round(v, 3) for v in obj.location))

bpy.ops.mesh.primitive_plane_add(size=6.0, location=(0.0, 0.0, -0.905))
floor = bpy.context.object
floor.name = "PreviewFloor"
floor.data.materials.append(make_mat("PreviewFloor", (0.015, 0.02, 0.025, 1), 0.0, 0.95))

bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0.0, 0.0, 0.2))
target = bpy.context.object
target.name = "AimTarget"

bpy.ops.object.camera_add(location=(2.6, -3.4, 0.5))
cam = bpy.context.object
cam.data.lens = 50
con = cam.constraints.new(type='TRACK_TO')
con.target = target
con.track_axis = 'TRACK_NEGATIVE_Z'
con.up_axis = 'UP_Y'
scene.camera = cam

bpy.ops.object.light_add(type='AREA', location=(2.5, -3.0, 3.0))
key = bpy.context.object
key.data.energy = 400
key.data.size = 3.0
key.data.color = (1.0, 0.85, 0.7)

bpy.ops.object.light_add(type='POINT', location=(-2.5, -2.0, 1.5))
fill = bpy.context.object
fill.data.energy = 120
fill.data.color = (0.35, 0.65, 0.9)
fill.data.shadow_soft_size = 2.0

bpy.ops.object.light_add(type='POINT', location=(0.0, 2.5, 2.0))
rim = bpy.context.object
rim.data.energy = 220
rim.data.color = (0.2, 0.8, 0.9)
rim.data.shadow_soft_size = 2.0


def reset_pose():
    for empty in (hips, torso, head, arm_l, arm_r, leg_l, leg_r, shin_l, shin_r, staff):
        empty.rotation_euler = (0.0, 0.0, 0.0)
    hips.location.z = -0.12


reset_pose()
scene.render.filepath = PREVIEW
bpy.ops.render.render(write_still=True)

reset_pose()
leg_l.rotation_euler.x = 0.38
leg_r.rotation_euler.x = -0.38
shin_l.rotation_euler.x = 0.28
shin_r.rotation_euler.x = 0.05
arm_l.rotation_euler.x = -0.30
arm_r.rotation_euler.x = 0.30
torso.rotation_euler.z = 0.05
head.rotation_euler.z = -0.03
hips.location.z = -0.14
scene.render.filepath = WALK_PREVIEW
bpy.ops.render.render(write_still=True)

reset_pose()
arm_r.rotation_euler.x = -1.0
arm_r.rotation_euler.z = -0.15
torso.rotation_euler.x = -0.06
torso.rotation_euler.z = 0.08
head.rotation_euler.x = -0.05
head.rotation_euler.z = 0.06
scene.render.filepath = CAST_PREVIEW
bpy.ops.render.render(write_still=True)

bpy.ops.wm.save_as_mainfile(filepath="/tmp/opencode/player_rig.blend")

print("EXPORTED", GLB)
print("PREVIEW", PREVIEW)
print("WALK_PREVIEW", WALK_PREVIEW)
print("CAST_PREVIEW", CAST_PREVIEW)
