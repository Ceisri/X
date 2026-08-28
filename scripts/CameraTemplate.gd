extends Spatial
#camroot.gd
onready var player = $".."
onready var PlayerCharacterMesh = $"../character"
var camrot_h = 0
var camrot_v = 0
onready var cam_v = $h/v
onready var cam_h = $h
onready var camera = $h/v/Camera
export var cam_v_max = 75
export var cam_v_min = -55
export var joystick_sensitivity = 20
var h_sensitivity = 0.1
var v_sensitivity = 0.1
var h_acceleration = 10
var v_acceleration = 10
var zoom_speed = 0.1
var joyview = Vector2()
# ---------------- IMPACT SHAKE ----------------
var shake_time = 0.0
var shake_strength = 0.0
var shake_decay = 4.0
var shake_t = 0.0
var shake_offset = Vector2()
# ---------------- RUN SHAKE ----------------
var runShake_t = 0.0
var runShake_strength = 0.0
var runShake_speed = 6.0
var runShake_intensity = 0.4
var runShake_offset = Vector2()
# ---------------------------------------------

func _isLocal() -> bool:
	return is_instance_valid(player) and player.has_method("isLocalPlayer") and player.isLocalPlayer()

func _ready():
	if !_isLocal():
		set_process_input(false)
		if is_instance_valid(camera):
			camera.current = false
		return

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.add_exception(get_parent())
	camera.current = true

func _input(event):
	if !_isLocal():
		return
	if player.cursor_visible == false:
		if event is InputEventMouseMotion:
			camrot_h += -event.relative.x * h_sensitivity
			camrot_v += event.relative.y * v_sensitivity
		if event is InputEventMouseButton and event.button_index == BUTTON_WHEEL_UP:
			Zoom(-1)
		elif event is InputEventMouseButton and event.button_index == BUTTON_WHEEL_DOWN:
			Zoom(1)

func _joystick_input():
	if Input.is_action_pressed("lookup") or Input.is_action_pressed("lookdown") or Input.is_action_pressed("lookleft") or Input.is_action_pressed("lookright"):
		joyview.x = Input.get_action_strength("lookleft") - Input.get_action_strength("lookright")
		joyview.y = Input.get_action_strength("lookup") - Input.get_action_strength("lookdown")
		camrot_h += joyview.x * joystick_sensitivity * h_sensitivity
		camrot_v += joyview.y * joystick_sensitivity * v_sensitivity

func Zoom(zoom_direction):
	camera.translation.y += zoom_direction * zoom_speed
	camera.translation.z -= zoom_direction * (zoom_speed * 2)

# ===================== CameraTemplate.gd (Camroot) =====================

func _physics_process(delta):
	if !_isLocal():
		_applyPuppetRotation(delta)
		return
	_joystick_input()
	mouseMode()
	camrot_v = clamp(camrot_v, cam_v_min, cam_v_max)
	# ---------------- IMPACT SHAKE ----------------
	if shake_time > 0:
		shake_time -= delta
		shake_strength = lerp(shake_strength, 0, delta * shake_decay)
		shake_t += delta * 18.0
		shake_offset.x = sin(shake_t) * shake_strength
		shake_offset.y = sin(shake_t * 1.7) * shake_strength
	else:
		shake_offset = Vector2()
		shake_t = 0.0
	# ---------------- APPLY ROTATION ----------------
	var final_offset = shake_offset + runShake_offset
	cam_h.rotation_degrees.y = lerp(
		cam_h.rotation_degrees.y,
		camrot_h + final_offset.x,
		delta * h_acceleration
	)
	cam_v.rotation_degrees.x = lerp(
		cam_v.rotation_degrees.x,
		camrot_v + final_offset.y,
		delta * v_acceleration
	)

# Puppet camroots receive camrot_h/camrot_v over the network (see
# Player.gd._applyPuppetState) but this node used to just `return` for
# every non-local instance, so the h/v Spatial nodes never rotated and
# this Camera's global_transform (and get_frustum()) never reflected the
# real remote player's actual view. Server-side mob relevance/freeze
# (Global.gd forceWakeVisibleNearbyMobs/forceFreezeUnseenMobs) needs this
# to be correct, since the player's camera is the sole source of truth
# for whether a mob is relevant, frozen, or synced.
func _applyPuppetRotation(delta) -> void:
	if !is_instance_valid(cam_h) or !is_instance_valid(cam_v):
		return
	camrot_v = clamp(camrot_v, cam_v_min, cam_v_max)
	cam_h.rotation_degrees.y = lerp(cam_h.rotation_degrees.y, camrot_h, delta * h_acceleration)
	cam_v.rotation_degrees.x = lerp(cam_v.rotation_degrees.x, camrot_v, delta * v_acceleration)
func mouseMode() -> void:
	if !_isLocal():
		return
	if Input.is_action_just_pressed("ESC"):
		player.cursor_visible = !player.cursor_visible
	if !player.cursor_visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		$"../UI/Crossair".visible = true
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		$"../UI/Crossair".visible = false

# ---------------- PUBLIC IMPACT SHAKE ----------------
func startCameraShake(strength, duration, decay = 4.0):
	if !_isLocal():
		return
	shake_strength = strength
	shake_time = duration
	shake_decay = decay

# ---------------- RUN SHAKE (CALL EVERY FRAME) ----------------
func updateCameraRunShake(delta):
	if !_isLocal():
		return
	runShake_t += delta * runShake_speed
	runShake_offset.x = sin(runShake_t) * runShake_intensity
	runShake_offset.y = sin(runShake_t * 1.0) * runShake_intensity * 0.5
