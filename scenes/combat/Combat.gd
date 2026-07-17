extends Control
## Combat MVP for the cosmic-horror roguelike.
##
## 1-vs-1 turn-based fight (GAME_NOTES.md 1.4): the player ALWAYS acts first,
## then the enemy, looping until one side is fully down.
##
## Sanity (GAME_NOTES.md 1.3) is a second health bar that:
##   - drains every player turn AFTER a 2-turn grace period,
##   - refills when a BASIC attack lands,
##   - is spent to use skills — and skills paid with sanity give NO refill,
##   - means death at zero, exactly like HP.
##
## The whole UI is built in code so the .tscn stays trivial.

# --- Tunable values (balance later, see GAME_NOTES.md 1.3 "TODO") ---
const SANITY_GRACE_TURNS := 2      # first N player turns don't drain sanity
const SANITY_DRAIN := 2            # sanity lost per player turn after the grace
const ATTACK_SANITY_GAIN := 3      # sanity restored when a basic attack lands
const SKILL_SANITY_COST := 5       # sanity spent on Frenzied Strike
const BANDAGE_HEAL := 10           # HP restored per bandage
const START_BANDAGES := 2
const FLEE_CHANCE := 0.5

# --- Colors ---
const COL_BG := Color(0.05, 0.05, 0.07)
const COL_ENEMY := Color(0.40, 0.55, 0.20)
const COL_PLAYER := Color(0.45, 0.40, 0.38)
const COL_HP := Color(0.72, 0.16, 0.16)
const COL_SANITY := Color(0.52, 0.26, 0.72)
const COL_BAR_BG := Color(0.15, 0.15, 0.18)

# --- Runtime state ---
var player: Combatant
var enemy: Combatant
var player_turn_count := 0
var bandages := START_BANDAGES
var combat_over := false
var log_lines: Array[String] = []

# --- UI references ---
var enemy_name_label: Label
var enemy_hp_bar: ProgressBar
var enemy_hp_label: Label
var player_hp_bar: ProgressBar
var player_hp_label: Label
var player_sanity_bar: ProgressBar
var player_sanity_label: Label
var log_label: RichTextLabel
var menu: HBoxContainer
var attack_btn: Button
var skill_btn: Button
var item_btn: Button
var flee_btn: Button
var restart_btn: Button


func _ready() -> void:
	randomize()
	_build_ui()
	_start_battle()


# ----------------------------------------------------------------------------
# Battle lifecycle
# ----------------------------------------------------------------------------
func _start_battle() -> void:
	player = Combatant.new("Investigator", 30, 6, 20)
	enemy = Combatant.new("Zombie", 20, 4)
	player_turn_count = 0
	bandages = START_BANDAGES
	combat_over = false
	log_lines.clear()

	enemy_name_label.text = enemy.display_name
	restart_btn.visible = false
	menu.visible = true

	_log("A [color=#8fbf3f]%s[/color] shambles out of the dark." % enemy.display_name)
	_refresh()
	_start_player_turn()


func _start_player_turn() -> void:
	if combat_over:
		return
	player_turn_count += 1

	# Sanity only starts draining after the grace period.
	if player_turn_count > SANITY_GRACE_TURNS:
		player.change_sanity(-SANITY_DRAIN)
		_log("The silence presses in. ([color=#b57fdd]-%d SAN[/color])" % SANITY_DRAIN)
		_refresh()
		if not player.is_alive():
			_end_battle("lose", "Sanity drains to nothing. Madness claims you.")
			return

	_log("[b]Turn %d[/b] — your move." % player_turn_count)
	_set_menu_enabled(true)


func _proceed_after_player() -> void:
	if not enemy.is_alive():
		_end_battle("win", "The %s collapses into stillness. You survive... for now." % enemy.display_name)
		return
	await _enemy_turn()


func _enemy_turn() -> void:
	if combat_over:
		return
	await get_tree().create_timer(0.7).timeout
	var dmg := _roll(enemy.attack)
	player.take_damage(dmg)
	_log("The %s claws at you for [color=#d94b4b]%d[/color] damage." % [enemy.display_name, dmg])
	_refresh()
	if not player.is_alive():
		_end_battle("lose", "Your body fails. Darkness swallows you.")
		return
	await get_tree().create_timer(0.4).timeout
	_start_player_turn()


