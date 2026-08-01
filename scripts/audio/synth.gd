class_name Synth
extends RefCounted

## Offline chiptune synthesiser. Renders a song definition (see
## song_library.gd) into a looping AudioStreamWAV.
##
##   song -> per note: an ADSR-enveloped oscillator
##        -> summed into stereo float buffers with per-track pan and gain
##        -> soft-clipped to 16-bit PCM with a loop point
##
## Offline rather than live (AudioStreamGenerator) because a rhythm game cannot
## afford a ring buffer that clicks on a frame hitch, and native streaming gives
## a playback clock that works as documented. See docs/ARCHITECTURE.md.
##
## Deterministic: noise uses a seeded LCG rather than randf(), so a cached and a
## fresh render are bit-identical.

## BUMP THIS whenever the synthesis maths changes.
##
## SongCache keys on a hash of the song DEFINITION, which cannot see changes to
## the code in this file. Without bumping this, edit an envelope here and every
## cached render stays stale forever while the change appears to do nothing.
const RENDER_VERSION: int = 4

## Output sample rate. 22050Hz is the classic chiptune range: high enough that
## the lead and hats stay crisp, low enough to halve both synthesis time and
## cache size versus 44100. Anything above ~11kHz of content is inaudible in
## square/triangle material anyway.
const MIX_RATE: int = 22050

## Oscillator shapes. Plain ints rather than an enum so song data stays
## JSON-shaped and easy to hand-edit.
const WAVE_PULSE: int = 0
const WAVE_TRIANGLE: int = 1
const WAVE_SAW: int = 2
const WAVE_SINE: int = 3
const WAVE_NOISE: int = 4

## Master gain applied before soft clipping. Leaves headroom for several tracks
## to stack on a downbeat without the limiter working hard enough to pump.
const MASTER_GAIN: float = 0.72


