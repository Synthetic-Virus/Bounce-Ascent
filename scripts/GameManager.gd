extends Node

# Singleton for managing game state, profiles, and statistics

# Security keys (split across multiple locations for obfuscation)
const KEY_PART_1 = "BounceAscent"
const KEY_PART_2 = "SecureGame"
const KEY_PART_3 = "2024Edition"

# Current game session data
var current_profile: Dictionary = {}
var session_stats: Dictionary = {
	"height": 0,
	"platforms_landed": 0,
	"platforms_broken": 0,
	"time_survived": 0.0,
	"edge_escape_attempts": 0,
	"start_time": 0.0
}

# Runtime anti-cheat redundancy
var _height_check: int = 0
var _platforms_check: int = 0
var _game_active: bool = false
var _last_validation_time: float = 0.0

signal profile_loaded(profile_data: Dictionary)
signal stats_updated(stats: Dictionary)

func _ready():
	load_or_create_profile()

func _notification(what):
	# Detect rage quits and save session data
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _game_active and session_stats.time_survived > 0:
			# End session and save all data (including rage quit)
			current_profile.rage_quit_count += 1
			end_game_session("rage_quit")
		else:
			# Just save profile if not in game
			save_profile()
		get_tree().quit()

# Profile Management
func load_or_create_profile():
	var save_path = "user://profile.save"

	if FileAccess.file_exists(save_path):
		var loaded_profile = load_profile_from_file(save_path)
		if loaded_profile != null:
			current_profile = loaded_profile
			profile_loaded.emit(current_profile)
			return

	# Create new profile
	current_profile = create_default_profile()
	save_profile()
	profile_loaded.emit(current_profile)

func create_default_profile() -> Dictionary:
	return {
		"username": "Player",
		"ball_color": Color(0.29, 0.62, 1.0).to_html(),  # Neon blue as hex
		"high_score": 0,
		"total_runs": 0,
		"platforms_landed": 0,
		"platforms_broken": 0,
		"total_height": 0,
		"total_time_survived": 0.0,
		"edge_escape_attempts": 0,
		"fell_to_death_count": 0,
		"rage_quit_count": 0,
		"created_timestamp": Time.get_unix_time_from_system(),
		"last_played": Time.get_unix_time_from_system()
	}

func update_username(new_name: String):
	current_profile.username = new_name
	save_profile()
	profile_loaded.emit(current_profile)

func update_ball_color(new_color: Color):
	current_profile.ball_color = new_color.to_html()
	save_profile()
	profile_loaded.emit(current_profile)

func get_ball_color() -> Color:
	if current_profile.has("ball_color"):
		return Color.html(current_profile.ball_color)
	return Color(0.29, 0.62, 1.0)  # Default neon blue

func save_profile():
	current_profile.last_played = Time.get_unix_time_from_system()

	var save_path = "user://profile.save"
	var profile_json = JSON.stringify(current_profile)

	# Generate checksum
	var checksum = generate_checksum(profile_json)

	# Generate HMAC signature
	var signature = generate_hmac(profile_json)

	# Create encrypted payload
	var payload = {
		"profile": current_profile,
		"checksum": checksum,
		"signature": signature,
		"timestamp": Time.get_unix_time_from_system()
	}

	var payload_json = JSON.stringify(payload)
	var encrypted_data = encrypt_data(payload_json)

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(encrypted_data)
		file.close()

func load_profile_from_file(save_path: String):
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return null

	var encrypted_data = file.get_as_text()
	file.close()

	# Decrypt
	var decrypted_json = decrypt_data(encrypted_data)
	if decrypted_json == "":
		push_error("Failed to decrypt profile data")
		return null

	var json = JSON.new()
	var parse_result = json.parse(decrypted_json)
	if parse_result != OK:
		push_error("Failed to parse profile JSON")
		return null

	var payload = json.data

	# Verify signature
	var profile_json = JSON.stringify(payload.profile)
	var expected_signature = generate_hmac(profile_json)
	if payload.signature != expected_signature:
		# Signature mismatch - likely old format, just return null silently
		return null

	# Verify checksum
	var expected_checksum = generate_checksum(profile_json)
	if payload.checksum != expected_checksum:
		push_error("Profile checksum verification failed - data corrupted")
		return null

	# Validate statistics for impossibilities
	if not validate_profile_stats(payload.profile):
		push_error("Profile statistics validation failed - impossible values detected")
		return null

	return payload.profile

# Encryption/Security Functions
func generate_checksum(data: String) -> String:
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data.to_utf8_buffer())
	return ctx.finish().hex_encode()

func generate_hmac(data: String) -> String:
	# Simple HMAC using secret key
	var secret_key = get_secret_key()
	var combined = secret_key + data + secret_key
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(combined.to_utf8_buffer())
	return ctx.finish().hex_encode()

func get_secret_key() -> String:
	# Obfuscated key generation
	var key = KEY_PART_1 + KEY_PART_2 + KEY_PART_3
	return key.sha256_text()

