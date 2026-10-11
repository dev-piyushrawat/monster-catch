extends Node2D
# Monster Catch — Deluxe Edition v2 with fixes. Attach to a Node2D named "Main".

# ---------------------------------------------------------------------
# CONFIG
# ---------------------------------------------------------------------
const W := 720
const H := 1280
const MONSTER_R := 60.0
const MONSTER_Y := 1120.0
const ITEM_R := 26.0
const CATCH_R := MONSTER_R + ITEM_R
const BASE_SPAWN := 0.8
const BOMB_CHANCE := 0.35
const GOLD_CHANCE := 0.05
const SHIELD_CHANCE := 0.05
const SAVE_PATH := "user://save.cfg"
const MIX_RATE := 22050
const HEART_R := 22.0
const HEART_GAP := 54.0
const HEART_Y := 150.0
const SHIELD_TIME := 6.0
const COMBO_TIMEOUT := 5.0
const BG_STRIPS := 24
const BG_TOP_COL := Color(0.039, 0.102, 0.133)
const BG_BOT_COL := Color(0.039, 0.141, 0.075)
const BG_DOT_COL := Color(0.45, 0.85, 0.55)
const BG_FOG_COL := Color(0.08, 0.28, 0.15)
const BG_DOTS := [
	Vector2(60, 180), Vector2(140, 420), Vector2(210, 120), Vector2(300, 300),
	Vector2(95, 640), Vector2(380, 160), Vector2(450, 520), Vector2(520, 260),
	Vector2(600, 400), Vector2(660, 180), Vector2(630, 700), Vector2(560, 860),
	Vector2(480, 740), Vector2(400, 920), Vector2(330, 640), Vector2(250, 820),
	Vector2(170, 940), Vector2(80, 760), Vector2(690, 560), Vector2(40, 420),
]
const MON_PX := 5
const PARTICLE_POOL_SIZE := 12
const TOUCH_COOLDOWN_MS := 400
const SHAPES := ["circle", "star", "heart", "triangle", "diamond"]

# ---------------------------------------------------------------------
# SKINS
# ---------------------------------------------------------------------
const SKINS := [
	{
		"name": "Slime", "unlock": 0,
		"c0": Color(0.03, 0.09, 0.07), "c1": Color(0.08, 0.22, 0.16),
		"c2": Color(0.18, 0.42, 0.28), "c3": Color(0.42, 0.68, 0.46),
		"c4": Color(0.78, 0.94, 0.78),
	},
	{
		"name": "Bonelord", "unlock": 30,
		"c0": Color(0.10, 0.10, 0.13), "c1": Color(0.28, 0.26, 0.24),
		"c2": Color(0.55, 0.50, 0.44), "c3": Color(0.80, 0.75, 0.65),
		"c4": Color(0.98, 0.96, 0.90),
	},
	{
		"name": "Blaze", "unlock": 80,
		"c0": Color(0.10, 0.03, 0.02), "c1": Color(0.35, 0.08, 0.05),
		"c2": Color(0.70, 0.20, 0.08), "c3": Color(0.95, 0.50, 0.15),
		"c4": Color(1.00, 0.90, 0.55),
	},
	{
		"name": "Void", "unlock": 150,
		"c0": Color(0.05, 0.02, 0.10), "c1": Color(0.15, 0.05, 0.28),
		"c2": Color(0.35, 0.15, 0.55), "c3": Color(0.65, 0.40, 0.90),
		"c4": Color(0.95, 0.85, 1.00),
	},
]

# ---------------------------------------------------------------------
# ITEM CLASS
# ---------------------------------------------------------------------
class Item extends RefCounted:
	var x: float
	var y: float
	var speed: float
	var type: String
	var color: Color
	var rot: float
	var spin: float
	var shape: String

	func _init(px: float, py: float, pspeed: float, ptype: String, pcolor: Color, prot: float, pspin: float, pshape: String) -> void:
		x = px; y = py; speed = pspeed
		type = ptype; color = pcolor
		rot = prot; spin = pspin; shape = pshape

# ---------------------------------------------------------------------
# STATE
# ---------------------------------------------------------------------
var monster_x := W / 2.0
var monster_draw_x := W / 2.0
var items: Array[Item] = []
var score := 0
var lives := 3
var game_over := false
var paused := false
var spawn_timer := 0.5
var touch_mode := false
var last_touch_release_ms := -10000
var monster_sx := 1.0
var monster_sy := 1.0
var shake_time := 0.0
var combo := 0
var multiplier := 1
var combo_timer := 0.0
var shield := false
var shield_timer := 0.0
var started := false
var high_score := 0
var current_skin := 0
var skin_colors: Array[Color] = []
var skin_manually_chosen := false
var next_player := 0
var tutorial_shown := false
var tutorial_timer := 0.0
var start_time := 0.0
var start_monster_x := W + 200.0

# Sound settings
var sound_on := true
var music_on := true

# ---------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------
var score_label: Label
var combo_label: Label
var pause_button: Button

var over_bg: ColorRect
var over_label: Label
var final_label: Label
var best_label: Label
var restart_button: Button

var start_bg: ColorRect
var title_label: Label
var subtitle_label: Label
var high_label: Label
var play_button: Button
var skin_button: Button

var pause_bg: ColorRect
var pause_label: Label
var resume_button: Button
var quit_button: Button
var sound_toggle: Button
var music_toggle: Button

var tutorial_label: Label

# ---------------------------------------------------------------------
# AUDIO
# ---------------------------------------------------------------------
var catch_sounds: Array = []
var bomb_sound: AudioStreamWAV
var over_sound: AudioStreamWAV
var gold_sound: AudioStreamWAV
var shield_get_sound: AudioStreamWAV
var shield_block_sound: AudioStreamWAV
var miss_sound: AudioStreamWAV
var unlock_sound: AudioStreamWAV
var music_sound: AudioStreamWAV
var players: Array = []
var music_player: AudioStreamPlayer
var audio_ready := false

var particle_pool: Array[CPUParticles2D] = []

# =====================================================================
# READY
# =====================================================================
func _ready() -> void:
	get_window().size = Vector2i(W, H)
	randomize()
	_load_save()
	_apply_skin()
	_build_ui()
	_build_particle_pool()
	_update_labels()
	_update_combo_label()
	_update_high_label()
	_update_skin_button()
	_update_sound_buttons()
	_set_start_ui(true)
	start_time = 0.0
	start_monster_x = W + 200.0
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		if started and not game_over and not paused:
			_on_pause_pressed()

