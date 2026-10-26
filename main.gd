extends Node2D
# Hollow Tide - Weeks 2-4: mechanics, assets, and two complete levels.
# Level 1 "Shallows of Veyra" teaches the tide. Level 2 "The Market Quarter" adds a
# pressure-plate gate puzzle, a patrolling eel, checkpoints and story murals.
# Levels are built in code from small helper functions so they are easy to read and edit.

const AssetUtil = preload("res://asset_util.gd")
const ART := "res://assets/art/"
const AUDIO := "res://assets/audio/"

const TIDE_Y := [600.0, 520.0, 330.0]   # water surface height per tide state
const TIDE_NAMES := ["LOW", "MID", "HIGH"]
const TIDE_SPEED := 90.0                 # px/sec the water moves
const MAX_CHARGES := 8
const LEVEL_NAMES := ["Level 1 - Shallows of Veyra", "Level 2 - The Market Quarter"]

# [WEEK5-OPT] Master switch for the Week 5 optimisations (sprite-frame sharing, sound pool,
# throttled HUD, no force on a resting crate). Set to false to measure the "before" state.
const OPTIMIZE := true
const BENCH_SECONDS := 10.0
const SFX_POOL_SIZE := 8
const GATE_X := 1340.0

static var current_level := 0            # survives scene reloads (restart / next level)

var water_y: float = 600.0
var tide_state := 0
var charges := MAX_CHARGES
var score := 0
var pearls := 0
var total_pearls := 0
var elapsed := 0.0
var won := false
var level_width := 1800
var start_pos := Vector2(100, 520)
var spawn_pos := Vector2(100, 520)
var anim_t := 0.0
var story_timer := 0.0

var player            # untyped on purpose: it uses a custom script
var crate: RigidBody2D
var water_node: Node2D
var water_surface: TextureRect
var music: AudioStreamPlayer
var sfx_cache := {}
var hud: Label
var msg: Label
var story: Label

# Level 2 interactive elements
var eels: Array = []
var has_gate := false
var gate_body: StaticBody2D
var gate_closed_y := 0.0
var gate_open_y := 0.0
var plate_sprite: AnimatedSprite2D
var plate_bodies := 0

# Week 5: tools, soft-lock protection and optimisation state
var crate_start := Vector2.ZERO
var hud_timer := 0.0
var overlay: Label
var show_overlay := false
var overlay_timer := 0.0
var bench_active := false
var bench_time := 0.0
var bench_samples: Array = []
var bench_text := ""
var bench_text_timer := 0.0
var out_of_charges_warned := false
var sfx_pool: Array = []
var sfx_index := 0


func _ready() -> void:
	level_width = 1800 if current_level == 0 else 2600
	AssetUtil.use_cache = OPTIMIZE
	AssetUtil.reset_stats()
	_setup_input()
	_build_background()
	if current_level == 0:
		_level_1()
	else:
		_level_2()
	_build_player_and_water()
	_build_hud()
	_build_sfx_pool()
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
		"next_level": [KEY_N, KEY_ENTER],
		"level_1": [KEY_1],
		"level_2": [KEY_2],
		"reset_crate": [KEY_C],      # [WEEK5-FEATURE] soft-lock protection
		"mute": [KEY_M],             # [WEEK5-FEATURE] mute / unmute all audio
		"debug_overlay": [KEY_F3],   # [WEEK5-FEATURE] live performance statistics
		"benchmark": [KEY_F4],       # [WEEK5-FEATURE] 10-second performance capture
	}
	for action in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


# ---------- Building blocks ----------
func _add_block(x: float, y: float, w: float, h: float, visible_art := true) -> void:
	var b := StaticBody2D.new()
	b.position = Vector2(x + w / 2.0, y + h / 2.0)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(w, h)
	cs.shape = rs
	b.add_child(cs)
	if visible_art:
		b.add_child(AssetUtil.tile_rect(ART + "ground_tile.png", Vector2(-w / 2.0, -h / 2.0), Vector2(w, h)))
		b.add_child(AssetUtil.tile_rect(ART + "moss_top.png", Vector2(-w / 2.0, -h / 2.0 - 2.0), Vector2(w, 12)))
	add_child(b)


