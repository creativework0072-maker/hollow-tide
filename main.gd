extends Node2D
# Hollow Tide - Week 2 prototype.
# Core mechanics: movement + swimming, collision, tide control (Low/Mid/High),
# buoyancy, collectibles (score), hazards, goal, and a simple HUD.
# The level is built in code so the whole prototype is easy to read and edit.

const TIDE_Y := [600.0, 520.0, 330.0]   # water surface height per tide state
const TIDE_NAMES := ["LOW", "MID", "HIGH"]
const TIDE_SPEED := 90.0                 # px/sec the water moves
const START_POS := Vector2(100, 520)
const MAX_CHARGES := 8
const TOTAL_PEARLS := 6

var water_y: float = 600.0
var tide_state := 0
var charges := MAX_CHARGES
var score := 0
var pearls := 0
var elapsed := 0.0
var won := false

var player            # untyped on purpose: it uses a custom script
var crate: RigidBody2D
var water_rect: ColorRect
var hud: Label
var msg: Label


func _ready() -> void:
	_setup_input()
	_build_level()
	_build_hud()


# ---------- Input ----------
func _setup_input() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE, KEY_W, KEY_UP],
		"tide_up": [KEY_E],
		"tide_down": [KEY_Q],
		"restart": [KEY_R],
	}
	for action in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


# ---------- Level building ----------
func _add_block(x: float, y: float, w: float, h: float, color: Color) -> void:
	var b := StaticBody2D.new()
	b.position = Vector2(x + w / 2.0, y + h / 2.0)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(w, h)
	cs.shape = rs
	b.add_child(cs)
	var r := ColorRect.new()
	r.size = Vector2(w, h)
	r.position = Vector2(-w / 2.0, -h / 2.0)
	r.color = color
	b.add_child(r)
	add_child(b)


func _add_area(pos: Vector2, size: Vector2, color: Color, callback: Callable) -> Area2D:
	var a := Area2D.new()
	a.position = pos
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	a.add_child(cs)
	var r := ColorRect.new()
	r.size = size
	r.position = -size / 2.0
	r.color = color
	a.add_child(r)
	a.body_entered.connect(callback.bind(a))
	add_child(a)
	return a


func _build_level() -> void:
	# Sky background
	var sky := ColorRect.new()
	sky.size = Vector2(2000, 1300)
	sky.position = Vector2(-100, -450)
	sky.color = Color("BFD7EA")
	sky.z_index = -10
	add_child(sky)

	# Terrain
	var dark := Color("12263A")
	_add_block(0, 560, 450, 200, dark)        # left ground (start)
	_add_block(450, 650, 600, 100, dark)      # sea floor of the pit
	_add_block(1050, 560, 450, 200, dark)     # right ground
	_add_block(1500, 380, 300, 380, dark)     # tall block with the exit on top
	_add_block(-20, -450, 20, 1300, Color(0, 0, 0, 0))   # invisible walls
	_add_block(1800, -450, 20, 1300, Color(0, 0, 0, 0))

	# Floating crate (RigidBody2D) - buoyancy is applied in _physics_process
	crate = RigidBody2D.new()
	crate.position = Vector2(300, 520)
	crate.linear_damp = 2.0
	crate.angular_damp = 4.0
	crate.lock_rotation = true
	var ccs := CollisionShape2D.new()
	var crs := RectangleShape2D.new()
	crs.size = Vector2(50, 50)
	ccs.shape = crs
	crate.add_child(ccs)
	var cr := ColorRect.new()
	cr.size = Vector2(50, 50)
	cr.position = Vector2(-25, -25)
	cr.color = Color("A9783B")
	crate.add_child(cr)
	add_child(crate)

	# Pearls (score)
	var pearl_positions := [
		Vector2(200, 530), Vector2(775, 625), Vector2(950, 625),
		Vector2(1200, 530), Vector2(1400, 530), Vector2(1650, 350),
	]
	for p in pearl_positions:
		_add_area(p, Vector2(18, 18), Color("FFF1E6"), _on_pearl)

	# Urchin hazards on the sea floor
	for x in [700.0, 850.0]:
		_add_area(Vector2(x, 636), Vector2(32, 28), Color("E76F51"), _on_hazard)

	# Exit
	_add_area(Vector2(1700, 340), Vector2(40, 80), Color("2A9D8F"), _on_exit)

	# Player
	player = CharacterBody2D.new()
	player.set_script(load("res://player.gd"))
	player.position = START_POS
	add_child(player)

	# Water (drawn last, semi-transparent, on top)
	water_rect = ColorRect.new()
	water_rect.size = Vector2(2000, 1100)
	water_rect.position = Vector2(-100, water_y)
	water_rect.color = Color(0.16, 0.62, 0.56, 0.45)
	water_rect.z_index = 5
	add_child(water_rect)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(16, 10)
	_style_label(hud, 20)
	layer.add_child(hud)
	msg = Label.new()
	msg.position = Vector2(176, 240)
	msg.size = Vector2(800, 120)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(msg, 34)
	layer.add_child(msg)


func _style_label(l: Label, size: int) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)


# ---------- Game loop ----------
func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return

	if not won:
		elapsed += delta

	# Tide control (limited charges)
	if Input.is_action_just_pressed("tide_up") and tide_state < 2 and charges > 0:
		tide_state += 1
		charges -= 1
	if Input.is_action_just_pressed("tide_down") and tide_state > 0 and charges > 0:
		tide_state -= 1
		charges -= 1

	var target: float = TIDE_Y[tide_state]
	water_y = move_toward(water_y, target, TIDE_SPEED * delta)
	water_rect.position.y = water_y

	# Buoyancy: upward force proportional to how much of the crate is submerged.
	# At 50% submerged the force equals gravity (mass * 980), so it floats there.
	var bottom := crate.position.y + 25.0
	var submerged: float = clamp((bottom - water_y) / 50.0, 0.0, 1.0)
	crate.apply_central_force(Vector2(0, -crate.mass * 980.0 * 2.0 * submerged))

	_update_hud()


func _update_hud() -> void:
	hud.text = "Score: %d   Pearls: %d/%d   Time: %.1fs\nTide: %s   Charges: %d   Breath: %d\nA/D move  Space jump/swim  E raise tide  Q lower tide  R restart" % [
		score, pearls, TOTAL_PEARLS, elapsed, TIDE_NAMES[tide_state], charges, int(ceil(player.breath))]


func respawn() -> void:
	player.global_position = START_POS
	player.velocity = Vector2.ZERO
	player.breath = 10.0
	score = max(0, score - 5)


# ---------- Callbacks (the Area2D is bound as the last argument) ----------
func _on_pearl(body: Node, area: Area2D) -> void:
	if body == player and not won:
		score += 10
		pearls += 1
		area.queue_free()


func _on_hazard(body: Node, _area: Area2D) -> void:
	if body == player:
		respawn.call_deferred()


func _on_exit(body: Node, _area: Area2D) -> void:
	if body == player and not won:
		won = true
		var bonus: int = max(0, 50 - int(elapsed)) + charges * 5
		score += bonus
		msg.text = "Level complete!\nFinal score: %d (R to restart)" % score
