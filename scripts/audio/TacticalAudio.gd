class_name TacticalAudioManager
extends Node

## Procedural tactical audio synthesizer ported from src/game/audio.ts
## Generates AudioStreamWAV buffers in memory so desktop & WebGL builds need zero external audio files.

const SAMPLE_RATE: int = 22050
const POOL_SIZE: int = 16

var muted: bool = false
var _ad_muted: bool = false
var _players: Array[AudioStreamPlayer] = []
var _cursor: int = 0
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 99123
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SfxPlayer_%d" % i
		add_child(p)
		_players.append(p)
	_build_all_streams()

func set_muted(val: bool) -> void:
	muted = val
	if muted:
		for p in _players:
			p.stop()

func set_ad_mute(val: bool) -> void:
	_ad_muted = val
	if _ad_muted:
		for p in _players:
			p.stop()

func _play_stream(key: String, volume_linear: float = 1.0, pitch_scale: float = 1.0) -> void:
	if muted or _ad_muted or not _streams.has(key):
		return
	var p: AudioStreamPlayer = _players[_cursor]
	_cursor = (_cursor + 1) % POOL_SIZE
	p.stream = _streams[key]
	p.volume_db = linear_to_db(clampf(volume_linear, 0.01, 1.5))
	p.pitch_scale = clampf(pitch_scale, 0.5, 2.0)
	p.play()

func play_gunshot(weapon_id: String, distance_attenuation: float = 1.0) -> void:
	var gain: float = clampf(distance_attenuation, 0.05, 1.0)
	var pitch_var: float = 0.92 + _rng.randf() * 0.16
	if weapon_id == "karambit":
		_play_stream("karambit", gain, pitch_var)
	elif weapon_id == "m4a1s" or weapon_id == "usps":
		_play_stream("gun_silenced", gain, pitch_var)
	elif weapon_id == "awp":
		_play_stream("gun_awp", gain, pitch_var)
	elif weapon_id == "nova":
		_play_stream("gun_shotgun", gain, pitch_var)
	elif weapon_id == "deagle":
		_play_stream("gun_deagle", gain, pitch_var)
	else:
		_play_stream("gun_rifle", gain, pitch_var)

func play_metallic_click(freq: float = 1100.0) -> void:
	_play_stream("click", 0.75, clampf(freq / 1100.0, 0.5, 1.8))

func play_reload() -> void:
	_play_stream("reload", 0.85, 1.0)

func play_hitmarker(headshot: bool) -> void:
	_play_stream("hit_head" if headshot else "hit_body", 0.9, 1.0)

func play_player_hurt() -> void:
	_play_stream("player_hurt", 0.9, 1.0)

func play_footstep() -> void:
	_play_stream("footstep", 0.7, 0.9 + _rng.randf() * 0.2)

func play_grenade_bounce() -> void:
	_play_stream("click", 0.55, 0.56 + _rng.randf() * 0.14)

func play_explosion(is_flash: bool) -> void:
	_play_stream("flash_bang" if is_flash else "he_boom", 1.0, 1.0)

func play_round_sting(victory: bool) -> void:
	_play_stream("sting_win" if victory else "sting_lose", 0.85, 1.0)