# A market-stall awning you can stand on (20 px thick platform)
func _add_platform(x: float, y: float, w: float) -> void:
	var b := StaticBody2D.new()
	b.position = Vector2(x + w / 2.0, y + 10.0)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(w, 20)
	cs.shape = rs
	b.add_child(cs)
	b.add_child(AssetUtil.tile_rect(ART + "stall_top.png", Vector2(-w / 2.0, -10.0), Vector2(w, 20)))
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
	if callback.is_valid():
		a.body_entered.connect(callback.bind(a))
	add_child(a)
	return a


func _add_crate(pos: Vector2) -> void:
	crate = RigidBody2D.new()
	crate.position = pos
	crate_start = pos
	crate.linear_damp = 2.0
	crate.angular_damp = 4.0
	crate.lock_rotation = true
	var ccs := CollisionShape2D.new()
	var crs := RectangleShape2D.new()
	crs.size = Vector2(50, 50)
	ccs.shape = crs
	crate.add_child(ccs)
	var crate_sprite := Sprite2D.new()
	crate_sprite.texture = AssetUtil.get_texture(ART + "crate.png")
	crate.add_child(crate_sprite)
	add_child(crate)


func _add_pearls(positions: Array) -> void:
	for p in positions:
		var ps := AssetUtil.build_sprite(ART + "pearl_sheet.png", 24, 24, {"shimmer": [0, 4, 6.0, true]})
		ps.frame = randi() % 4          # desynchronise the shimmer
		_add_area(p, Vector2(18, 18), ps, _on_pearl)
		total_pearls += 1


func _add_urchins(xs: Array, y: float) -> void:
	for x in xs:
		var us := Sprite2D.new()
		us.texture = AssetUtil.get_texture(ART + "urchin.png")
		_add_area(Vector2(x, y), Vector2(32, 28), us, _on_hazard)


func _add_exit(pos: Vector2) -> void:
	var beacon := AssetUtil.build_sprite(ART + "exit_sheet.png", 40, 80, {"glow": [0, 2, 3.0, true]})
	_add_area(pos, Vector2(40, 80), beacon, _on_exit)


func _add_lantern(pos: Vector2) -> void:
	var l := AssetUtil.build_sprite(ART + "lantern_sheet.png", 24, 48, {"off": [0, 1, 1.0, false], "on": [1, 1, 1.0, false]})
	_add_area(pos, Vector2(30, 60), l, _on_lantern)


func _add_mural(pos: Vector2, text: String) -> void:
	var m := Sprite2D.new()
	m.texture = AssetUtil.get_texture(ART + "mural.png")
	_add_area(pos, Vector2(50, 70), m, _on_mural.bind(text))


func _add_decor(tex: String, pos: Vector2, z := -1) -> void:
	var s := Sprite2D.new()
	s.texture = AssetUtil.get_texture(ART + tex)
	s.position = pos
	s.z_index = z
	add_child(s)