# =====================================================================
# UI BUILD
# =====================================================================
func _build_ui() -> void:
	# ---- In-game HUD ----
	score_label = Label.new()
	score_label.position = Vector2(20, 18)
	score_label.add_theme_font_size_override("font_size", 44)
	score_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	score_label.add_theme_constant_override("outline_size", 4)
	add_child(score_label)

	combo_label = Label.new()
	combo_label.position = Vector2(20, 78)
	combo_label.add_theme_font_size_override("font_size", 34)
	combo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	combo_label.add_theme_constant_override("outline_size", 3)
	add_child(combo_label)

	# Pause button (top-right, well above hearts)
	pause_button = Button.new()
	pause_button.text = "❚❚"
	pause_button.position = Vector2(W - 110, 20)
	pause_button.size = Vector2(90, 90)
	pause_button.add_theme_font_size_override("font_size", 40)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.20, 0.26, 0.92)
	sb.set_corner_radius_all(45)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.55, 0.60, 0.70)
	pause_button.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate() as StyleBoxFlat
	sbh.bg_color = Color(0.28, 0.30, 0.38, 0.95)
	pause_button.add_theme_stylebox_override("hover", sbh)
	var sbp := sb.duplicate() as StyleBoxFlat
	sbp.bg_color = Color(0.10, 0.11, 0.15, 0.95)
	pause_button.add_theme_stylebox_override("pressed", sbp)
	pause_button.pressed.connect(_on_pause_pressed)
	add_child(pause_button)

	# Tutorial hint
	tutorial_label = Label.new()
	tutorial_label.text = "Drag anywhere to catch!"
	tutorial_label.position = Vector2(0, 900)
	tutorial_label.size = Vector2(W, 60)
	tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_label.add_theme_font_size_override("font_size", 40)
	tutorial_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.9))
	tutorial_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	tutorial_label.add_theme_constant_override("outline_size", 6)
	tutorial_label.modulate.a = 0.0
	add_child(tutorial_label)

	# ---- Game Over overlay ----
	over_bg = ColorRect.new()
	over_bg.color = Color(0, 0, 0, 0.72)
	over_bg.size = Vector2(W, H)
	add_child(over_bg)

	over_label = Label.new()
	over_label.text = "Game Over"
	over_label.position = Vector2(0, 440)
	over_label.size = Vector2(W, 110)
	over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_label.add_theme_font_size_override("font_size", 82)
	over_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	over_label.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.02))
	over_label.add_theme_constant_override("outline_size", 8)
	add_child(over_label)

	final_label = Label.new()
	final_label.position = Vector2(0, 585)
	final_label.size = Vector2(W, 60)
	final_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_label.add_theme_font_size_override("font_size", 52)
	final_label.add_theme_color_override("font_color", Color(1, 1, 1))
	final_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	final_label.add_theme_constant_override("outline_size", 5)
	add_child(final_label)

	best_label = Label.new()
	best_label.position = Vector2(0, 655)
	best_label.size = Vector2(W, 40)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_label.add_theme_font_size_override("font_size", 32)
	best_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	best_label.add_theme_constant_override("outline_size", 4)
	add_child(best_label)

	restart_button = Button.new()
	restart_button.text = "Restart"
	restart_button.position = Vector2(W / 2.0 - 140, 780)
	restart_button.size = Vector2(280, 105)
	restart_button.add_theme_font_size_override("font_size", 46)
	restart_button.pressed.connect(_on_restart_pressed)
	add_child(restart_button)

	# ---- Start screen ----
	start_bg = ColorRect.new()
	start_bg.color = Color(0.05, 0.07, 0.11, 0.95)
	start_bg.size = Vector2(W, H - 280)
	add_child(start_bg)

	title_label = Label.new()
	title_label.text = "Monster Catch!"
	title_label.position = Vector2(0, 380)
	title_label.size = Vector2(W, 130)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 84)
	title_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.8))
	title_label.add_theme_color_override("font_outline_color", Color(0.1, 0.28, 0.15))
	title_label.add_theme_constant_override("outline_size", 10)
	add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Catch the food - Dodge the bombs"
	subtitle_label.position = Vector2(0, 515)
	subtitle_label.size = Vector2(W, 40)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 26)
	subtitle_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.85, 0.9))
	add_child(subtitle_label)

	high_label = Label.new()
	high_label.position = Vector2(0, 590)
	high_label.size = Vector2(W, 50)
	high_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	high_label.add_theme_font_size_override("font_size", 38)
	high_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	high_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0))
	high_label.add_theme_constant_override("outline_size", 5)
	add_child(high_label)

	play_button = Button.new()
	play_button.text = "Play"
	play_button.position = Vector2(W / 2.0 - 140, 700)
	play_button.size = Vector2(280, 105)
	play_button.add_theme_font_size_override("font_size", 48)
	var pb := StyleBoxFlat.new()
	pb.bg_color = Color(0.20, 0.55, 0.32)
	pb.set_corner_radius_all(24)
	pb.set_border_width_all(3)
	pb.border_color = Color(0.55, 0.9, 0.65)
	play_button.add_theme_stylebox_override("normal", pb)
	var pbh := pb.duplicate() as StyleBoxFlat
	pbh.bg_color = Color(0.28, 0.68, 0.42)
	play_button.add_theme_stylebox_override("hover", pbh)
	var pbp := pb.duplicate() as StyleBoxFlat
	pbp.bg_color = Color(0.13, 0.40, 0.24)
	play_button.add_theme_stylebox_override("pressed", pbp)
	play_button.pressed.connect(_on_play_pressed)
	add_child(play_button)

	skin_button = Button.new()
	skin_button.position = Vector2(W / 2.0 - 180, 830)
	skin_button.size = Vector2(360, 70)
	skin_button.add_theme_font_size_override("font_size", 24)
	var kb := StyleBoxFlat.new()
	kb.bg_color = Color(0.16, 0.20, 0.28, 0.9)
	kb.set_corner_radius_all(18)
	kb.set_border_width_all(2)
	kb.border_color = Color(0.5, 0.6, 0.75)
	skin_button.add_theme_stylebox_override("normal", kb)
	var kbh := kb.duplicate() as StyleBoxFlat
	kbh.bg_color = Color(0.24, 0.30, 0.40)
	skin_button.add_theme_stylebox_override("hover", kbh)
	var kbp := kb.duplicate() as StyleBoxFlat
	kbp.bg_color = Color(0.10, 0.13, 0.18)
	skin_button.add_theme_stylebox_override("pressed", kbp)
	skin_button.pressed.connect(_on_skin_pressed)
	add_child(skin_button)

	# ---- Pause overlay ----
	pause_bg = ColorRect.new()
	pause_bg.color = Color(0, 0, 0, 0.82)
	pause_bg.size = Vector2(W, H)
	add_child(pause_bg)

	pause_label = Label.new()
	pause_label.text = "Paused"
	pause_label.position = Vector2(0, 380)
	pause_label.size = Vector2(W, 100)
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.add_theme_font_size_override("font_size", 78)
	pause_label.add_theme_color_override("font_color", Color(1, 1, 1))
	pause_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	pause_label.add_theme_constant_override("outline_size", 6)
	add_child(pause_label)

	resume_button = Button.new()
	resume_button.text = "Resume"
	resume_button.position = Vector2(W / 2.0 - 140, 540)
	resume_button.size = Vector2(280, 100)
	resume_button.add_theme_font_size_override("font_size", 44)
	resume_button.pressed.connect(_on_resume_pressed)
	add_child(resume_button)

	sound_toggle = Button.new()
	sound_toggle.position = Vector2(W / 2.0 - 140, 660)
	sound_toggle.size = Vector2(280, 80)
	sound_toggle.add_theme_font_size_override("font_size", 30)
	sound_toggle.pressed.connect(_on_sound_toggle)
	add_child(sound_toggle)

	music_toggle = Button.new()
	music_toggle.position = Vector2(W / 2.0 - 140, 760)
	music_toggle.size = Vector2(280, 80)
	music_toggle.add_theme_font_size_override("font_size", 30)
	music_toggle.pressed.connect(_on_music_toggle)
	add_child(music_toggle)

	quit_button = Button.new()
	quit_button.text = "Quit"
	quit_button.position = Vector2(W / 2.0 - 140, 880)
	quit_button.size = Vector2(280, 100)
	quit_button.add_theme_font_size_override("font_size", 44)
	quit_button.pressed.connect(_on_quit_pressed)
	add_child(quit_button)

	_set_over_ui(false)
	_set_pause_ui(false)
	pause_button.visible = false

