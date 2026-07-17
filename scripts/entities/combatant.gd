class_name Combatant
extends RefCounted
## A single fighter in combat.
##
## The player also uses Sanity as a SECOND health bar (see GAME_NOTES.md 1.3):
## reaching zero sanity is death, just like reaching zero HP. Enemies leave
## max_sanity at 0, so the sanity rules simply don't apply to them.

var display_name: String
var max_hp: int
var hp: int
var max_sanity: int
var sanity: int
var attack: int
var uses_sanity: bool

func _init(name: String, hp_max: int, atk: int, sanity_max: int = 0) -> void:
	display_name = name
	max_hp = hp_max
	hp = hp_max
	attack = atk
	max_sanity = sanity_max
	sanity = sanity_max
	uses_sanity = sanity_max > 0

func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)

func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)

func change_sanity(amount: int) -> void:
	if not uses_sanity:
		return
	sanity = clampi(sanity + amount, 0, max_sanity)

func is_alive() -> bool:
	# Sanity is a second health bar: hitting zero is death, just like HP.
	if hp <= 0:
		return false
	if uses_sanity and sanity <= 0:
		return false
	return true