func _add_bubbles(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.texture = AssetUtil.get_texture(ART + "bubble.png")
	p.position = pos
	p.amount = 5
	p.lifetime = 3.5
	p.direction = Vector2(0, -1)
	p.spread = 12.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 30.0
	p.z_index = 4
	add_child(p)
	p.emitting = true


func _add_eel(x_min: float, x_max: float, y: float, speed: float) -> void:
	var spr := AssetUtil.build_sprite(ART + "eel_sheet.png", 48, 20, {"swim": [0, 2, 6.0, true]})
	var a := _add_area(Vector2(x_min, y), Vector2(40, 16), spr, _on_hazard)
	eels.append({"area": a, "sprite": spr, "min": x_min, "max": x_max, "speed": speed, "dir": 1.0})


# ---------- Backgrounds ----------
func _build_background() -> void:
	var sky := TextureRect.new()
	sky.texture = AssetUtil.get_texture(ART + "bg_sky.png")
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.size = Vector2(level_width + 200, 1300)
	sky.position = Vector2(-100, -450)
	sky.z_index = -10
	if current_level == 1:
		sky.modulate = Color(1.0, 0.88, 0.84)       # warmer dusk for the market quarter
	add_child(sky)
	for i in range(ceili(level_width / 1800.0)):
		var city := TextureRect.new()
		city.texture = AssetUtil.get_texture(ART + "bg_city.png")
		city.position = Vector2(i * 1800, 261)
		city.z_index = -9
		if current_level == 1:
			city.modulate = Color(1.0, 0.82, 0.78)
		add_child(city)


# ---------- Level 1: Shallows of Veyra (tutorial) ----------
func _level_1() -> void:
	start_pos = Vector2(100, 520)
	_add_block(0, 560, 450, 200)        # left ground (start)
	_add_block(450, 650, 600, 100)      # sea floor of the pit
	_add_block(1050, 560, 450, 200)     # right ground
	_add_block(1500, 380, 300, 380)     # tall block with the exit on top
	_add_block(-20, -450, 20, 1300, false)
	_add_block(1800, -450, 20, 1300, false)
	_add_crate(Vector2(300, 520))
	_add_pearls([Vector2(200, 530), Vector2(775, 625), Vector2(950, 625),
		Vector2(1200, 530), Vector2(1400, 530), Vector2(1650, 350)])
	_add_urchins([700.0, 850.0], 636.0)
	_add_mural(Vector2(150, 528), "Veyra, the city of lamps. The sea rose one night and never left.")
	_add_mural(Vector2(1280, 528), "Some walls are too tall to jump. Raise the tide (E) and swim over.")
	_add_lantern(Vector2(1120, 536))
	_add_exit(Vector2(1700, 340))


# ---------- Level 2: The Market Quarter ----------
func _level_2() -> void:
	start_pos = Vector2(100, 520)
	# Terrain: dock, flooded market floor, steps, district, aqueduct block
	_add_block(0, 560, 420, 200)          # A  start dock
	_add_block(420, 650, 940, 100)        # B  flooded market floor
	_add_block(1360, 600, 120, 160)       #    step up
	_add_block(1480, 560, 520, 200)       # D  district ground
	_add_block(2000, 400, 600, 360)       # E  aqueduct block (needs High tide)
	_add_block(-20, -450, 20, 1300, false)
	_add_block(2600, -450, 20, 1300, false)
	# Market stall awnings (platforms above the floor)
	_add_platform(520, 540, 120)
	_add_platform(700, 490, 120)
	_add_platform(880, 540, 120)
	_add_platform(1060, 490, 140)
	# Puzzle: push the crate into the pit onto the plate (at Low tide) to open the gate
	_add_crate(Vector2(300, 520))
	plate_sprite = AssetUtil.build_sprite(ART + "plate_sheet.png", 72, 16, {"up": [0, 1, 1.0, false], "down": [1, 1, 1.0, false]})
	plate_sprite.position = Vector2(0, 17)
	var plate := _add_area(Vector2(560, 625), Vector2(70, 50), plate_sprite, Callable())
	plate.body_entered.connect(_on_plate_enter)
	plate.body_exited.connect(_on_plate_exit)
	# Iron gate (collision moves up when open)
	has_gate = true
	gate_closed_y = 445.0
	gate_open_y = 25.0
	# [WEEK5-FIX] AnimatableBody2D is the correct body type for a collider that moves by script
	var gate_anim := AnimatableBody2D.new()
	gate_anim.sync_to_physics = true
	gate_body = gate_anim
	gate_body.position = Vector2(GATE_X, gate_closed_y)
	var gcs := CollisionShape2D.new()
	var grs := RectangleShape2D.new()
	grs.size = Vector2(40, 410)
	gcs.shape = grs
	gate_body.add_child(gcs)
	gate_body.add_child(AssetUtil.tile_rect(ART + "gate_tile.png", Vector2(-20, -205), Vector2(40, 410)))
	add_child(gate_body)
	# Enemies and hazards
	_add_eel(450.0, 720.0, 612.0, 80.0)
	_add_urchins([850.0, 1150.0], 636.0)
	# Collectibles
	_add_pearls([Vector2(580, 510), Vector2(760, 460), Vector2(940, 510), Vector2(1130, 460),
		Vector2(1000, 625), Vector2(1650, 530), Vector2(1900, 530),
		Vector2(2250, 370), Vector2(2450, 370)])
	# Checkpoint, story murals and exit
	_add_lantern(Vector2(1540, 536))
	_add_mural(Vector2(180, 528), "Veyra's market never slept. Its lamps burned all night.")
	_add_mural(Vector2(1235, 618), "The Undertow sealed the gate. Only something heavy at the bottom can open it.")
	_add_mural(Vector2(1750, 528), "Oren's note: 'The tide answers to patience.'")
	_add_mural(Vector2(2300, 368), "Light the beacon, little keeper.")
	_add_exit(Vector2(2500, 360))
	# Environmental dressing
	for x in [470.0, 640.0, 790.0, 1040.0, 1250.0]:
		_add_decor("seaweed.png", Vector2(x, 630))
	_add_decor("pillar.png", Vector2(1290, 602), -2)
	_add_decor("pillar.png", Vector2(1640, 512), -2)
	_add_decor("pillar.png", Vector2(2150, 352), -2)
	_add_bubbles(Vector2(790, 640))
	_add_bubbles(Vector2(1250, 640))


# ---------- Player, water, HUD ----------
func _build_player_and_water() -> void:
	spawn_pos = start_pos
	player = CharacterBody2D.new()
	player.set_script(load("res://player.gd"))
	player.position = start_pos
	add_child(player)
	# Water: tiled body + a scrolling wave strip along the surface (drawn on top)
	water_node = Node2D.new()
	water_node.position = Vector2(0, water_y)
	water_node.z_index = 5
	water_node.add_child(AssetUtil.tile_rect(ART + "water_tile.png", Vector2(-100, 0), Vector2(level_width + 200, 1100)))
	water_surface = AssetUtil.tile_rect(ART + "water_surface.png", Vector2(-164, -6), Vector2(level_width + 300, 12))
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
	msg.position = Vector2(176, 220)
	msg.size = Vector2(800, 140)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(msg, 34)
	layer.add_child(msg)
	overlay = Label.new()
	overlay.position = Vector2(820, 10)
	overlay.visible = false
	_style_label(overlay, 16)
	layer.add_child(overlay)
	story = Label.new()
	story.position = Vector2(126, 560)
	story.size = Vector2(900, 70)
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(story, 22)
	layer.add_child(story)


func _style_label(l: Label, size: int) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)