func _set_over_ui(s: bool) -> void:
	over_bg.visible = s
	over_label.visible = s
	final_label.visible = s
	best_label.visible = s
	restart_button.visible = s

func _set_start_ui(s: bool) -> void:
	start_bg.visible = s
	title_label.visible = s
	subtitle_label.visible = s
	high_label.visible = s
	play_button.visible = s
	skin_button.visible = s

func _set_pause_ui(s: bool) -> void:
	pause_bg.visible = s
	pause_label.visible = s
	resume_button.visible = s
	sound_toggle.visible = s
	music_toggle.visible = s
	quit_button.visible = s

# =====================================================================
# INPUT
# =====================================================================
func _input(event: InputEvent) -> void:
	if game_over or not started or paused:
		return
	if event is InputEventScreenTouch:
		var ev := event as InputEventScreenTouch
		touch_mode = ev.pressed
		if not ev.pressed:
			last_touch_release_ms = Time.get_ticks_msec()
	elif event is InputEventScreenDrag:
		touch_mode = true
		_drag((event as InputEventScreenDrag).relative.x)
	elif event is InputEventMouseMotion and not touch_mode:
		if Time.get_ticks_msec() - last_touch_release_ms < TOUCH_COOLDOWN_MS:
			return
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_drag(motion.relative.x)

func _drag(dx: float) -> void:
	monster_x = clampf(monster_x + dx, MONSTER_R, W - MONSTER_R)

# =====================================================================
# PROCESS
# =====================================================================
func _process(delta: float) -> void:
	if not started and not game_over:
		_animate_start_screen(delta)

	if tutorial_timer > 0.0:
		tutorial_timer -= delta
		var a := 0.0
		if tutorial_timer > 2.2:
			a = clampf((3.0 - tutorial_timer) / 0.4, 0.0, 1.0)
		elif tutorial_timer > 0.6:
			a = 1.0
		else:
			a = clampf(tutorial_timer / 0.6, 0.0, 1.0)
		tutorial_label.modulate.a = a

	if paused:
		return
	_update_shake(delta)
	monster_sx = lerpf(monster_sx, 1.0, 10.0 * delta)
	monster_sy = lerpf(monster_sy, 1.0, 10.0 * delta)
	monster_draw_x = lerpf(monster_draw_x, monster_x, 25.0 * delta)

	if not started or game_over:
		return

	if Input.is_action_pressed("ui_left"):
		_drag(-600.0 * delta)
	if Input.is_action_pressed("ui_right"):
		_drag(600.0 * delta)

	if shield:
		shield_timer -= delta
		if shield_timer <= 0.0:
			shield = false

	if combo > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
			multiplier = 1
			_update_combo_label()

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_item()
		spawn_timer = BASE_SPAWN * clampf(1.0 - score * 0.002, 0.65, 1.0)

	var speed_mul := minf(1.0 + score * 0.006, 2.0)
	for i in range(items.size() - 1, -1, -1):
		var it := items[i]
		it.y += it.speed * speed_mul * delta
		it.rot += it.spin * delta
		var dx := it.x - monster_x
		var dy := it.y - MONSTER_Y
		if dx * dx + dy * dy < CATCH_R * CATCH_R:
			var pos := Vector2(it.x, it.y)
			if it.type == "bomb":
				_hit_bomb(pos)
			elif it.type == "shield":
				_catch_shield(pos)
			else:
				_eat_food(pos, it.color, it.type == "gold")
			items.remove_at(i)
		elif it.y > H + ITEM_R:
			if it.type == "food" or it.type == "gold":
				_sfx_miss()
			items.remove_at(i)

	queue_redraw()

# ---------------------------------------------------------------------
# Title screen animation
# ---------------------------------------------------------------------
func _animate_start_screen(delta: float) -> void:
	start_time += delta
	start_monster_x = lerpf(start_monster_x, W / 2.0, 2.5 * delta)
	title_label.position.y = 380 + sin(start_time * 2.4) * 12
	var slide := clampf((start_time - 0.3) * 2.0, 0.0, 1.0)
	play_button.modulate.a = slide
	skin_button.modulate.a = slide
	high_label.modulate.a = slide
	subtitle_label.modulate.a = slide
	title_label.modulate.a = clampf(slide * 1.3, 0.0, 1.0)
	queue_redraw()

