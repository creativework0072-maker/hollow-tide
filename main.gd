extends Node2D
# Hollow Tide - Week 2 mechanics + Week 3 art and audio integration.
# Core mechanics: movement + swimming, collision, tide control (Low/Mid/High),
# buoyancy, collectibles (score), hazards, goal, and a simple HUD.
# The level is built in code so the whole prototype is easy to read and edit.

const AssetUtil = preload("res://asset_util.gd")
const ART := "res://assets/art/"
const AUDIO := "res://assets/audio/"

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
var water_node: Node2D
var water_surface: TextureRect
var music: AudioStreamPlayer
var sfx_cache := {}
var anim_t := 0.0
var hud: Label
var msg: Label


func _ready() -> void:
	_setup_input()
	_build_level()
	_build_hud()
	_start_music()


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
func _add_block(x: float, y: float, w: float, h: float, visible_art := true) -> void:
	var b := StaticBody2D.new()
	b.position = Vector2(x + w / 2.0, y + h / 2.0)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(w, h)
	cs.shape = rs
	b.add_child(cs)
	if visible_art:
		# Stone tile fill + a strip of moss along the top edge
		b.add_child(AssetUtil.tile_rect(ART + "ground_tile.png", Vector2(-w / 2.0, -h / 2.0), Vector2(w, h)))
		b.add_child(AssetUtil.tile_rect(ART + "moss_top.png", Vector2(-w / 2.0, -h / 2.0 - 2.0), Vector2(w, 12)))
	add_child(b)


func _add_area(pos: Vector2, size: Vector2, visual: Node, callback: Callable) -> Area2D:
	var a := Area2D.new()
	a.position = pos
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	a.add_child(cs)
	a.add_child(visual)
	a.body_entered.connect(callback.bind(a))
	add_child(a)
	return a


func _build_level() -> void:
	# Background: sky gradient and a hazy ruined-city silhouette
	var sky := TextureRect.new()
	sky.texture = load(ART + "bg_sky.png")
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.size = Vector2(2000, 1300)
	sky.position = Vector2(-100, -450)
	sky.z_index = -10
	add_child(sky)
	var city := TextureRect.new()
	city.texture = load(ART + "bg_city.png")
	city.position = Vector2(0, 261)
	city.z_index = -9
	add_child(city)

	# Terrain
	_add_block(0, 560, 450, 200)        # left ground (start)
	_add_block(450, 650, 600, 100)      # sea floor of the pit
	_add_block(1050, 560, 450, 200)     # right ground
	_add_block(1500, 380, 300, 380)     # tall block with the exit on top
	_add_block(-20, -450, 20, 1300, false)   # invisible walls
	_add_block(1800, -450, 20, 1300, false)

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
	var crate_sprite := Sprite2D.new()
	crate_sprite.texture = load(ART + "crate.png")
	crate.add_child(crate_sprite)
	add_child(crate)

	# Pearls (score) - 4-frame shimmer animation
	var pearl_positions := [
		Vector2(200, 530), Vector2(775, 625), Vector2(950, 625),
		Vector2(1200, 530), Vector2(1400, 530), Vector2(1650, 350),
	]
	for p in pearl_positions:
		var ps := AssetUtil.build_sprite(ART + "pearl_sheet.png", 24, 24, {"shimmer": [0, 4, 6.0, true]})
		ps.frame = randi() % 4          # desynchronise the shimmer
		_add_area(p, Vector2(18, 18), ps, _on_pearl)

	# Urchin hazards on the sea floor
	for x in [700.0, 850.0]:
		var us := Sprite2D.new()
		us.texture = load(ART + "urchin.png")
		_add_area(Vector2(x, 636), Vector2(32, 28), us, _on_hazard)

	# Exit beacon (lamp flickers between 2 frames)
	var beacon := AssetUtil.build_sprite(ART + "exit_sheet.png", 40, 80, {"glow": [0, 2, 3.0, true]})
	_add_area(Vector2(1700, 340), Vector2(40, 80), beacon, _on_exit)

	# Player
	player = CharacterBody2D.new()
	player.set_script(load("res://player.gd"))
	player.position = START_POS
	add_child(player)

	# Water: tiled body + a scrolling wave strip along the surface (drawn on top)
	water_node = Node2D.new()
	water_node.position = Vector2(0, water_y)
	water_node.z_index = 5
	water_node.add_child(AssetUtil.tile_rect(ART + "water_tile.png", Vector2(-100, 0), Vector2(2000, 1100)))
	water_surface = AssetUtil.tile_rect(ART + "water_surface.png", Vector2(-164, -6), Vector2(2100, 12))
	water_node.add_child(water_surface)
	add_child(water_node)


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


# ---------- Audio ----------
func _start_music() -> void:
	var m: AudioStreamWAV = load(AUDIO + "music_theme.wav")
	m.loop_mode = AudioStreamWAV.LOOP_FORWARD
	m.loop_begin = 0
	m.loop_end = m.data.size() / 2        # 16-bit mono: 2 bytes per sample
	music = AudioStreamPlayer.new()
	music.stream = m
	music.volume_db = -8.0
	add_child(music)
	music.play()


func play_sfx(sfx_name: String, volume_db := 0.0) -> void:
	if not sfx_cache.has(sfx_name):
		sfx_cache[sfx_name] = load(AUDIO + sfx_name + ".wav")
	var p := AudioStreamPlayer.new()
	p.stream = sfx_cache[sfx_name]
	p.volume_db = volume_db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# ---------- Game loop ----------
func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return

	if not won:
		elapsed += delta
	anim_t += delta

	# Tide control (limited charges)
	if Input.is_action_just_pressed("tide_up") and tide_state < 2 and charges > 0:
		tide_state += 1
		charges -= 1
		play_sfx("sfx_tide", -4.0)
	if Input.is_action_just_pressed("tide_down") and tide_state > 0 and charges > 0:
		tide_state -= 1
		charges -= 1
		play_sfx("sfx_tide", -4.0)

	var target: float = TIDE_Y[tide_state]
	water_y = move_toward(water_y, target, TIDE_SPEED * delta)
	water_node.position.y = water_y
	water_surface.position.x = -164.0 + fmod(anim_t * 24.0, 64.0)   # wave strip scrolls sideways
	# Music gets quieter when Mira is underwater
	var music_target := -16.0 if player.in_water else -8.0
	music.volume_db = move_toward(music.volume_db, music_target, 30.0 * delta)

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
	play_sfx("sfx_hurt")


# ---------- Callbacks (the Area2D is bound as the last argument) ----------
func _on_pearl(body: Node, area: Area2D) -> void:
	if body == player and not won:
		score += 10
		pearls += 1
		play_sfx("sfx_pearl")
		area.queue_free()


func _on_hazard(body: Node, _area: Area2D) -> void:
	if body == player:
		respawn.call_deferred()


func _on_exit(body: Node, _area: Area2D) -> void:
	if body == player and not won:
		won = true
		var bonus: int = max(0, 50 - int(elapsed)) + charges * 5
		score += bonus
		play_sfx("sfx_win")
		msg.text = "Level complete!\nFinal score: %d (R to restart)" % score