func _show_story(text: String, secs := 5.0) -> void:
	story.text = text
	story_timer = secs


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


# [WEEK5-OPT] A fixed pool of players is reused instead of creating and freeing a node per sound.
func _build_sfx_pool() -> void:
	if not OPTIMIZE:
		return
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_pool.append(p)


func play_sfx(sfx_name: String, volume_db := 0.0) -> void:
	if not sfx_cache.has(sfx_name):
		sfx_cache[sfx_name] = load(AUDIO + sfx_name + ".wav")
	if OPTIMIZE:
		var pooled: AudioStreamPlayer = sfx_pool[sfx_index]
		sfx_index = (sfx_index + 1) % SFX_POOL_SIZE
		pooled.stream = sfx_cache[sfx_name]
		pooled.volume_db = volume_db
		pooled.play()
	else:
		var p := AudioStreamPlayer.new()
		p.stream = sfx_cache[sfx_name]
		p.volume_db = volume_db
		add_child(p)
		p.finished.connect(p.queue_free)
		p.play()


# ---------- Game loop ----------
func _goto_level(i: int) -> void:
	current_level = i
	get_tree().reload_current_scene()


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if Input.is_action_just_pressed("level_1"):
		_goto_level(0)
		return
	if Input.is_action_just_pressed("level_2"):
		_goto_level(1)
		return
	if won and Input.is_action_just_pressed("next_level"):
		_goto_level((current_level + 1) % LEVEL_NAMES.size())
		return
	# [WEEK5-FEATURE] utility keys
	if Input.is_action_just_pressed("mute"):
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
	if Input.is_action_just_pressed("reset_crate"):
		_reset_crate("Crate returned to its start.")
	if Input.is_action_just_pressed("debug_overlay"):
		show_overlay = not show_overlay
		overlay.visible = show_overlay or bench_text_timer > 0.0
	if Input.is_action_just_pressed("benchmark") and not bench_active:
		bench_active = true
		bench_time = 0.0
		bench_samples.clear()
		_show_story("Benchmark running for %d s - play normally..." % int(BENCH_SECONDS), 3.0)

	if not won:
		elapsed += delta
	anim_t += delta
	if story_timer > 0.0:
		story_timer -= delta
		if story_timer <= 0.0:
			story.text = ""

	# Tide control (limited charges)
	if Input.is_action_just_pressed("tide_up") and tide_state < 2 and charges > 0:
		tide_state += 1
		charges -= 1
		play_sfx("sfx_tide", -4.0)
		_check_charges()
	if Input.is_action_just_pressed("tide_down") and tide_state > 0 and charges > 0:
		tide_state -= 1
		charges -= 1
		play_sfx("sfx_tide", -4.0)
		_check_charges()

	var target: float = TIDE_Y[tide_state]
	water_y = move_toward(water_y, target, TIDE_SPEED * delta)
	water_node.position.y = water_y
	water_surface.position.x = -164.0 + fmod(anim_t * 24.0, 64.0)   # wave strip scrolls sideways
	var music_target := -16.0 if player.in_water else -8.0
	music.volume_db = move_toward(music.volume_db, music_target, 30.0 * delta)

	# Buoyancy: upward force proportional to how much of the crate is submerged.
	var bottom := crate.position.y + 25.0
	var submerged: float = clamp((bottom - water_y) / 50.0, 0.0, 1.0)
	# [WEEK5-OPT] No force when the crate is dry, so Godot can put it to sleep.
	if submerged > 0.0 or not OPTIMIZE:
		crate.apply_central_force(Vector2(0, -crate.mass * 980.0 * 2.0 * submerged))
	# [WEEK5-FIX] Soft-lock protection: bring the crate back if it leaves the level
	if crate.position.y > 800.0 or crate.position.x < -50.0 or crate.position.x > level_width + 50.0:
		_reset_crate("The crate drifted away and was returned to its start.")

	# Eels patrol back and forth
	for e in eels:
		var a: Area2D = e["area"]
		a.position.x += e["dir"] * e["speed"] * delta
		if a.position.x > e["max"]:
			e["dir"] = -1.0
		elif a.position.x < e["min"]:
			e["dir"] = 1.0
		e["sprite"].flip_h = e["dir"] < 0.0

	# Gate follows the pressure plate
	if has_gate:
		# [WEEK5-FIX] The gate never closes while Mira is standing in it (it could trap her)
		# (only counts once the gate has actually been raised, so it cannot be opened by standing near it)
		var in_gate: bool = absf(player.global_position.x - GATE_X) < 34.0 and gate_body.position.y < gate_closed_y - 60.0
		var gate_target := gate_open_y if (plate_bodies > 0 or in_gate) else gate_closed_y
		gate_body.position.y = move_toward(gate_body.position.y, gate_target, 220.0 * delta)
		var plate_anim := "down" if plate_bodies > 0 else "up"
		if plate_sprite.animation != plate_anim:
			plate_sprite.play(plate_anim)

	# [WEEK5-OPT] HUD text is rebuilt 10 times per second instead of every physics frame
	hud_timer -= delta
	if hud_timer <= 0.0 or not OPTIMIZE:
		hud_timer = 0.1
		_update_hud()
	_update_debug(delta)


