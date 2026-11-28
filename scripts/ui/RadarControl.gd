class_name RadarControl
extends Control

## Tactical Compound Radar Minimap ported from HudOverlay.tsx

const RADAR_SIZE: float = 132.0

var radar_blips: Array = []
var player_x: float = 0.0
var player_z: float = 24.0
var player_yaw: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(RADAR_SIZE, RADAR_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_state(blips: Array, px: float, pz: float, pyaw: float) -> void:
	radar_blips = blips
	player_x = px
	player_z = pz
	player_yaw = pyaw
	queue_redraw()

func _to_radar(wx: float, wz: float) -> Vector2:
	var span: float = MapData.MAP_HALF_SIZE * 2.0
	return Vector2(
		((wx + MapData.MAP_HALF_SIZE) / span) * RADAR_SIZE,
		((wz + MapData.MAP_HALF_SIZE) / span) * RADAR_SIZE
	)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(RADAR_SIZE, RADAR_SIZE)), Color("#181511"))

	var span: float = MapData.MAP_HALF_SIZE * 2.0
	for p in MapData.MAP_PROPS:
		var px: float = float(p["x"])
		var pz: float = float(p["z"])
		var pw: float = float(p["w"])
		var pd: float = float(p["d"])
		var tl: Vector2 = _to_radar(px - pw * 0.5, pz - pd * 0.5)
		var rw: float = maxf(2.0, (pw / span) * RADAR_SIZE)
		var rh: float = maxf(2.0, (pd / span) * RADAR_SIZE)
		var col: Color = Color("#7c5a37") if String(p["kind"]) == "crate" else Color("#574c3f")
		draw_rect(Rect2(tl, Vector2(rw, rh)), col)

	for b in radar_blips:
		var pt: Vector2 = _to_radar(float(b["x"]), float(b["z"]))
		var st: GameTypes.BotAIState = b["state"]
		var col := Color("#f59e0b")
		if st == GameTypes.BotAIState.BLINDED:
			col = Color.WHITE
		elif st == GameTypes.BotAIState.ENGAGE:
			col = Color("#ef4444")
		draw_circle(pt, 4.2, Color.BLACK)
		draw_circle(pt, 3.2, col)

	var p_pos: Vector2 = _to_radar(player_x, player_z)
	var rot: float = -player_yaw
	var pts := PackedVector2Array([
		Vector2(0.0, -6.5),
		Vector2(4.5, 5.0),
		Vector2(0.0, 2.5),
		Vector2(-4.5, 5.0),
	])
	var xformed := PackedVector2Array()
	for v in pts:
		xformed.append(p_pos + v.rotated(rot))
	draw_colored_polygon(xformed, Color("#34d399"))
	draw_polyline(xformed + PackedVector2Array([xformed[0]]), Color.BLACK, 1.0)
