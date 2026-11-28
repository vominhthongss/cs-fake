class_name CrosshairControl
extends Control

## Full-screen overlay drawing dynamic crosshair, hitmarker, AWP scope, flashbang & damage vignette

var is_scoped: bool = false
var crosshair_spread: float = 0.003
var flash_alpha: float = 0.0
var damage_flash_alpha: float = 0.0
var hp: int = 100
var hitmarker_type: String = "none"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func update_state(hud: Dictionary) -> void:
	is_scoped = bool(hud["is_scoped"])
	crosshair_spread = float(hud["crosshair_spread"])
	flash_alpha = float(hud["flash_alpha"])
	damage_flash_alpha = float(hud["damage_flash_alpha"])
	hp = int(hud["hp"])
	hitmarker_type = String(hud["hitmarker_type"])
	queue_redraw()

func _draw() -> void:
	var sz: Vector2 = size
	var center: Vector2 = sz * 0.5

	# AWP Scope overlay
	if is_scoped:
		var radius: float = minf(sz.x, sz.y) * 0.36
		var dark := Color(0.03, 0.035, 0.04, 0.96)
		# Mask outside circle with thick ring + surrounding rects
		var left_x: float = center.x - radius
		var right_x: float = center.x + radius
		var top_y: float = center.y - radius
		var bot_y: float = center.y + radius
		draw_rect(Rect2(0, 0, sz.x, maxf(0.0, top_y)), dark)
		draw_rect(Rect2(0, bot_y, sz.x, maxf(0.0, sz.y - bot_y)), dark)
		draw_rect(Rect2(0, top_y, maxf(0.0, left_x), radius * 2.0), dark)
		draw_rect(Rect2(right_x, top_y, maxf(0.0, sz.x - right_x), radius * 2.0), dark)
		# Corner arcs approximated by thick outer arc
		draw_arc(center, radius * 1.28, 0.0, TAU, 64, dark, radius * 0.56, true)
		draw_arc(center, radius, 0.0, TAU, 64, Color(0.02, 0.02, 0.02, 1.0), 4.0, true)
		# Reticle lines & red dot
		draw_line(Vector2(0, center.y), Vector2(sz.x, center.y), Color(0.05, 0.05, 0.05, 0.92), 1.5)
		draw_line(Vector2(center.x, 0), Vector2(center.x, sz.y), Color(0.05, 0.05, 0.05, 0.92), 1.5)
		draw_circle(center, 3.2, Color("#ef4444"))
	else:
		# Dynamic 4-bar emerald crosshair
		var gap: float = clampf(round(crosshair_spread * 420.0), 4.0, 34.0)
		var bar_len: float = 10.0
		var col := Color("#6ee7b7")
		var outline := Color(0, 0, 0, 0.85)
		# Top, Bottom, Left, Right bars with 1px dark outline
		for rect in [
			Rect2(center.x - 1.0, center.y - gap - bar_len, 2.0, bar_len),
			Rect2(center.x - 1.0, center.y + gap, 2.0, bar_len),
			Rect2(center.x - gap - bar_len, center.y - 1.0, bar_len, 2.0),
			Rect2(center.x + gap, center.y - 1.0, bar_len, 2.0),
		]:
			draw_rect(rect.grow(1.0), outline)
			draw_rect(rect, col)
		draw_rect(Rect2(center.x - 1.0, center.y - 1.0, 2.0, 2.0), col)

	# Hitmarker X
	if hitmarker_type != "none":
		var hcol := Color.WHITE
		if hitmarker_type == "kill":
			hcol = Color("#ef4444")
		elif hitmarker_type == "head":
			hcol = Color("#f59e0b")
		var inner: float = 5.0
		var outer: float = 12.0
		draw_line(center + Vector2(-outer, -outer), center + Vector2(-inner, -inner), hcol, 2.5)
		draw_line(center + Vector2(outer, -outer), center + Vector2(inner, -inner), hcol, 2.5)
		draw_line(center + Vector2(-outer, outer), center + Vector2(-inner, inner), hcol, 2.5)
		draw_line(center + Vector2(outer, outer), center + Vector2(inner, inner), hcol, 2.5)

	# Damage / Low HP vignette
	var dmg_a: float = maxf(damage_flash_alpha, 0.35 if hp <= 25 else 0.0)
	if dmg_a > 0.01:
		var edge := Color(0.86, 0.15, 0.15, dmg_a * 0.45)
		var bw: float = 42.0
		draw_rect(Rect2(0, 0, sz.x, bw), edge)
		draw_rect(Rect2(0, sz.y - bw, sz.x, bw), edge)
		draw_rect(Rect2(0, bw, bw, sz.y - bw * 2.0), edge)
		draw_rect(Rect2(sz.x - bw, bw, bw, sz.y - bw * 2.0), edge)

	# Flashbang whiteout
	if flash_alpha > 0.01:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(1.0, 1.0, 1.0, clampf(flash_alpha, 0.0, 1.0)))