# =====================================================================
# SPAWNING
# =====================================================================
func _spawn_item() -> void:
	var roll := randf()
	var type := "food"
	if roll < BOMB_CHANCE:
		type = "bomb"
	elif roll < BOMB_CHANCE + GOLD_CHANCE:
		type = "gold"
	elif roll < BOMB_CHANCE + GOLD_CHANCE + SHIELD_CHANCE:
		type = "shield"
	var color := Color(0.16, 0.16, 0.2)
	var shape := "circle"
	var speed := randf_range(200.0, 290.0)
	if type == "food":
		color = Color.from_hsv(randf(), 0.75, 0.95)
		shape = SHAPES[randi() % SHAPES.size()]
	elif type == "gold":
		color = Color(1.0, 0.8, 0.2)
		shape = "star"
		speed = randf_range(220.0, 300.0)
	elif type == "shield":
		color = Color(0.3, 0.75, 1.0)
		shape = "circle"
		speed = randf_range(200.0, 260.0)
	elif type == "bomb":
		# Bombs fall faster — more dangerous
		speed = randf_range(280.0, 380.0)
	items.append(Item.new(
		randf_range(ITEM_R * 1.4, W - ITEM_R * 1.4),
		-ITEM_R * 1.4,
		speed,
		type, color,
		randf() * TAU,
		randf_range(-2.5, 2.5),
		shape
	))
# =====================================================================
# ACTIONS
# =====================================================================
func _eat_food(pos: Vector2, color: Color, golden: bool) -> void:
	combo += 1
	combo_timer = COMBO_TIMEOUT
	multiplier = 1 + int(combo / 5.0)
	var gain := 5 if golden else multiplier
	score += gain
	_update_labels()
	_update_combo_label()
	_burst(pos, color)
	var pop_col := Color(1.0, 0.85, 0.35) if golden else Color(1, 1, 1)
	if multiplier > 1 and not golden:
		pop_col = Color(1.0, 0.75, 0.3)
	_score_popup(pos, "+%d" % gain, pop_col)
	if golden:
		_sfx_gold()
		Input.vibrate_handheld(40)
	else:
		_sfx_catch()
	monster_sx = 1.35
	monster_sy = 0.65

func _hit_bomb(pos: Vector2) -> void:
	_burst(pos, Color(0.95, 0.3, 0.2))
	if shield:
		shield = false
		_score_popup(pos, "Blocked!", Color(0.6, 0.9, 1.0))
		_sfx_shield_block()
		monster_sx = 1.25
		monster_sy = 0.8
		return
	lives -= 1
	combo = 0
	multiplier = 1
	combo_timer = 0.0
	Input.vibrate_handheld(150)
	_update_labels()
	_update_combo_label()
	_sfx_bomb()
	monster_sx = 0.7
	monster_sy = 1.3
	shake_time = 0.3
	if lives <= 0:
		_show_game_over()

func _catch_shield(pos: Vector2) -> void:
	shield = true
	shield_timer = SHIELD_TIME
	_burst(pos, Color(0.3, 0.75, 1.0))
	_score_popup(pos, "Shield!", Color(0.5, 0.9, 1.0))
	_sfx_shield_get()
	Input.vibrate_handheld(25)
	monster_sx = 1.35
	monster_sy = 0.65

# =====================================================================
# SCORE POPUP
# =====================================================================
func _score_popup(pos: Vector2, txt: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 68)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.position = pos + Vector2(-90, -110)
	lbl.size = Vector2(180, 90)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.pivot_offset = Vector2(90, 45)
	lbl.scale = Vector2(0.2, 0.2)
	add_child(lbl)
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector2(1.25, 1.25), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", lbl.position.y - 140.0, 0.95).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.55).set_delay(0.4)
	tw.set_parallel(false)
	tw.tween_callback(lbl.queue_free)

# =====================================================================
# UNLOCK POPUP
# =====================================================================
func _unlock_popup(title: String, subtitle: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = title + "\n" + subtitle
	lbl.add_theme_font_size_override("font_size", 52)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.position = Vector2(0, 180)
	lbl.size = Vector2(W, 200)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.pivot_offset = Vector2(W / 2.0, 100)
	lbl.scale = Vector2(0.3, 0.3)
	lbl.z_index = 100
	add_child(lbl)
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector2(1.15, 1.15), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.6).set_delay(2.0)
	tw.set_parallel(false)
	tw.tween_callback(lbl.queue_free)

# =====================================================================
# PARTICLES
# =====================================================================
func _build_particle_pool() -> void:
	for i in PARTICLE_POOL_SIZE:
		var p := CPUParticles2D.new()
		p.amount = 16
		p.one_shot = true
		p.explosiveness = 1.0
		p.lifetime = 0.5
		p.direction = Vector2(0, -1)
		p.spread = 180.0
		p.initial_velocity_min = 120.0
		p.initial_velocity_max = 300.0
		p.gravity = Vector2(0, 600)
		p.scale_amount_min = 4.0
		p.scale_amount_max = 8.0
		p.emitting = false
		add_child(p)
		particle_pool.append(p)

func _burst(pos: Vector2, color: Color) -> void:
	var chosen: CPUParticles2D = null
	for p in particle_pool:
		if not p.emitting:
			chosen = p
			break
	if chosen == null:
		chosen = particle_pool[0]
		chosen.emitting = false
	chosen.position = pos
	chosen.color = color
	chosen.emitting = true

# =====================================================================
# SHAKE
# =====================================================================
func _update_shake(delta: float) -> void:
	if shake_time > 0.0:
		shake_time = maxf(shake_time - delta, 0.0)
		var amt := 18.0 * shake_time / 0.3
		position = Vector2(randf_range(-amt, amt), randf_range(-amt, amt))
	else:
		position = Vector2.ZERO

# =====================================================================
# LABELS
# =====================================================================
func _update_labels() -> void:
	score_label.text = "Score: %d" % score

func _update_combo_label() -> void:
	combo_label.text = "Combo x%d" % multiplier
	if multiplier > 1:
		combo_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.2))
	else:
		combo_label.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))

func _update_high_label() -> void:
	high_label.text = "High Score: %d" % high_score

func _update_skin_button() -> void:
	var sk: Dictionary = SKINS[current_skin]
	var unlocked := 0
	for i in SKINS.size():
		if high_score >= int(SKINS[i]["unlock"]):
			unlocked = i + 1
	if unlocked < SKINS.size():
		var nxt: Dictionary = SKINS[unlocked]
		skin_button.text = "%s  -  Next: %s at %d pts" % [sk["name"], nxt["name"], int(nxt["unlock"])]
	else:
		skin_button.text = "%s  -  All unlocked!" % sk["name"]

func _update_sound_buttons() -> void:
	sound_toggle.text = "Sound: %s" % ("ON" if sound_on else "OFF")
	music_toggle.text = "Music: %s" % ("ON" if music_on else "OFF")