func _end_battle(result: String, message: String) -> void:
	combat_over = true
	_set_menu_enabled(false)
	menu.visible = false
	restart_btn.visible = true
	var color := "#8fbf3f"
	if result == "lose":
		color = "#d94b4b"
	elif result == "escape":
		color = "#c9c9c9"
	_log("[color=%s]%s[/color]" % [color, message])


# ----------------------------------------------------------------------------
# Player actions
# ----------------------------------------------------------------------------
func _on_attack() -> void:
	if combat_over or attack_btn.disabled:
		return
	_set_menu_enabled(false)
	var dmg := _roll(player.attack)
	enemy.take_damage(dmg)
	player.change_sanity(ATTACK_SANITY_GAIN)  # basic attacks restore sanity
	_log("You strike the %s for [color=#ffd24a]%d[/color]. ([color=#b57fdd]+%d SAN[/color])"
		% [enemy.display_name, dmg, ATTACK_SANITY_GAIN])
	_refresh()
	await _proceed_after_player()


func _on_skill() -> void:
	if combat_over or skill_btn.disabled:
		return
	if player.sanity < SKILL_SANITY_COST:
		_log("Not enough sanity to focus your will.")
		return
	_set_menu_enabled(false)
	player.change_sanity(-SKILL_SANITY_COST)  # paid with sanity — NO on-hit refill
	var dmg := _roll(player.attack * 2)
	enemy.take_damage(dmg)
	_log("[b]Frenzied Strike![/b] [color=#ffd24a]%d[/color] damage. ([color=#b57fdd]-%d SAN[/color], no sanity gained)"
		% [dmg, SKILL_SANITY_COST])
	_refresh()
	# Spending sanity can itself be fatal.
	if not player.is_alive():
		_end_battle("lose", "Your mind gives out mid-swing.")
		return
	await _proceed_after_player()


func _on_item() -> void:
	if combat_over or item_btn.disabled:
		return
	if bandages <= 0:
		_log("No bandages left.")
		return
	_set_menu_enabled(false)
	bandages -= 1
	player.heal(BANDAGE_HEAL)
	_log("You bind your wounds. ([color=#ff8f8f]+%d HP[/color], %d left)" % [BANDAGE_HEAL, bandages])
	_refresh()
	await _proceed_after_player()


func _on_flee() -> void:
	if combat_over or flee_btn.disabled:
		return
	_set_menu_enabled(false)
	if randf() < FLEE_CHANCE:
		_end_battle("escape", "You flee into the dark, heart pounding.")
		return
	_log("You stumble — no escape!")
	await _enemy_turn()


func _on_restart() -> void:
	_start_battle()


# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
func _roll(base: int) -> int:
	# Small +/-1 variance so damage doesn't feel robotic; never below 1.
	return maxi(1, base + randi_range(-1, 1))


func _set_menu_enabled(enabled: bool) -> void:
	attack_btn.disabled = not enabled
	skill_btn.disabled = not enabled or player.sanity < SKILL_SANITY_COST
	item_btn.disabled = not enabled or bandages <= 0
	flee_btn.disabled = not enabled


func _log(line: String) -> void:
	log_lines.append(line)
	while log_lines.size() > 5:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)


func _refresh() -> void:
	enemy_hp_bar.max_value = enemy.max_hp
	enemy_hp_bar.value = enemy.hp
	enemy_hp_label.text = "HP %d/%d" % [enemy.hp, enemy.max_hp]

	player_hp_bar.max_value = player.max_hp
	player_hp_bar.value = player.hp
	player_hp_label.text = "HP  %d/%d" % [player.hp, player.max_hp]

	player_sanity_bar.max_value = player.max_sanity
	player_sanity_bar.value = player.sanity
	player_sanity_label.text = "SAN %d/%d" % [player.sanity, player.max_sanity]