func encrypt_data(data: String) -> String:
	# Simple XOR encryption with key derivation
	var key = get_secret_key()
	var encrypted = PackedByteArray()
	var data_bytes = data.to_utf8_buffer()

	for i in range(data_bytes.size()):
		var key_byte = key.unicode_at(i % key.length())
		encrypted.append(data_bytes[i] ^ (key_byte % 256))

	return Marshalls.raw_to_base64(encrypted)

func decrypt_data(encrypted_b64: String) -> String:
	var key = get_secret_key()
	var encrypted = Marshalls.base64_to_raw(encrypted_b64)
	var decrypted = PackedByteArray()

	for i in range(encrypted.size()):
		var key_byte = key.unicode_at(i % key.length())
		decrypted.append(encrypted[i] ^ (key_byte % 256))

	return decrypted.get_string_from_utf8()

# Statistics Validation
func validate_profile_stats(profile: Dictionary) -> bool:
	# Can't break more platforms than landed on
	if profile.platforms_broken > profile.platforms_landed:
		return false

	# Height should correlate with platforms landed (max 2x for platform skipping)
	if profile.total_height > profile.platforms_landed * 2 and profile.platforms_landed > 0:
		return false

	# Time should be reasonable for height (minimum 0.3 seconds per height unit)
	if profile.total_height > 0 and profile.total_time_survived > 0:
		var min_time = profile.total_height * 0.3
		if profile.total_time_survived < min_time:
			return false

	# Runs should be positive
	if profile.total_runs < 0:
		return false

	return true

# Session Management
func start_game_session():
	_game_active = true
	session_stats = {
		"height": 0,
		"platforms_landed": 0,
		"platforms_broken": 0,
		"time_survived": 0.0,
		"edge_escape_attempts": 0,
		"start_time": Time.get_unix_time_from_system()
	}
	_height_check = 0
	_platforms_check = 0
	_last_validation_time = Time.get_ticks_msec()

func end_game_session(death_type: String):
	_game_active = false

	# Final validation
	if not validate_session_stats():
		push_error("Session validation failed - discarding stats")
		return

	# Calculate score
	var score = calculate_score(session_stats)

	# Update profile
	current_profile.total_runs += 1
	current_profile.platforms_landed += session_stats.platforms_landed
	current_profile.platforms_broken += session_stats.platforms_broken
	current_profile.total_height += session_stats.height
	current_profile.total_time_survived += session_stats.time_survived
	current_profile.edge_escape_attempts += session_stats.edge_escape_attempts

	if death_type == "fell":
		current_profile.fell_to_death_count += 1

	# Update high score (use >= to ensure it saves even if equal)
	if score >= current_profile.high_score:
		current_profile.high_score = score

	# Emit stats updated signal for UI
	stats_updated.emit(session_stats)

	save_profile()

func calculate_score(stats: Dictionary) -> int:
	var score = 0
	score += stats.height * 10
	score += stats.platforms_landed * 5
	score += int(stats.time_survived * 2)
	return score

func validate_session_stats() -> bool:
	# Redundancy check
	if session_stats.height != _height_check:
		push_warning("Validation failed: height mismatch. height=%d, _height_check=%d" % [session_stats.height, _height_check])
		return false
	if session_stats.platforms_landed != _platforms_check:
		push_warning("Validation failed: platforms mismatch. platforms_landed=%d, _platforms_check=%d" % [session_stats.platforms_landed, _platforms_check])
		return false

	# Can't break more than landed
	if session_stats.platforms_broken > session_stats.platforms_landed:
		push_warning("Validation failed: broken > landed")
		return false

	# Height can't exceed platforms landed * 20 (combo system allows VERY high jumps)
	if session_stats.height > session_stats.platforms_landed * 20:
		push_warning("Validation failed: height > platforms * 20. height=%d, platforms=%d" % [session_stats.height, session_stats.platforms_landed])
		return false

	# Time must be reasonable (relaxed due to faster bounces with combo)
	var min_time = session_stats.height * 0.1
	if session_stats.time_survived < min_time and session_stats.height > 50:
		push_warning("Validation failed: time too short. time=%f, min_time=%f" % [session_stats.time_survived, min_time])
		return false

	print("Session validation passed! Stats: ", session_stats)
	return true

# Session stat incrementers with validation
func increment_height():
	if not _game_active:
		return
	session_stats.height += 1
	_height_check += 1
	stats_updated.emit(session_stats)

func increment_platform_landed():
	if not _game_active:
		return
	session_stats.platforms_landed += 1
	_platforms_check += 1

func increment_platform_broken():
	if not _game_active:
		return
	session_stats.platforms_broken += 1

func increment_edge_escape():
	if not _game_active:
		return
	session_stats.edge_escape_attempts += 1

func update_time_survived(delta: float):
	if not _game_active:
		return

	# Anti-speedhack: validate delta time
	if delta > 0.1 or delta < 0:  # Max 100ms per frame, no negative time
		push_warning("Suspicious delta time detected: " + str(delta))
		return

	session_stats.time_survived += delta

func get_current_score() -> int:
	return calculate_score(session_stats)
