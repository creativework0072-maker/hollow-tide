extends CharacterBody2D
# Mira: walking, jumping, swimming, breath meter and crate pushing.

const SPEED := 230.0
const JUMP_VELOCITY := -430.0
const GRAVITY := 1100.0
const MAX_BREATH := 10.0

var breath := MAX_BREATH
var in_water := false


func _ready() -> void:
	# Collision shape
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(26, 46)
	cs.shape = rs
	add_child(cs)
	# Placeholder art: yellow raincoat + dark hat
	var body := ColorRect.new()
	body.size = Vector2(26, 46)
	body.position = Vector2(-13, -23)
	body.color = Color("E9C46A")
	add_child(body)
	var hat := ColorRect.new()
	hat.size = Vector2(34, 8)
	hat.position = Vector2(-17, -31)
	hat.color = Color("12263A")
	add_child(hat)
	# Camera follows the player inside the level bounds
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.limit_left = 0
	cam.limit_right = 1800
	cam.limit_top = -100
	cam.limit_bottom = 720
	add_child(cam)


func _physics_process(delta: float) -> void:
	var main = get_parent()
	in_water = global_position.y > main.water_y
	var head_under: bool = (global_position.y - 23.0) > main.water_y
	var dir := Input.get_axis("move_left", "move_right")

	if in_water:
		# Swimming: light gravity, jump key = swim up
		velocity.y = min(velocity.y + GRAVITY * 0.2 * delta, 110.0)
		if Input.is_action_pressed("jump"):
			velocity.y = -170.0
		velocity.x = move_toward(velocity.x, dir * SPEED * 0.7, 1500.0 * delta)
	else:
		velocity.y += GRAVITY * delta
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY
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

	if global_position.y > 900.0:
		main.respawn()