# ----------------------------------------------------------------------------
# UI construction (kept out of the .tscn on purpose)
# ----------------------------------------------------------------------------
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# --- Enemy (top) ---
	enemy_name_label = _make_label("Zombie", Vector2(0, 12), Vector2(640, 24), 20, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(enemy_name_label)

	var enemy_sprite := ColorRect.new()
	enemy_sprite.color = COL_ENEMY
	enemy_sprite.position = Vector2(284, 42)
	enemy_sprite.size = Vector2(72, 72)
	add_child(enemy_sprite)

	enemy_hp_bar = _make_bar(COL_ENEMY, Vector2(220, 122), Vector2(200, 12))
	add_child(enemy_hp_bar)
	enemy_hp_label = _make_label("HP", Vector2(220, 136), Vector2(200, 16), 12, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(enemy_hp_label)

	# --- Message log (middle) ---
	var log_bg := ColorRect.new()
	log_bg.color = Color(0, 0, 0, 0.35)
	log_bg.position = Vector2(36, 158)
	log_bg.size = Vector2(568, 60)
	add_child(log_bg)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.fit_content = true
	log_label.scroll_active = false
	log_label.position = Vector2(44, 160)
	log_label.size = Vector2(552, 56)
	log_label.add_theme_font_size_override("normal_font_size", 13)
	log_label.add_theme_font_size_override("bold_font_size", 13)
	add_child(log_label)

	# --- Player (bottom) ---
	var player_sprite := ColorRect.new()
	player_sprite.color = COL_PLAYER
	player_sprite.position = Vector2(296, 226)
	player_sprite.size = Vector2(48, 48)
	add_child(player_sprite)

	player_hp_label = _make_label("HP", Vector2(40, 232), Vector2(180, 16), 14, HORIZONTAL_ALIGNMENT_LEFT)
	add_child(player_hp_label)
	player_hp_bar = _make_bar(COL_HP, Vector2(40, 250), Vector2(180, 12))
	add_child(player_hp_bar)

	player_sanity_label = _make_label("SAN", Vector2(420, 232), Vector2(180, 16), 14, HORIZONTAL_ALIGNMENT_RIGHT)
	add_child(player_sanity_label)
	player_sanity_bar = _make_bar(COL_SANITY, Vector2(420, 250), Vector2(180, 12))
	add_child(player_sanity_bar)

	# --- Command menu ---
	menu = HBoxContainer.new()
	menu.position = Vector2(40, 300)
	menu.size = Vector2(560, 44)
	menu.add_theme_constant_override("separation", 8)
	add_child(menu)

	attack_btn = _make_menu_button("Attack")
	skill_btn = _make_menu_button("Frenzied Strike (5 SAN)")
	item_btn = _make_menu_button("Bandage")
	flee_btn = _make_menu_button("Flee")
	menu.add_child(attack_btn)
	menu.add_child(skill_btn)
	menu.add_child(item_btn)
	menu.add_child(flee_btn)

	attack_btn.pressed.connect(_on_attack)
	skill_btn.pressed.connect(_on_skill)
	item_btn.pressed.connect(_on_item)
	flee_btn.pressed.connect(_on_flee)

	restart_btn = Button.new()
	restart_btn.text = "New Run"
	restart_btn.position = Vector2(260, 300)
	restart_btn.size = Vector2(120, 44)
	restart_btn.custom_minimum_size = Vector2(120, 44)
	restart_btn.visible = false
	restart_btn.pressed.connect(_on_restart)
	add_child(restart_btn)


func _make_label(text: String, pos: Vector2, size: Vector2, font_size: int, align: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.size = size
	lbl.horizontal_alignment = align
	lbl.add_theme_font_size_override("font_size", font_size)
	return lbl


func _make_bar(fill_color: Color, pos: Vector2, size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = size
	bar.custom_minimum_size = size
	bar.show_percentage = false

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	bar.add_theme_stylebox_override("fill", fill)

	var back := StyleBoxFlat.new()
	back.bg_color = COL_BAR_BG
	bar.add_theme_stylebox_override("background", back)
	return bar


func _make_menu_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 40)
	return btn