func _build_all_streams() -> void:
	_streams["karambit"] = _make_karambit_wav()
	_streams["gun_rifle"] = _make_gunshot_wav(210.0, 0.09, 0.30, 0.28, 0.16, false, false)
	_streams["gun_silenced"] = _make_gunshot_wav(260.0, 0.07, 0.18, 0.14, 0.08, true, false)
	_streams["gun_awp"] = _make_gunshot_wav(190.0, 0.22, 0.42, 0.48, 0.42, false, true)
	_streams["gun_shotgun"] = _make_gunshot_wav(140.0, 0.12, 0.34, 0.42, 0.26, false, false)
	_streams["gun_deagle"] = _make_gunshot_wav(240.0, 0.10, 0.34, 0.36, 0.18, false, false)
	_streams["click"] = _make_click_wav(1100.0, 0.045)
	_streams["reload"] = _make_reload_wav()
	_streams["hit_body"] = _make_sweep_wav(920.0, 480.0, 0.075, 0.18, false)
	_streams["hit_head"] = _make_sweep_wav(1950.0, 2900.0, 0.075, 0.28, true)
	_streams["player_hurt"] = _make_sweep_wav(140.0, 48.0, 0.16, 0.28, true)
	_streams["footstep"] = _make_footstep_wav()
	_streams["he_boom"] = _make_he_explosion_wav()
	_streams["flash_bang"] = _make_flashbang_wav()
	_streams["sting_win"] = _make_sting_wav([440.0, 554.37, 659.25])
	_streams["sting_lose"] = _make_sting_wav([330.0, 293.66, 220.0])

func _pack_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var s: int = clampi(int(samples[i] * 32767.0), -32768, 32767)
		bytes.encode_s16(i * 2, s)
	wav.data = bytes
	return wav

func _make_karambit_wav() -> AudioStreamWAV:
	var n: int = int(SAMPLE_RATE * 0.14)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 28.0) * 0.35
		var noise: float = _rng.randf_range(-1.0, 1.0)
		var alpha: float = clampf(0.28 - t * 1.4, 0.05, 0.3)
		lp += alpha * (noise - lp)
		buf[i] = lp * env
	return _pack_wav(buf)