# =====================================================================
# GAME OVER
# =====================================================================
func _show_game_over() -> void:
	game_over = true
	pause_button.visible = false
	if music_player:
		music_player.stop()
	final_label.text = "Score: %d" % score

	var old_high := high_score
	if score > high_score:
		high_score = score
		best_label.text = "New High Score!"
		best_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.2))
		_sfx_unlock()
	else:
		best_label.text = "Best: %d" % high_score
		best_label.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))

	# Check for newly unlocked skins
	var newly_unlocked: Array[int] = []
	for i in SKINS.size():
		var u := int(SKINS[i]["unlock"])
		if old_high < u and high_score >= u:
			newly_unlocked.append(i)

	if not newly_unlocked.is_empty():
		var first: int = newly_unlocked[0]
		_unlock_popup("SKIN UNLOCKED!", str(SKINS[first]["name"]), Color(0.4, 1.0, 0.6))
		if not skin_manually_chosen:
			current_skin = first
			_apply_skin()

	_save_save()
	_update_skin_button()
	_set_over_ui(true)
	_sfx_game_over()

# =====================================================================
# SAVE / LOAD
# =====================================================================
func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = int(cfg.get_value("save", "high_score", 0))
		current_skin = int(cfg.get_value("save", "skin", 0))
		tutorial_shown = bool(cfg.get_value("save", "tutorial_shown", false))
		skin_manually_chosen = bool(cfg.get_value("save", "skin_manual", false))
		sound_on = bool(cfg.get_value("save", "sound_on", true))
		music_on = bool(cfg.get_value("save", "music_on", true))
	if current_skin < 0 or current_skin >= SKINS.size():
		current_skin = 0

func _save_save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("save", "high_score", high_score)
	cfg.set_value("save", "skin", current_skin)
	cfg.set_value("save", "tutorial_shown", tutorial_shown)
	cfg.set_value("save", "skin_manual", skin_manually_chosen)
	cfg.set_value("save", "sound_on", sound_on)
	cfg.set_value("save", "music_on", music_on)
	cfg.save(SAVE_PATH)

func _apply_skin() -> void:
	var sk: Dictionary = SKINS[current_skin]
	skin_colors = [sk["c0"], sk["c1"], sk["c2"], sk["c3"], sk["c4"]]

# =====================================================================
# STATE TRANSITIONS
# =====================================================================
func _reset_game() -> void:
	score = 0
	lives = 3
	combo = 0
	multiplier = 1
	combo_timer = 0.0
	items.clear()
	shield = false
	shield_timer = 0.0
	monster_x = W / 2.0
	monster_draw_x = W / 2.0
	spawn_timer = 0.5
	game_over = false
	paused = false
	monster_sx = 1.0
	monster_sy = 1.0
	shake_time = 0.0
	position = Vector2.ZERO
	_update_labels()
	_update_combo_label()
	_update_high_label()
	_update_skin_button()
	_set_over_ui(false)
	pause_button.visible = true
	queue_redraw()

func _on_play_pressed() -> void:
	_ensure_audio()
	_set_start_ui(false)
	_reset_game()
	started = true
	start_monster_x = W + 200.0
	if not tutorial_shown:
		tutorial_timer = 3.0
		tutorial_shown = true
		_save_save()
	if music_player and music_on:
		music_player.stream_paused = false
		if not music_player.playing:
			music_player.play()

func _on_restart_pressed() -> void:
	_reset_game()
	if music_player and music_on:
		if not music_player.playing:
			music_player.play()
		music_player.stream_paused = false

func _on_pause_pressed() -> void:
	if not started or game_over:
		return
	paused = true
	pause_button.visible = false
	_set_pause_ui(true)
	if music_player:
		music_player.stream_paused = true

func _on_resume_pressed() -> void:
	paused = false
	_set_pause_ui(false)
	pause_button.visible = true
	if music_player and music_on:
		music_player.stream_paused = false

func _on_quit_pressed() -> void:
	paused = false
	_go_to_start()

func _on_sound_toggle() -> void:
	sound_on = not sound_on
	_update_sound_buttons()
	_save_save()

func _on_music_toggle() -> void:
	music_on = not music_on
	_update_sound_buttons()
	if music_player:
		if music_on and started and not game_over and not paused:
			if not music_player.playing:
				music_player.play()
			music_player.stream_paused = false
		else:
			music_player.stream_paused = true
	_save_save()

func _on_skin_pressed() -> void:
	var unlocked := 0
	for i in SKINS.size():
		if high_score >= int(SKINS[i]["unlock"]):
			unlocked = i + 1
	if unlocked <= 1:
		_unlock_popup("LOCKED", "Reach %d pts to unlock Bonelord" % int(SKINS[1]["unlock"]), Color(1.0, 0.75, 0.3))
		return
	current_skin = (current_skin + 1) % unlocked
	skin_manually_chosen = true
	_apply_skin()
	_save_save()
	_update_skin_button()
	_sfx_unlock()

func _go_to_start() -> void:
	started = false
	game_over = false
	items.clear()
	monster_x = W / 2.0
	monster_draw_x = W / 2.0
	start_monster_x = W + 200.0
	start_time = 0.0
	shake_time = 0.0
	position = Vector2.ZERO
	_update_high_label()
	_update_skin_button()
	_set_pause_ui(false)
	_set_over_ui(false)
	pause_button.visible = false
	_set_start_ui(true)
	if music_player:
		music_player.stop()
	queue_redraw()

# =====================================================================
# AUDIO BUILD
# =====================================================================
func _ensure_audio() -> void:
	if audio_ready:
		return
	audio_ready = true
	_build_audio()

func _build_audio() -> void:
	for i in 15:
		var freq := 440.0 * pow(2.0, float(i) / 12.0)
		catch_sounds.append(_make_wav(_tone(freq, 0.2, 0.5, 0, 14.0)))
	var b := _mix(_tone(95.0, 0.3, 0.55, 1, 9.0), _tone(0.0, 0.22, 0.4, 2, 16.0), 0)
	bomb_sound = _make_wav(b)
	var g := PackedFloat32Array()
	var notes := [392.0, 330.0, 262.0]
	for i in notes.size():
		g = _mix(g, _tone(notes[i], 0.3, 0.5, 0, 7.0), int(i * 0.22 * MIX_RATE))
	over_sound = _make_wav(g)
	var gd := PackedFloat32Array()
	gd = _mix(gd, _tone(660.0, 0.12, 0.45, 0, 12.0), 0)
	gd = _mix(gd, _tone(880.0, 0.12, 0.45, 0, 12.0), int(0.08 * MIX_RATE))
	gd = _mix(gd, _tone(1320.0, 0.25, 0.45, 0, 10.0), int(0.16 * MIX_RATE))
	gold_sound = _make_wav(gd)
	var sg := PackedFloat32Array()
	sg = _mix(sg, _tone(330.0, 0.15, 0.45, 0, 10.0), 0)
	sg = _mix(sg, _tone(660.0, 0.2, 0.45, 0, 8.0), int(0.1 * MIX_RATE))
	shield_get_sound = _make_wav(sg)
	var sb := _mix(_tone(520.0, 0.08, 0.4, 1, 25.0), _tone(780.0, 0.15, 0.35, 0, 12.0), int(0.05 * MIX_RATE))
	shield_block_sound = _make_wav(sb)
	miss_sound = _make_wav(_tone(180.0, 0.12, 0.25, 0, 20.0))
	var ul := PackedFloat32Array()
	ul = _mix(ul, _tone(523.25, 0.15, 0.5, 0, 10.0), 0)
	ul = _mix(ul, _tone(659.25, 0.15, 0.5, 0, 10.0), int(0.09 * MIX_RATE))
	ul = _mix(ul, _tone(783.99, 0.15, 0.5, 0, 10.0), int(0.18 * MIX_RATE))
	ul = _mix(ul, _tone(1046.5, 0.35, 0.55, 0, 6.0), int(0.27 * MIX_RATE))
	unlock_sound = _make_wav(ul)
	music_sound = _build_music()
	music_player = AudioStreamPlayer.new()
	music_player.stream = music_sound
	music_player.volume_db = -8.0
	add_child(music_player)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)