## Convert a MIDI note number to frequency in Hz. A4 (MIDI 69) = 440Hz.
static func midi_to_freq(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


## Render a song dictionary into a looping AudioStreamWAV.
##
## The returned stream loops over its entire length, so the music runs forever
## while a climb is in progress. Because the loop covers a whole number of bars,
## the loop point falls exactly on a downbeat and is inaudible.
##
## This is safe to call from a background thread: it touches no scene tree state
## and allocates only local buffers.
static func render_song(song: Dictionary) -> AudioStreamWAV:
	var bpm: float = song.get("bpm", 120.0)
	var bars: int = song.get("bars", 8)
	var beats_per_bar: int = song.get("beats_per_bar", 4)
	var spb: float = 60.0 / bpm

	var total_beats: float = float(bars * beats_per_bar)
	var total_samples: int = int(ceil(total_beats * spb * MIX_RATE))

	# Float accumulation buffers. Summing in float and converting once at the
	# end avoids the cumulative quantisation error you get from mixing in 16-bit.
	var left: PackedFloat32Array = PackedFloat32Array()
	var right: PackedFloat32Array = PackedFloat32Array()
	left.resize(total_samples)
	right.resize(total_samples)

	for track in song.get("tracks", []):
		_render_track(track, left, right, spb, total_samples)

	return _to_stream(left, right, total_samples, total_beats * spb)


## Render one track's notes into the shared stereo accumulation buffers.
static func _render_track(
	track: Dictionary,
	left: PackedFloat32Array,
	right: PackedFloat32Array,
	spb: float,
	total_samples: int
) -> void:
	var inst: Dictionary = track.get("instrument", {})
	var gain: float = track.get("gain", 0.5)
	var pan: float = clampf(track.get("pan", 0.0), -1.0, 1.0)

	# Equal-power panning keeps perceived loudness constant across the stereo
	# field, unlike naive linear panning which dips in the middle.
	var pan_angle: float = (pan + 1.0) * 0.25 * PI
	var gain_l: float = cos(pan_angle) * gain
	var gain_r: float = sin(pan_angle) * gain

	var wave: int = inst.get("wave", WAVE_PULSE)
	var pulse_width: float = inst.get("pulse_width", 0.5)
	var attack: float = maxf(inst.get("attack", 0.005), 0.0001)
	var decay: float = maxf(inst.get("decay", 0.08), 0.0001)
	var sustain: float = clampf(inst.get("sustain", 0.6), 0.0, 1.0)
	var release: float = maxf(inst.get("release", 0.10), 0.0001)
	var octave: int = inst.get("octave", 0)
	# Pitch envelope: how many semitones the note falls over `pitch_env_time`
	# seconds. This is what turns a sine into a kick drum.
	var pitch_drop: float = inst.get("pitch_drop", 0.0)
	var pitch_time: float = maxf(inst.get("pitch_time", 0.05), 0.0001)
	# Fraction of the signal replaced by noise. Used for snares and hats.
	var noise_mix: float = clampf(inst.get("noise_mix", 0.0), 0.0, 1.0)

	# Envelope stage lengths in samples, hoisted out of the note loop.
	var voice := {
		"wave": wave,
		"pulse_width": pulse_width,
		"sustain": sustain,
		"octave": octave,
		"pitch_drop": pitch_drop,
		"pitch_time_s": pitch_time * MIX_RATE,
		"noise_mix": noise_mix,
		"attack_s": int(attack * MIX_RATE),
		"decay_s": int(decay * MIX_RATE),
		"release_s": int(release * MIX_RATE),
		"gain_l": gain_l,
		"gain_r": gain_r,
	}

	# Deterministic noise source. Seeded per track so two tracks using noise do
	# not produce correlated (and therefore phasey) output. Threaded through the
	# note loop by hand so the sequence is continuous across notes, which is what
	# keeps repeated hats from sounding identical.
	var rng_state: int = int(track.get("noise_seed", 12345)) | 1

	for note in track.get("notes", []):
		rng_state = _render_note(
			note, voice, left, right, spb, total_samples, rng_state)


## Render a single note into the accumulation buffers. Returns the advanced
## noise generator state.
##
## Split from _render_track for readability at a measured 54% cost (1284ms ->
## 1980ms per song). Not the call itself, which happens a few hundred times: it
## is that writing to a Packed*Array held in a PARAMETER makes GDScript do a
## copy-on-write uniqueness check on each of ~5M element writes. Accepted, since
## synthesis is one-time background work that is then cached forever.
##
## The per-sample loop below must stay inlined; extracting the oscillator would
## add a call to each of those 5M iterations.
static func _render_note(
	note: Array,
	voice: Dictionary,
	left: PackedFloat32Array,
	right: PackedFloat32Array,
	spb: float,
	total_samples: int,
	rng_state: int
) -> int:
	# Note format: [beat, duration_in_beats, midi, velocity]
	var beat: float = note[0]
	var dur_beats: float = note[1]
	var midi: float = note[2]
	var velocity: float = note[3] if note.size() > 3 else 1.0

	var start: int = int(beat * spb * MIX_RATE)
	if start >= total_samples:
		return rng_state

	var wave: int = voice["wave"]
	var pulse_width: float = voice["pulse_width"]
	var sustain: float = voice["sustain"]
	var pitch_drop: float = voice["pitch_drop"]
	var pitch_time_s: float = voice["pitch_time_s"]
	var noise_mix: float = voice["noise_mix"]
	var attack_s: int = voice["attack_s"]
	var decay_s: int = voice["decay_s"]
	var release_s: int = voice["release_s"]
	var gain_l: float = voice["gain_l"]
	var gain_r: float = voice["gain_r"]

	var hold_s: int = int(dur_beats * spb * MIX_RATE)
	var life_s: int = hold_s + release_s
	var base_freq: float = midi_to_freq(midi + float(int(voice["octave"]) * 12))
	var phase: float = 0.0

	for i in life_s:
		var idx: int = start + i
		if idx >= total_samples:
			break

		# --- Amplitude envelope (ADSR) ---
		var env: float
		if i < attack_s:
			env = float(i) / float(attack_s)
		elif i < attack_s + decay_s:
			var d: float = float(i - attack_s) / float(decay_s)
			env = lerpf(1.0, sustain, d)
		elif i < hold_s:
			env = sustain
		else:
			var r: float = float(i - hold_s) / float(release_s)
			env = lerpf(sustain, 0.0, clampf(r, 0.0, 1.0))

		if env <= 0.0:
			continue

		# --- Pitch envelope ---
		# An exponential fall from `pitch_drop` semitones above the note down to
		# the note itself. With a large drop and a short time this is a kick;
		# with a small drop it is a subtle attack transient.
		var freq: float = base_freq
		if pitch_drop > 0.0:
			var pe: float = exp(-float(i) / pitch_time_s)
			freq = base_freq * pow(2.0, (pitch_drop * pe) / 12.0)

		phase += freq / float(MIX_RATE)
		if phase >= 1.0:
			phase -= floorf(phase)

		# --- Oscillator ---
		var s: float = 0.0
		if wave == WAVE_PULSE:
			s = 1.0 if phase < pulse_width else -1.0
		elif wave == WAVE_TRIANGLE:
			s = 4.0 * absf(phase - 0.5) - 1.0
		elif wave == WAVE_SAW:
			s = 2.0 * phase - 1.0
		elif wave == WAVE_SINE:
			s = sin(phase * TAU)
		else:
			# Noise falls through to the LCG below.
			s = 0.0

		if noise_mix > 0.0 or wave == WAVE_NOISE:
			# 32-bit linear congruential generator (Numerical Recipes
			# constants), masked to stay inside GDScript's 64-bit ints.
			rng_state = (rng_state * 1664525 + 1013904223) & 0xFFFFFFFF
			var n: float = (float(rng_state) / 2147483648.0) - 1.0
			s = n if wave == WAVE_NOISE else lerpf(s, n, noise_mix)

		var value: float = s * env * velocity
		left[idx] += value * gain_l
		right[idx] += value * gain_r

	return rng_state


## Convert the float accumulation buffers into a looping 16-bit AudioStreamWAV.
static func _to_stream(
	left: PackedFloat32Array,
	right: PackedFloat32Array,
	total_samples: int,
	_duration: float
) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	# 16-bit stereo: 2 channels * 2 bytes per sample frame.
	bytes.resize(total_samples * 4)

	for i in total_samples:
		var l: int = _encode_sample(left[i])
		var r: int = _encode_sample(right[i])
		var o: int = i * 4
		bytes[o + 0] = l & 0xFF
		bytes[o + 1] = (l >> 8) & 0xFF
		bytes[o + 2] = r & 0xFF
		bytes[o + 3] = (r >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = true
	stream.data = bytes
	# Loop the entire buffer. The song is a whole number of bars, so the wrap
	# lands exactly on a downbeat and is inaudible.
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total_samples
	return stream


## Soft-clip a float sample and encode it as a signed 16-bit integer.
##
## tanh-style saturation rather than a hard clamp: when several tracks land on
## the same downbeat the sum can exceed 1.0, and hard clipping that would sound
## like a crackle rather than like loudness.
static func _encode_sample(v: float) -> int:
	var x: float = v * MASTER_GAIN
	# Cheap tanh approximation, accurate enough for saturation duty and much
	# faster than the real thing across a million-sample buffer.
	var saturated: float = x / (1.0 + absf(x))
	var i: int = int(round(saturated * 32767.0))
	return clampi(i, -32768, 32767) & 0xFFFF
