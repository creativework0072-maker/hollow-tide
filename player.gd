extends CharacterBody2D
# Mira: walking, jumping, swimming, breath meter, crate pushing, animation and sound.
# Week 5 additions are tagged [WEEK5-FIX] (bug fix) or [WEEK5-FEATURE] (new feature).

const AssetUtil = preload("res://asset_util.gd")

const SPEED := 230.0
const JUMP_VELOCITY := -430.0
const GRAVITY := 1100.0
const MAX_BREATH := 10.0
const COYOTE_TIME := 0.10      # [WEEK5-FEATURE] can still jump 0.1 s after leaving a ledge
const JUMP_BUFFER := 0.10      # [WEEK5-FEATURE] a jump pressed 0.1 s before landing still counts

var breath := MAX_BREATH
var in_water := false
var was_in_water := false
var splash_cooldown := 0.0
var coyote := 0.0
var jump_buffer := 0.0
var sprite: AnimatedSprite2D


func _ready() -> void:
	# Collision shape
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(26, 46)
	cs.shape = rs
	add_child(cs)
	# Animated sprite (11 frames of 32x48): idle 0-1, run 2-5, jump 6, swim 7-10
	sprite = AssetUtil.build_sprite("res://assets/art/mira_sheet.png", 32, 48, {
		"idle": [0, 2, 3.0, true],
		"run": [2, 4, 10.0, true],
		"jump": [6, 1, 1.0, false],
		"swim": [7, 4, 6.0, true],
	})
	sprite.position = Vector2(0, 1)
	add_child(sprite)
	# Camera follows the player inside the level bounds
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.limit_left = 0
	cam.limit_right = get_parent().level_width
	cam.limit_top = -100
	cam.limit_bottom = 720
	add_child(cam)


func _physics_process(delta: float) -> void:
	var main = get_parent()
	in_water = global_position.y > main.water_y
	var head_under: bool = (global_position.y - 23.0) > main.water_y
	var dir := Input.get_axis("move_left", "move_right")

	splash_cooldown -= delta
	if in_water != was_in_water:
		if splash_cooldown <= 0.0:
			main.play_sfx("sfx_splash")
			splash_cooldown = 0.5
		was_in_water = in_water

	if in_water:
		# Swimming: light gravity, jump key = swim up
		velocity.y = min(velocity.y + GRAVITY * 0.2 * delta, 110.0)
		if Input.is_action_pressed("jump"):
			velocity.y = -170.0
		velocity.x = move_toward(velocity.x, dir * SPEED * 0.7, 1500.0 * delta)
		coyote = 0.0
		jump_buffer = 0.0
	else:
		velocity.y += GRAVITY * delta
		# [WEEK5-FEATURE] coyote time + jump buffering make jumping feel more forgiving
		if is_on_floor():
			coyote = COYOTE_TIME
		else:
			coyote -= delta
		if Input.is_action_just_pressed("jump"):
			jump_buffer = JUMP_BUFFER
		else:
			jump_buffer -= delta
		if jump_buffer > 0.0 and coyote > 0.0:
			velocity.y = JUMP_VELOCITY
			jump_buffer = 0.0
			coyote = 0.0
			main.play_sfx("sfx_jump")
		# [WEEK5-FEATURE] variable jump height: release early for a shorter hop
		if Input.is_action_just_released("jump") and velocity.y < -150.0:
			velocity.y *= 0.5
		velocity.x = move_toward(velocity.x, dir * SPEED, 1800.0 * delta)

	# Breath meter: drains with head underwater, refills in air
	if head_under:
		breath -= delta
	else:
		breath = min(MAX_BREATH, breath + delta * 4.0)
	if breath <= 0.0:
		main.respawn()
		return

	move_and_slide()

	# Push physics crates
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col = c.get_collider()
		if col is RigidBody2D:
			col.apply_central_impulse(-c.get_normal() * 20.0)

	_update_animation()

	if global_position.y > 900.0:
		main.respawn()


func _update_animation() -> void:
	var anim := "idle"
	if in_water:
		anim = "swim"
	elif not is_on_floor():
		anim = "jump"
	elif abs(velocity.x) > 10.0:
		anim = "run"
	if abs(velocity.x) > 10.0:
		sprite.flip_h = velocity.x < 0.0
	if sprite.animation != anim:
		sprite.play(anim)