# ---------------------------------------------------------------------
# Music generation
# ---------------------------------------------------------------------
func _build_music() -> AudioStreamWAV:
	var step := 0.15
	var bars := 4
	var steps_per_bar := 8
	var total_steps := bars * steps_per_bar
	var total_samples := int(step * total_steps * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(total_samples)
	var chords := [
		{"root": 110.00, "notes": [440.00, 523.25, 659.25]},
		{"root": 87.31,  "notes": [349.23, 440.00, 523.25]},
		{"root": 130.81, "notes": [523.25, 659.25, 783.99]},
		{"root": 98.00,  "notes": [392.00, 493.88, 587.33]},
	]
	for bar in bars:
		var ch: Dictionary = chords[bar]
		var bar_start := float(bar * steps_per_bar) * step
		for s in [0, 2, 4, 6]:
			_add_tone(buf, ch["root"], 0.24, 0.32, bar_start + s * step, 1)
		var mel: Array = ch["notes"]
		for s in steps_per_bar:
			var n: float = mel[s % mel.size()]
			var vol := 0.16 if s % 2 == 0 else 0.10
			_add_tone(buf, n, 0.14, vol, bar_start + s * step, 0)
	return _make_looped_wav(buf)

func _add_tone(buf: PackedFloat32Array, freq: float, dur: float, vol: float, at_sec: float, kind: int) -> void:
	var offset := int(at_sec * MIX_RATE)
	var n := int(dur * MIX_RATE)
	for i in n:
		var idx := offset + i
		if idx >= buf.size():
			break
		var t := float(i) / MIX_RATE
		var env := minf(t / 0.005, 1.0) * exp(-t * 7.0) * vol
		var ph := TAU * freq * t
		var w := 0.0
		if kind == 0:
			w = sin(ph) * 0.7 + sin(2.0 * ph) * 0.2 + sin(3.0 * ph) * 0.1
		elif kind == 1:
			w = sin(ph) * 0.6 + sin(2.0 * ph) * 0.4
		buf[idx] += w * env

# ---------------------------------------------------------------------
# Tone generation
# ---------------------------------------------------------------------
func _tone(freq: float, dur: float, vol: float, kind: int, decay: float) -> PackedFloat32Array:
	var n := int(dur * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var env := minf(t / 0.005, 1.0) * exp(-t * decay) * vol
		var ph := TAU * freq * t
		var w := 0.0
		match kind:
			0:
				w = sin(ph) * 0.75 + sin(2.0 * ph) * 0.25
			1:
				w = 1.0 if fmod(ph, TAU) < PI else -1.0
			2:
				w = randf_range(-1.0, 1.0)
		out[i] = w * env
	return out

func _mix(dest: PackedFloat32Array, src: PackedFloat32Array, offset: int) -> PackedFloat32Array:
	var need := offset + src.size()
	if dest.size() < need:
		dest.resize(need)
	for i in src.size():
		dest[offset + i] += src[i]
	return dest

func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -0.9, 0.9) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav

func _make_looped_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav := _make_wav(samples)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = samples.size()
	return wav

# ---------------------------------------------------------------------
# SFX wrappers
# ---------------------------------------------------------------------
func _play_sound(stream: AudioStream) -> void:
	if not sound_on:
		return
	if players.is_empty() or stream == null:
		return
	var p: AudioStreamPlayer = players[next_player]
	next_player = (next_player + 1) % players.size()
	p.stream = stream
	p.play()

func _sfx_catch() -> void:
	if not catch_sounds.is_empty():
		_play_sound(catch_sounds[mini(combo, 14)])

func _sfx_bomb() -> void:
	_play_sound(bomb_sound)

func _sfx_game_over() -> void:
	_play_sound(over_sound)

func _sfx_gold() -> void:
	_play_sound(gold_sound)

func _sfx_shield_get() -> void:
	_play_sound(shield_get_sound)

func _sfx_shield_block() -> void:
	_play_sound(shield_block_sound)

func _sfx_miss() -> void:
	_play_sound(miss_sound)

func _sfx_unlock() -> void:
	_play_sound(unlock_sound)

# =====================================================================
# DRAW
# =====================================================================
func _draw() -> void:
	var now_ms := Time.get_ticks_msec()
	var now_s := now_ms / 1000.0
	_draw_background(now_s)

	# Title screen: draw monster walking in, then return
	if not started and not game_over:
		var sm := Vector2(start_monster_x, MONSTER_Y)
		_draw_monster(sm, now_s)
		return

	# In-game items
	for it in items:
		var pos := Vector2(it.x, it.y)
		if it.type == "gold":
			_draw_gold(pos, it.rot, now_s)
		elif it.type == "bomb":
			_draw_bomb(pos, it.rot, now_s)
		elif it.type == "shield":
			_draw_shape(pos, ITEM_R, "circle", it.color, it.rot)
			draw_arc(pos, ITEM_R * 0.55, 0.0, TAU, 24, Color(1, 1, 1, 0.85), 4.0)
		else:
			_draw_shape(pos, ITEM_R, it.shape, it.color, it.rot)

	var m := Vector2(monster_draw_x, MONSTER_Y)
	_draw_monster(m, now_s)

	# Shield effect around monster
	if shield and (shield_timer > 2.0 or int(now_ms / 150) % 2 == 0):
		var pulse := 0.5 + 0.5 * sin(now_ms / 200.0)
		var r := MONSTER_R + 16.0 + pulse * 5.0
		draw_circle(m, r, Color(0.35, 0.75, 1.0, 0.12))
		draw_arc(m, r, 0.0, TAU, 40, Color(0.5, 0.85, 1.0, 0.9), 3.0)

	# Hearts row (well below the pause button)
	for i in 3:
		var hc := Vector2(W - 124.0 - float(i) * HEART_GAP, HEART_Y)
		var pts := _heart_points(hc, HEART_R)
		if i < lives:
			draw_colored_polygon(pts, Color(0.92, 0.16, 0.22))
			draw_circle(hc + Vector2(-HEART_R * 0.35, -HEART_R * 0.5), HEART_R * 0.15, Color(1, 1, 1, 0.5))
		else:
			draw_colored_polygon(pts, Color(0.13, 0.10, 0.12, 0.6))
			draw_polyline(pts, Color(0.45, 0.24, 0.28), 2.5, true)

# ---------------------------------------------------------------------
# Bomb rendering (bright red, glowing, with warning ring)
# ---------------------------------------------------------------------
func _draw_bomb(pos: Vector2, rot: float, t: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 8.0)
	# Outer glow
	draw_circle(pos, ITEM_R * (1.55 + pulse * 0.15), Color(1.0, 0.15, 0.1, 0.28))
	draw_circle(pos, ITEM_R * 1.2, Color(1.0, 0.25, 0.15, 0.35))
	# Dark core with bright red shell
	draw_circle(pos, ITEM_R, Color(0.18, 0.05, 0.05))
	draw_circle(pos, ITEM_R * 0.85, Color(0.55, 0.10, 0.10))
	draw_circle(pos + Vector2(-ITEM_R * 0.3, -ITEM_R * 0.3), ITEM_R * 0.28, Color(1.0, 0.4, 0.3, 0.9))
	# Warning ring
	draw_arc(pos, ITEM_R * (1.05 + pulse * 0.08), 0.0, TAU, 32, Color(1.0, 0.35, 0.2, 0.9), 3.0)
	# Bright fuse with spark
	var fuse := pos + Vector2(0, -ITEM_R * 0.75).rotated(rot)
	draw_circle(fuse, 8.0, Color(1.0, 0.6, 0.2))
	draw_circle(fuse, 4.0, Color(1.0, 1.0, 0.7))

# ---------------------------------------------------------------------
# Food shapes
# ---------------------------------------------------------------------
func _draw_shape(center: Vector2, radius: float, shape: String, col: Color, rot: float) -> void:
	match shape:
		"circle":
			draw_circle(center, radius, col)
			draw_circle(center + Vector2(-radius * 0.35, -radius * 0.35), radius * 0.22, col.lightened(0.5))
		"star":
			draw_colored_polygon(_star_points(center, radius * 1.15, radius * 0.5, rot), col)
			draw_colored_polygon(_star_points(center, radius * 0.7, radius * 0.3, rot), col.lightened(0.35))
		"heart":
			draw_colored_polygon(_heart_points(center, radius * 1.45), col)
			draw_circle(center + Vector2(-radius * 0.4, -radius * 0.4), radius * 0.18, col.lightened(0.5))
		"triangle":
			var pts := PackedVector2Array()
			for i in 3:
				var a := rot + float(i) * TAU / 3.0 - PI / 2.0
				pts.append(center + Vector2(cos(a), sin(a)) * radius * 1.15)
			draw_colored_polygon(pts, col)
			draw_circle(center + Vector2(-radius * 0.2, -radius * 0.3), radius * 0.15, col.lightened(0.4))
		"diamond":
			var pts := PackedVector2Array()
			for i in 4:
				var a := rot + float(i) * TAU / 4.0 - PI / 2.0
				pts.append(center + Vector2(cos(a), sin(a)) * radius * 1.2)
			draw_colored_polygon(pts, col)
			draw_circle(center + Vector2(-radius * 0.2, -radius * 0.3), radius * 0.15, col.lightened(0.45))
		_:
			draw_circle(center, radius, col)

# ---------------------------------------------------------------------
# Gold star
# ---------------------------------------------------------------------
func _star_points(center: Vector2, outer: float, inner: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var r := outer if i % 2 == 0 else inner
		var a := rot + float(i) * PI / 5.0 - PI / 2.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts

func _draw_gold(pos: Vector2, rot: float, t: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 6.0 + rot)
	draw_circle(pos, ITEM_R * (1.7 + pulse * 0.3), Color(1.0, 0.85, 0.2, 0.15))
	draw_circle(pos, ITEM_R * 1.3, Color(1.0, 0.85, 0.2, 0.25))
	var spin := rot * 0.3
	draw_colored_polygon(_star_points(pos, ITEM_R * 1.3, ITEM_R * 0.6, spin), Color(1.0, 0.72, 0.1))
	draw_colored_polygon(_star_points(pos, ITEM_R * 0.9, ITEM_R * 0.4, spin), Color(1.0, 0.92, 0.45))
	draw_string(ThemeDB.fallback_font, pos + Vector2(-20, 9), "5", HORIZONTAL_ALIGNMENT_CENTER, 40.0, 26, Color(0.55, 0.3, 0.0))
	for k in 3:
		var a := t * 3.0 + float(k) * TAU / 3.0
		draw_circle(pos + Vector2(cos(a), sin(a)) * ITEM_R * 1.8, 3.0 + pulse * 2.0, Color.WHITE)

# ---------------------------------------------------------------------
# Heart shape helper
# ---------------------------------------------------------------------
func _heart_points(center: Vector2, size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var s := size / 16.0
	for i in 25:
		var t := TAU * float(i) / 24.0
		var hx := 16.0 * pow(sin(t), 3.0)
		var hy := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(center + Vector2(hx, -hy) * s)
	return pts

# ---------------------------------------------------------------------
# Background
# ---------------------------------------------------------------------
func _draw_background(now: float) -> void:
	var strip_h := float(H) / float(BG_STRIPS)
	for i in BG_STRIPS:
		var c := BG_TOP_COL.lerp(BG_BOT_COL, float(i) / float(BG_STRIPS - 1))
		draw_rect(Rect2(0.0, float(i) * strip_h, float(W), strip_h + 1.0), c)
	for i in BG_DOTS.size():
		var d: Vector2 = BG_DOTS[i]
		var tw := 0.5 + 0.5 * sin(now * 0.9 + float(i) * 1.9)
		var a := 0.10 + 0.25 * tw
		var s := 3.0 + float(i % 3)
		draw_rect(Rect2(d.x, d.y, s, s), Color(BG_DOT_COL, a))
	draw_rect(Rect2(0.0, H - 160.0, W, 160.0), Color(BG_FOG_COL, 0.07))
	draw_rect(Rect2(0.0, H - 115.0, W, 115.0), Color(BG_FOG_COL, 0.09))
	draw_rect(Rect2(0.0, H - 75.0, W, 75.0), Color(BG_FOG_COL, 0.12))
	draw_rect(Rect2(30.0, H - 130.0, 280.0, 50.0), Color(BG_FOG_COL, 0.08))
	draw_rect(Rect2(420.0, H - 150.0, 260.0, 60.0), Color(BG_FOG_COL, 0.08))
	draw_rect(Rect2(240.0, H - 70.0, 320.0, 40.0), Color(BG_FOG_COL, 0.10))

# ---------------------------------------------------------------------
# Pixel helpers
# ---------------------------------------------------------------------
func _px(gx: int, gy: int, gw: int, gh: int, col: Color) -> void:
	draw_rect(Rect2(float(gx * MON_PX), float(gy * MON_PX), float(gw * MON_PX), float(gh * MON_PX)), col)

func _px_ellipse(cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	var y0 := int(floor(cy - ry))
	var y1 := int(ceil(cy + ry))
	for gy in range(y0, y1):
		var ny := ((float(gy) + 0.5) - cy) / ry
		var k := 1.0 - ny * ny
		if k <= 0.0:
			continue
		var hw := sqrt(k) * rx
		var x0 := int(round(cx - hw))
		var x1 := int(round(cx + hw))
		if x1 > x0:
			_px(x0, gy, x1 - x0, 1, col)

# ---------------------------------------------------------------------
# Monster target
# ---------------------------------------------------------------------
func _monster_target(m: Vector2) -> Vector2:
	var best := Vector2(-9999.0, -9999.0)
	var best_score := INF
	for it in items:
		if it.type != "food" and it.type != "gold":
			continue
		var p := Vector2(it.x, it.y)
		if p.y > m.y + 60.0:
			continue
		var d := p.distance_to(m) + p.y * 0.4
		if d < best_score:
			best_score = d
			best = p
	return best

# ---------------------------------------------------------------------
# Monster drawing
# ---------------------------------------------------------------------
func _draw_monster(m: Vector2, now: float) -> void:
	draw_set_transform(m, 0.0, Vector2(monster_sx, monster_sy))
	var tgt := _monster_target(m)
	var has_t := tgt.x > -9000.0
	var dist := 9999.0
	if has_t:
		dist = tgt.distance_to(m)
	var jaw := 0
	if dist < 300.0:
		jaw = int(round(3.0 * (1.0 - dist / 300.0)))
	var look_x := 0
	var look_y := 0
	if has_t:
		var dir := (tgt - m).normalized()
		look_x = clampi(int(round(dir.x * 1.5)), -1, 1)
		look_y = clampi(int(round(dir.y)), -1, 1)
	var blink := fmod(now, 3.5) > 3.3
	_draw_torso()
	_draw_skull(jaw, look_x, look_y, blink)
	var bob_l := int(round(sin(now * 2.0) * 2.0))
	var bob_r := int(round(sin(now * 2.0 + 1.7) * 2.0))
	_draw_bone_hand(-15, 9 + bob_l, -1)
	_draw_bone_hand(15, 9 + bob_r, 1)
	draw_set_transform(Vector2.ZERO)

func _draw_skull(jaw: int, look_x: int, look_y: int, blink: bool) -> void:
	_px_ellipse(0.0, -0.5, 10.5, 9.5, skin_colors[1])
	_px_ellipse(0.0, -0.5, 9.5, 8.5, skin_colors[2])
	_px_ellipse(-1.5, -2.5, 6.5, 5.5, skin_colors[3])
	for k in 2:
		var side := 1 - 2 * k
		var ex := 5 * side
		_px_ellipse(float(ex), -3.0, 3.6, 3.6, skin_colors[0])
		if blink:
			_px(ex - 3, -3, 6, 1, skin_colors[2])
		else:
			_px_ellipse(float(ex), -3.0, 2.6, 2.6, skin_colors[4])
			_px(ex - 1 + look_x, -4 + look_y, 2, 2, skin_colors[0])
			_px(ex - 1 + look_x, -4 + look_y, 1, 1, skin_colors[3])
	_px(-2, 0, 1, 2, skin_colors[0])
	_px(1, 0, 1, 2, skin_colors[0])
	var mh := 4 + jaw
	_px(-8, 2, 16, mh + 2, skin_colors[1])
	_px(-7, 3, 14, mh, skin_colors[0])
	for tx in range(-7, 7, 3):
		_px(tx, 3, 2, 2, skin_colors[4])
		_px(tx, 3 + mh - 2, 2, 2, skin_colors[4])
	var jb := 3 + mh
	var drip_x: Array[int] = [-6, -2, 2, 5]
	var drip_l: Array[int] = [2, 1, 3, 2]
	for i in 4:
		_px(drip_x[i], jb + 1, 1, drip_l[i], skin_colors[2])

func _draw_torso() -> void:
	_px_ellipse(0.0, 18.5, 10.5, 7.5, skin_colors[0])
	_px(-11, 11, 22, 1, skin_colors[3])
	_px(-10, 12, 20, 1, skin_colors[2])
	var hws: Array[int] = [10, 9, 8, 6]
	for i in 4:
		var y := 14 + i * 3
		var hw := hws[i]
		_px(-hw, y, hw - 1, 1, skin_colors[3])
		_px(-hw + 1, y + 1, hw - 2, 1, skin_colors[2])
		_px(-hw, y + 1, 1, 1, skin_colors[1])
		_px(1, y, hw - 1, 1, skin_colors[3])
		_px(1, y + 1, hw - 2, 1, skin_colors[2])
		_px(hw - 1, y + 1, 1, 1, skin_colors[1])
	_px(-1, 11, 2, 15, skin_colors[1])
	for r in range(0, 15, 2):
		_px(-1, 11 + r, 2, 1, skin_colors[3])
	_px(-3, 26, 6, 1, skin_colors[2])

func _draw_bone_hand(hx: int, hy: int, side: int) -> void:
	_px(hx - 1, hy + 3, 2, 2, skin_colors[1])
	_px(hx - 2, hy, 4, 3, skin_colors[2])
	_px(hx - 2, hy, 4, 1, skin_colors[3])
	var heights: Array[int] = [2, 3, 3, 2]
	for f in 4:
		var h := heights[f]
		_px(hx - 2 + f, hy - h, 1, h, skin_colors[2])
		_px(hx - 2 + f, hy - h, 1, 1, skin_colors[4])
	var tx := hx + 2 if side < 0 else hx - 3
	_px(tx, hy + 1, 1, 2, skin_colors[3])