func _check_charges() -> void:
	if charges == 0 and not out_of_charges_warned:
		out_of_charges_warned = true
		_show_story("Out of tide charges! Light a lantern to restore them, or press R.", 6.0)


# [WEEK5-FIX] Prevents the crate from becoming permanently lost (C key or automatic)
func _reset_crate(text: String) -> void:
	crate.freeze = true
	crate.linear_velocity = Vector2.ZERO
	crate.angular_velocity = 0.0
	crate.global_position = crate_start
	crate.set_deferred("freeze", false)
	_show_story(text, 2.5)


# ---------- Debug overlay and benchmark ([WEEK5-FEATURE]) ----------
func _update_debug(delta: float) -> void:
	if bench_text_timer > 0.0:
		bench_text_timer -= delta
	overlay_timer -= delta
	if bench_active:
		bench_time += delta
		bench_samples.append([
			Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		])
		if bench_time >= BENCH_SECONDS:
			_finish_benchmark()
	if show_overlay or bench_text_timer > 0.0:
		overlay.visible = true
		if overlay_timer <= 0.0:
			overlay_timer = 0.25
			overlay.text = bench_text if bench_text_timer > 0.0 else _stats_text()
	else:
		overlay.visible = false


func _stats_text() -> String:
	return "FPS: %d\nProcess: %.2f ms   Physics: %.2f ms\nNodes: %d   Objects: %d\nResources: %d   Draw calls: %d\nStatic memory: %.1f MB\nSpriteFrames built: %d   Atlas: %d\nOPTIMIZE: %s" % [
		int(Performance.get_monitor(Performance.TIME_FPS)),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		AssetUtil.frames_built, AssetUtil.atlas_built, str(OPTIMIZE)]


