extends SceneTree
func _init() -> void:
	var songs := SongLibrary.all_songs()
	var sums := {}
	for s in songs:
		var st := Synth.render_song(s)
		var note_total := 0
		for t in s["tracks"]:
			note_total += t["notes"].size()
		# Cheap checksum over the PCM: sum every 97th byte, weighted by index.
		var sum := 0
		var i := 0
		while i < st.data.size():
			sum = (sum + st.data[i] * (i % 251 + 1)) % 1000000007
			i += 97
		print("%-14s bpm=%3d tracks=%d notes=%4d bytes=%d pcmsum=%d" % [
			s["name"], int(s["bpm"]), s["tracks"].size(), note_total,
			st.data.size(), sum])
		sums[s["id"]] = sum
	var ids := sums.keys()
	for a in ids.size():
		for b in range(a + 1, ids.size()):
			if sums[ids[a]] == sums[ids[b]]:
				print("IDENTICAL AUDIO: ", ids[a], " == ", ids[b])
	quit(0)