func _make_gunshot_wav(
	start_freq: float,
	osc_dur: float,
	osc_amp: float,
	noise_amp: float,
	noise_dur: float,
	silenced: bool,
	with_bolt: bool
) -> AudioStreamWAV:
	var total_dur: float = 0.56 if with_bolt else maxf(osc_dur, noise_dur) + 0.03
	var n: int = int(SAMPLE_RATE * total_dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase: float = 0.0
	var lp: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		var s: float = 0.0
		if t < osc_dur:
			var frac: float = t / osc_dur
			var freq: float = start_freq * pow(38.0 / start_freq, frac)
			phase += TAU * freq / float(SAMPLE_RATE)
			var tri: float = absf(fmod(phase / PI, 2.0) - 1.0) * 2.0 - 1.0
			s += tri * osc_amp * exp(-frac * 5.2)
		if t < noise_dur:
			var nfrac: float = t / noise_dur
			var raw: float = _rng.randf_range(-1.0, 1.0)
			var alpha: float = 0.22 if silenced else clampf(0.55 * (1.0 - nfrac * 0.75), 0.06, 0.6)
			lp += alpha * (raw - lp)
			var n_out: float = (raw - lp) if silenced else lp
			s += n_out * noise_amp * exp(-nfrac * 5.0)
		if with_bolt:
			for click_t in [0.32, 0.46]:
				if t >= click_t and t < click_t + 0.035:
					var ct: float = t - click_t
					var cfreq: float = 920.0 if click_t < 0.4 else 1180.0
					s += (1.0 if sin(TAU * cfreq * ct) >= 0.0 else -1.0) * 0.08 * exp(-ct * 90.0)
		buf[i] = clampf(s, -0.95, 0.95)
	return _pack_wav(buf)

func _make_click_wav(freq: float, dur: float) -> AudioStreamWAV:
	var n: int = int(SAMPLE_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		var frac: float = t / dur
		var f: float = freq * (1.0 - 0.55 * frac)
		phase += TAU * f / float(SAMPLE_RATE)
		var sq: float = 1.0 if sin(phase) >= 0.0 else -1.0
		buf[i] = sq * 0.14 * exp(-frac * 5.5)
	return _pack_wav(buf)

func _make_reload_wav() -> AudioStreamWAV:
	var total_dur: float = 1.25
	var n: int = int(SAMPLE_RATE * total_dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var clicks := [[0.05, 760.0], [0.55, 1020.0], [1.15, 1340.0]]
	for c in clicks:
		var start_s: int = int(float(c[0]) * SAMPLE_RATE)
		var dur_s: int = int(0.045 * SAMPLE_RATE)
		var freq: float = float(c[1])
		var phase: float = 0.0
		for j in range(dur_s):
			var idx: int = start_s + j
			if idx >= n:
				break
			var frac: float = float(j) / float(dur_s)
			phase += TAU * (freq * (1.0 - 0.55 * frac)) / float(SAMPLE_RATE)
			var sq: float = 1.0 if sin(phase) >= 0.0 else -1.0
			buf[idx] = clampf(buf[idx] + sq * 0.13 * exp(-frac * 5.5), -0.95, 0.95)
	return _pack_wav(buf)

func _make_sweep_wav(f0: float, f1: float, dur: float, amp: float, sharp: bool) -> AudioStreamWAV:
	var n: int = int(SAMPLE_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase: float = 0.0
	for i in range(n):
		var frac: float = float(i) / float(maxi(1, n))
		var freq: float = f0 * pow(f1 / f0, frac)
		phase += TAU * freq / float(SAMPLE_RATE)
		var wave: float = (absf(fmod(phase / PI, 2.0) - 1.0) * 2.0 - 1.0) if sharp else sin(phase)
		buf[i] = wave * amp * exp(-frac * 4.8)
	return _pack_wav(buf)

func _make_footstep_wav() -> AudioStreamWAV:
	var n: int = int(SAMPLE_RATE * 0.07)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp: float = 0.0
	for i in range(n):
		var frac: float = float(i) / float(n)
		lp += 0.12 * (_rng.randf_range(-1.0, 1.0) - lp)
		buf[i] = lp * 0.22 * exp(-frac * 5.5)
	return _pack_wav(buf)

func _make_he_explosion_wav() -> AudioStreamWAV:
	var dur: float = 0.75
	var n: int = int(SAMPLE_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase: float = 0.0
	var lp: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		var frac: float = t / dur
		var freq: float = 115.0 * pow(24.0 / 115.0, minf(1.0, t / 0.55))
		phase += TAU * freq / float(SAMPLE_RATE)
		var bass: float = sin(phase) * 0.58 * exp(-t * 5.0)
		var alpha: float = clampf(0.35 * (1.0 - frac * 0.85), 0.04, 0.35)
		lp += alpha * (_rng.randf_range(-1.0, 1.0) - lp)
		var rumble: float = lp * 0.55 * exp(-t * 3.8)
		buf[i] = clampf(bass + rumble, -0.95, 0.95)
	return _pack_wav(buf)

func _make_flashbang_wav() -> AudioStreamWAV:
	var dur: float = 1.15
	var n: int = int(SAMPLE_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		var s: float = 0.0
		if t < 0.26:
			var raw: float = _rng.randf_range(-1.0, 1.0)
			lp += 0.25 * (raw - lp)
			s += (raw - lp) * 0.42 * exp(-t * 18.0)
		s += sin(TAU * 3400.0 * t) * 0.09 * exp(-t * 3.8)
		buf[i] = clampf(s, -0.95, 0.95)
	return _pack_wav(buf)

func _make_sting_wav(notes: Array) -> AudioStreamWAV:
	var dur: float = 0.7
	var n: int = int(SAMPLE_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for idx in range(notes.size()):
		var freq: float = float(notes[idx])
		var start_t: float = float(idx) * 0.11
		var start_s: int = int(start_t * SAMPLE_RATE)
		var note_len: int = int(0.28 * SAMPLE_RATE)
		for j in range(note_len):
			var k: int = start_s + j
			if k >= n:
				break
			var lt: float = float(j) / float(SAMPLE_RATE)
			var phase: float = TAU * freq * lt
			var tri: float = absf(fmod(phase / PI, 2.0) - 1.0) * 2.0 - 1.0
			buf[k] = clampf(buf[k] + tri * 0.18 * exp(-lt * 10.0), -0.95, 0.95)
	return _pack_wav(buf)