func _finish_benchmark() -> void:
	bench_active = false
	var fps_sum := 0.0
	var fps_min := 99999.0
	var proc_sum := 0.0
	var phys_sum := 0.0
	for smp in bench_samples:
		fps_sum += smp[0]
		fps_min = minf(fps_min, smp[0])
		proc_sum += smp[1]
		phys_sum += smp[2]
	var n := maxi(1, bench_samples.size())
	bench_text = "BENCHMARK  OPTIMIZE=%s  Level %d\nAverage FPS: %.1f   Minimum FPS: %.1f\nAvg process: %.3f ms   Avg physics: %.3f ms\nNodes: %d   Objects: %d   Resources: %d\nDraw calls: %d   Static memory: %.1f MB\nSpriteFrames built: %d   Atlas built: %d\nSamples: %d" % [
		str(OPTIMIZE), current_level + 1, fps_sum / n, fps_min, proc_sum / n, phys_sum / n,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		AssetUtil.frames_built, AssetUtil.atlas_built, bench_samples.size()]
	var fname := "user://benchmark_%s_level%d.txt" % ["after" if OPTIMIZE else "before", current_level + 1]
	var f := FileAccess.open(fname, FileAccess.WRITE)
	if f:
		f.store_string(bench_text)
		f.close()
	print(bench_text)
	print("Saved to: ", ProjectSettings.globalize_path(fname))
	bench_text_timer = 30.0
	overlay_timer = 0.0
	_show_story("Benchmark saved to " + ProjectSettings.globalize_path(fname), 12.0)


func _update_hud() -> void:
	hud.text = "%s\nScore: %d   Pearls: %d/%d   Time: %.1fs\nTide: %s   Charges: %d   Breath: %d\nA/D move  Space jump/swim  E/Q tide  R restart  1/2 level\nC reset crate  M mute  F3 stats  F4 benchmark" % [
		LEVEL_NAMES[current_level], score, pearls, total_pearls, elapsed, TIDE_NAMES[tide_state], charges, int(ceil(player.breath))]


func respawn() -> void:
	player.global_position = spawn_pos
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


func _on_lantern(body: Node, area: Area2D) -> void:
	if body == player and not area.has_meta("lit"):
		area.set_meta("lit", true)
		spawn_pos = area.position + Vector2(0, -20)
		for c in area.get_children():
			if c is AnimatedSprite2D:
				c.play("on")
		play_sfx("sfx_pearl", -4.0)
		# [WEEK5-FEATURE] lanterns also restore tide charges (prevents running out)
		charges = MAX_CHARGES
		out_of_charges_warned = false
		_show_story("Checkpoint lit! Tide charges restored.", 3.0)


func _on_mural(body: Node, text: String, _area: Area2D) -> void:
	if body == player:
		_show_story(text, 6.0)


func _on_plate_enter(body: Node) -> void:
	if body == crate or body == player:
		plate_bodies += 1
		if plate_bodies == 1:
			play_sfx("sfx_tide", -8.0)


func _on_plate_exit(body: Node) -> void:
	if body == crate or body == player:
		plate_bodies = max(0, plate_bodies - 1)


func _on_exit(body: Node, _area: Area2D) -> void:
	if body == player and not won:
		won = true
		var bonus: int = max(0, 50 - int(elapsed)) + charges * 5
		score += bonus
		play_sfx("sfx_win")
		var last := current_level >= LEVEL_NAMES.size() - 1
		var hint := "N: back to Level 1   R: replay" if last else "Press N for the next level"
		msg.text = "Level complete!\nScore: %d\n%s" % [score, hint]
