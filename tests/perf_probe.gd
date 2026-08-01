extends SceneTree

## Throwaway performance probe for the synthesiser.
##
## Measures how long a single song takes to render, and how many sample-writes
## that involves, so the cost can be attributed rather than guessed at.

func _init() -> void:
	var song := SongLibrary.all_songs()[0]

	# Count the work the renderer is actually being asked to do.
	var spb := 60.0 / float(song["bpm"])
	var note_seconds := 0.0
	var note_count := 0
	for track in song["tracks"]:
		var inst: Dictionary = track["instrument"]
		var release: float = inst.get("release", 0.1)
		for n in track["notes"]:
			note_seconds += float(n[1]) * spb + release
			note_count += 1

	var iterations := note_seconds * float(Synth.MIX_RATE)
	print("song            : %s" % song["name"])
	print("notes           : %d" % note_count)
	print("note-seconds    : %.1f" % note_seconds)
	print("inner iterations: %.0f" % iterations)

	var t0 := Time.get_ticks_msec()
	var stream := Synth.render_song(song)
	var elapsed := Time.get_ticks_msec() - t0

	print("render time     : %d ms" % elapsed)
	print("bytes           : %d" % stream.data.size())
	if elapsed > 0:
		print("throughput      : %.2f M iter/sec"
			% (iterations / float(elapsed) / 1000.0))
	quit(0)
