class_name SfxBank
extends RefCounted

## Procedural one-shot sound effects.
##
## Each is well under a tenth of a second, so building them all at startup costs
## nothing measurable and needs no caching.

## Build every effect. Returns name -> AudioStreamWAV.
##
## Judgement blips rise in pitch with accuracy, so a player can hear how well
## they timed a jump without reading the HUD.
static func build() -> Dictionary:
	return {
		"perfect": _blip(1320.0, 0.10, Synth.WAVE_PULSE, 0.30, 12.0),
		"great": _blip(990.0, 0.09, Synth.WAVE_PULSE, 0.30, 7.0),
		"good": _blip(660.0, 0.08, Synth.WAVE_TRIANGLE, 0.5, 4.0),
		"miss": _blip(220.0, 0.12, Synth.WAVE_SAW, 0.5, -6.0),
		"land": _blip(150.0, 0.05, Synth.WAVE_SINE, 0.5, -10.0),
		"death": _blip(300.0, 0.55, Synth.WAVE_SAW, 0.5, -30.0),
		# Menu feedback. Quiet and short: navigation should feel mechanical,
		# not announce itself.
		"ui_move": _blip(880.0, 0.04, Synth.WAVE_PULSE, 0.5, 0.0),
		"ui_confirm": _blip(1180.0, 0.13, Synth.WAVE_PULSE, 0.3, 9.0),
	}


## Render a short pitched one-shot.
##
## `bend` is how many semitones the pitch travels over the sound's life, which
## is the whole difference between a "blip" and a "boop".
static func _blip(
	freq: float, duration: float, wave: int, pulse_width: float, bend: float
) -> AudioStreamWAV:
	var rate: int = Synth.MIX_RATE
	var count: int = int(duration * rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	var phase: float = 0.0
	var rng: int = 99991
	for i in count:
		var progress: float = float(i) / float(count)
		# Exponential decay reads as percussive; linear reads as a fade-out.
		var env: float = pow(1.0 - progress, 2.2)
		phase += (freq * pow(2.0, (bend * progress) / 12.0)) / float(rate)
		if phase >= 1.0:
			phase -= floorf(phase)

		var s: float = 0.0
		if wave == Synth.WAVE_PULSE:
			s = 1.0 if phase < pulse_width else -1.0
		elif wave == Synth.WAVE_TRIANGLE:
			s = 4.0 * absf(phase - 0.5) - 1.0
		elif wave == Synth.WAVE_SAW:
			s = 2.0 * phase - 1.0
		elif wave == Synth.WAVE_SINE:
			s = sin(phase * TAU)
		else:
			rng = (rng * 1664525 + 1013904223) & 0xFFFFFFFF
			s = (float(rng) / 2147483648.0) - 1.0

		var v: int = clampi(int(s * env * 0.55 * 32767.0), -32768, 32767) & 0xFFFF
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream
