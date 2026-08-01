class_name SongLibrary
extends RefCounted

## Song definitions.
##
## Each track has its own STYLE, not just its own tempo. An earlier version
## shared one progression, one drum kit and one bassline across all three, so
## they were audibly the same piece played at different speeds.
##
## What differs per track: chord progression, drum pattern, bass rhythm, lead
## instrument, arpeggio behaviour and which parts are present at all.
##
## Format: { id, name, bpm, beats_per_bar, bars, difficulty, tracks }.
## `bpm` is the ground truth the entire game clock derives from.

const A1: int = 33
const A2: int = 45
const A3: int = 57
const A4: int = 69

const MINOR_PENTATONIC: Array[int] = [0, 3, 5, 7, 10]

# --- Instruments ------------------------------------------------------------

const INST_KICK: Dictionary = {
	"wave": Synth.WAVE_SINE,
	"attack": 0.001, "decay": 0.09, "sustain": 0.0, "release": 0.02,
	# A 34-semitone fall over 40ms is what makes a sine read as a kick: the ear
	# hears the pitch sweep as the beater impact.
	"pitch_drop": 34.0, "pitch_time": 0.040,
}

const INST_SNARE: Dictionary = {
	"wave": Synth.WAVE_NOISE,
	"attack": 0.001, "decay": 0.11, "sustain": 0.0, "release": 0.03,
}

const INST_HAT: Dictionary = {
	"wave": Synth.WAVE_NOISE,
	"attack": 0.0005, "decay": 0.028, "sustain": 0.0, "release": 0.01,
}

const INST_BASS_ROUND: Dictionary = {
	"wave": Synth.WAVE_TRIANGLE,
	"attack": 0.004, "decay": 0.05, "sustain": 0.85, "release": 0.05,
	"pitch_drop": 0.6, "pitch_time": 0.02,
}

const INST_BASS_REEDY: Dictionary = {
	"wave": Synth.WAVE_SAW,
	"attack": 0.002, "decay": 0.06, "sustain": 0.55, "release": 0.04,
}

const INST_ARP: Dictionary = {
	"wave": Synth.WAVE_PULSE, "pulse_width": 0.25,
	"attack": 0.002, "decay": 0.06, "sustain": 0.35, "release": 0.05,
}

const INST_LEAD_SOFT: Dictionary = {
	"wave": Synth.WAVE_PULSE, "pulse_width": 0.45,
	"attack": 0.020, "decay": 0.10, "sustain": 0.70, "release": 0.18,
}

const INST_LEAD_SHARP: Dictionary = {
	"wave": Synth.WAVE_SAW,
	"attack": 0.004, "decay": 0.09, "sustain": 0.60, "release": 0.09,
}

const INST_LEAD_HARD: Dictionary = {
	"wave": Synth.WAVE_PULSE, "pulse_width": 0.16,
	"attack": 0.002, "decay": 0.07, "sustain": 0.55, "release": 0.06,
}

const INST_PAD: Dictionary = {
	"wave": Synth.WAVE_SAW,
	"attack": 0.12, "decay": 0.30, "sustain": 0.55, "release": 0.35,
}


## Every song, in menu order.
##
## The three styles are meant to feel like different pieces, not one piece at
## three speeds:
##
##   neon_ascent   112  warm synthwave. Am-F-C-G, four-on-the-floor, round
##                      triangle bass on eighths, soft pulse lead, no arp.
##   vector_drive  128  driving. Am-G-F-G, pumping OFFBEAT bass, sixteenth
##                      hats, saw lead, arpeggio running throughout.
##   overclock     150  aggressive. Am-Em-F-Dm, BROKEN kick (not four to the
##                      floor), snare pushed onto the offbeat, hard narrow-pulse
##                      lead high in the register, fast arp, no pad.
static func all_songs() -> Array[Dictionary]:
	return [
		_build({
			"id": "neon_ascent", "name": "Neon Ascent", "bpm": 112.0,
			"difficulty": 0,
			"progression": [0, 8, 3, 10],
			"shapes": [[0, 3, 7], [0, 4, 7], [0, 4, 7], [0, 4, 7]],
			"kick": "four", "snare": "backbeat", "hat_div": 0.5,
			"bass": "eighths", "bass_inst": INST_BASS_ROUND,
			"lead_inst": INST_LEAD_SOFT, "lead_octave": 0,
			"arp": false, "pad": true,
			"motif": [0, 3, 5, 3, 7, 5, 3, 0],
			"lead_gain": 0.30, "rest_phrase": true,
		}),
		_build({
			"id": "vector_drive", "name": "Vector Drive", "bpm": 128.0,
			"difficulty": 1,
			"progression": [0, 10, 8, 10],
			"shapes": [[0, 3, 7], [0, 4, 7], [0, 4, 7], [0, 4, 7]],
			"kick": "four", "snare": "backbeat", "hat_div": 0.25,
			"bass": "offbeat", "bass_inst": INST_BASS_REEDY,
			"lead_inst": INST_LEAD_SHARP, "lead_octave": 0,
			"arp": true, "pad": true,
			"motif": [7, 5, 7, 10, 12, 10, 7, 5],
			"lead_gain": 0.26, "rest_phrase": true,
		}),
		_build({
			"id": "overclock", "name": "Overclock", "bpm": 150.0,
			"difficulty": 2,
			"progression": [0, 7, 8, 5],
			"shapes": [[0, 3, 7], [0, 3, 7], [0, 4, 7], [0, 3, 7]],
			"kick": "broken", "snare": "pushed", "hat_div": 0.25,
			"bass": "driving", "bass_inst": INST_BASS_REEDY,
			"lead_inst": INST_LEAD_HARD, "lead_octave": 1,
			"arp": true, "pad": false,
			"motif": [12, 10, 7, 10, 12, 15, 12, 10],
			"lead_gain": 0.22, "rest_phrase": false,
		}),
	]


static func get_song(id: String) -> Dictionary:
	var songs := all_songs()
	for s in songs:
		if s["id"] == id:
			return s
	return songs[0]


static func _build(style: Dictionary) -> Dictionary:
	var bars: int = 16
	var bpb: int = 4
	var tracks: Array = []

	tracks.append({
		"instrument": INST_KICK, "gain": 0.95, "pan": 0.0,
		"notes": _kick(style["kick"], bars, bpb),
	})
	tracks.append({
		"instrument": INST_SNARE, "gain": 0.32, "pan": 0.0, "noise_seed": 7717,
		"notes": _snare(style["snare"], bars, bpb),
	})
	tracks.append({
		"instrument": INST_HAT, "gain": 0.15, "pan": 0.35, "noise_seed": 3391,
		"notes": _hats(style["hat_div"], bars, bpb),
	})
	tracks.append({
		"instrument": style["bass_inst"], "gain": 0.52, "pan": 0.0,
		"notes": _bass(style, bars, bpb),
	})
	if style["pad"]:
		tracks.append({
			"instrument": INST_PAD, "gain": 0.12, "pan": -0.25,
			"notes": _pad(style, bars, bpb),
		})
	if style["arp"]:
		tracks.append({
			"instrument": INST_ARP, "gain": 0.19, "pan": 0.45,
			"notes": _arp(style, bars, bpb),
		})
	tracks.append({
		"instrument": style["lead_inst"], "gain": style["lead_gain"], "pan": -0.15,
		"notes": _lead(style, bars, bpb),
	})

	return {
		"id": style["id"], "name": style["name"], "bpm": style["bpm"],
		"beats_per_bar": bpb, "bars": bars,
		"difficulty": style["difficulty"], "tracks": tracks,
	}


static func _chord(style: Dictionary, bar: int) -> int:
	var prog: Array = style["progression"]
	return int(prog[bar % prog.size()])


static func _shape(style: Dictionary, bar: int) -> Array:
	var shapes: Array = style["shapes"]
	return shapes[bar % shapes.size()]


## Kick patterns. "four" is the steady spine the player locks onto; "broken"
## leaves gaps on the beat, which is what makes Overclock feel unsettled.
static func _kick(pattern: String, bars: int, bpb: int) -> Array:
	var notes: Array = []
	for bar in bars:
		var base := float(bar * bpb)
		if pattern == "four":
			for b in bpb:
				notes.append([base + float(b), 0.2, A2, 1.0 if b == 0 else 0.82])
		else:
			# Beat 1, the "and" of 2, and beat 4: a syncopated figure that pulls
			# against the hats instead of sitting under them.
			notes.append([base + 0.0, 0.2, A2, 1.0])
			notes.append([base + 1.5, 0.18, A2, 0.78])
			notes.append([base + 3.0, 0.2, A2, 0.88])
			if bar % 2 == 1:
				notes.append([base + 2.5, 0.16, A2, 0.6])
	return notes


static func _snare(pattern: String, bars: int, bpb: int) -> Array:
	var notes: Array = []
	for bar in bars:
		var base := float(bar * bpb)
		if pattern == "backbeat":
			notes.append([base + 1.0, 0.14, A4, 0.9])
			notes.append([base + 3.0, 0.14, A4, 0.9])
		else:
			# Pushed: the backbeat lands a sixteenth early, which reads as
			# urgency without changing the tempo.
			notes.append([base + 0.75, 0.12, A4, 0.85])
			notes.append([base + 2.75, 0.12, A4, 0.9])
			notes.append([base + 3.5, 0.10, A4, 0.55])
		# A fill telegraphs the loop point.
		if bar % 8 == 7:
			notes.append([base + 3.5, 0.10, A4, 0.7])
			notes.append([base + 3.75, 0.10, A4, 0.85])
	return notes


static func _hats(div: float, bars: int, bpb: int) -> Array:
	var notes: Array = []
	var steps := int(float(bars * bpb) / div)
	for i in steps:
		var beat := float(i) * div
		notes.append([beat, 0.05, A4, 0.85 if fmod(beat, 1.0) == 0.0 else 0.45])
	return notes


## Bass rhythms, the biggest single contributor to a track's feel.
static func _bass(style: Dictionary, bars: int, bpb: int) -> Array:
	var notes: Array = []
	var mode: String = style["bass"]
	for bar in bars:
		var root := A1 + _chord(style, bar)
		var base := float(bar * bpb)
		if mode == "eighths":
			# Root on the beat, fifth on the offbeat: steady synthwave motion.
			for step in bpb * 2:
				var midi := root if step % 2 == 0 else root + 7
				notes.append([base + float(step) * 0.5, 0.45, midi, 0.9])
		elif mode == "offbeat":
			# Nothing on the downbeat, so the kick has the beat to itself and
			# the bass pumps between hits.
			for step in bpb * 2:
				if step % 2 == 0:
					continue
				notes.append([base + float(step) * 0.5, 0.4, root, 0.95])
			notes.append([base, 0.9, root - 12, 0.7])
		else:
			# Driving sixteenths on the root with an octave jump each bar.
			for step in bpb * 4:
				var beat := base + float(step) * 0.25
				var midi := root + (12 if step % 8 == 6 else 0)
				notes.append([beat, 0.22, midi, 0.9 if step % 4 == 0 else 0.7])
	return notes


static func _pad(style: Dictionary, bars: int, bpb: int) -> Array:
	var notes: Array = []
	for bar in bars:
		var root := A3 + _chord(style, bar)
		for offset in _shape(style, bar):
			notes.append([float(bar * bpb), float(bpb) - 0.1, root + int(offset), 0.7])
	return notes


static func _arp(style: Dictionary, bars: int, bpb: int) -> Array:
	var notes: Array = []
	for bar in bars:
		if bar < 2:
			continue
		var root := A4 + _chord(style, bar)
		var shape := _shape(style, bar)
		for step in bpb * 4:
			var degree := step % shape.size()
			var octave_up := int(step / shape.size()) % 2
			notes.append([
				float(bar * bpb) + float(step) * 0.25, 0.22,
				root + int(shape[degree]) + octave_up * 12, 0.75,
			])
	return notes


## The melody: the track's identity. Motif degrees are pentatonic, so every note
## is consonant over every chord and a transposed figure can never land wrong.
static func _lead(style: Dictionary, bars: int, bpb: int) -> Array:
	var notes: Array = []
	var motif: Array = style["motif"]
	if motif.is_empty():
		return notes

	for bar in bars:
		# Resting two bars in eight lets the loop breathe. Overclock skips the
		# rest entirely, which is part of why it feels relentless.
		if style["rest_phrase"] and (bar % 8 == 2 or bar % 8 == 3):
			continue

		var root := A4 + _chord(style, bar) + int(style["lead_octave"]) * 12
		for step in bpb:
			var index := (bar * bpb + step) % motif.size()
			notes.append([
				float(bar * bpb + step), 0.9,
				root + _pentatonic(int(motif[index])), 0.85,
			])
	return notes


static func _pentatonic(degree: int) -> int:
	var size := MINOR_PENTATONIC.size()
	var octave := int(floor(float(degree) / float(size)))
	var index := degree % size
	if index < 0:
		index += size
	return MINOR_PENTATONIC[index] + octave * 12
