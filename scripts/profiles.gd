class_name GravityProfiles
extends RefCounted

const MODES := ["ai_easy", "ai_normal", "ai_hard", "ai_master", "local", "online", "ai_easy_series3", "ai_normal_series3", "ai_hard_series3", "ai_master_series3", "local_series3", "online_series3", "ai_easy_series5", "ai_normal_series5", "ai_hard_series5", "ai_master_series5", "local_series5", "online_series5"]
const FRAME_TITLES := ["素雅", "初征铜环", "常客翠环", "进阶银辉", "博弈紫晶", "大师金冠", "空间星轨", "十胜王冠", "AI 铜", "AI 银", "AI 紫", "AI 金", "曜影龙魂", "天穹轨环", "星凰双翼", "棋圣御冕", "逆冕星辉", "锋芒晶刃"]
const FRAME_REQUIREMENTS := ["", "first_game", "games10", "normal_win", "hard_win", "master_win", "space_win", "wins10", "", "", "", "", "master_late", "master_space", "master_dual", "master_sweep", "master_comeback", "master_fast"]
const HUMAN_FRAMES := [0,1,2,3,4,5,6,7,12,13,14,15,16,17]
const AVATAR_REQUIREMENTS := ["","","","","","","","","master_late","master_space","master_dual","master_sweep","master_comeback"]
const Achievements = preload("res://scripts/achievements.gd")
var last_unlocks: Array[String] = []
var path := "user://profiles_v2.json"
var data := {"version": 2, "settings": {}, "profiles": {}, "history": []}

func _init(storage_path: String = "user://profiles_v2.json") -> void:
	path = storage_path
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and parsed.get("profiles") is Dictionary and parsed.get("history") is Array and parsed.get("settings") is Dictionary:
			data = parsed
	if not data.has("users"): data["users"] = {}
	if not data.has("seen"): data["seen"] = []
	if not data.has("achievements"): data["achievements"] = {}
	for username in data.profiles:
		_ensure_user(str(username))
	# Fold old case variants into one registered account without losing totals.
	for old_name in data.profiles.keys():
		var canonical := _ensure_user(str(old_name))
		if canonical == str(old_name): continue
		if not data.profiles.has(canonical): data.profiles[canonical] = {}
		for mode_key in data.profiles[old_name]:
			var source: Dictionary = data.profiles[old_name][mode_key]
			if not data.profiles[canonical].has(mode_key):
				data.profiles[canonical][mode_key] = source.duplicate()
			else:
				var target: Dictionary = data.profiles[canonical][mode_key]
				for total in ["games", "wins", "losses", "draws", "points", "moves", "seconds"]: target[total] += source[total]
				target.best_streak = maxi(int(target.best_streak), int(source.best_streak))
				target.streak = 0
				if float(source.fastest_win) >= 0 and (float(target.fastest_win) < 0 or float(source.fastest_win) < float(target.fastest_win)): target.fastest_win = source.fastest_win
		data.profiles.erase(old_name)
	for record_data in data.history:
		var uid := str(record_data.get("uid", ""))
		if uid not in data.seen: data.seen.append(uid)
	_ensure_user(str(data.settings.get("username", "玩家")))
	_ensure_user(str(data.settings.get("opponent", "玩家二")))

	for username in data.profiles:
		var scores: Dictionary = data.profiles[username]
		for key in scores.keys():
			if not (str(key).ends_with("_alternate") or str(key).ends_with("_blitz")): continue
			var base: String = str(key).trim_suffix("_alternate").trim_suffix("_blitz")
			if not scores.has(base): scores[base] = scores[key].duplicate()
			else:
				var target: Dictionary = scores[base]
				var old: Dictionary = scores[key]
				for total in ["games","wins","losses","draws","points","moves","seconds"]: target[total] += old[total]
				target.best_streak = maxi(int(target.best_streak),int(old.best_streak))
				target.streak = 0
				if float(old.fastest_win) >= 0 and (float(target.fastest_win) < 0 or float(old.fastest_win) < float(target.fastest_win)): target.fastest_win = old.fastest_win
			scores.erase(key)

	if int(data.settings.get("rules_version",0)) < 38:
		data.settings["ruleset"] = 0
		data.settings["game_seconds"] = 0
		data.settings["rules_version"] = 38
	while data.history.size() > 20: data.history.pop_front()
	data.version = 3

static func clean_name(value: String, fallback: String = "玩家") -> String:
	var result := ""
	for c in value.strip_edges():
		if c.unicode_at(0) >= 32 and c.unicode_at(0) != 127:
			result += c
	result = result.left(16)
	return result if not result.is_empty() else fallback

func save() -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK

func record(match_data: Dictionary, entries: Array[Dictionary]) -> bool:
	last_unlocks.clear()
	var uid := str(match_data.uid)
	if uid in data.seen: return false
	data.seen.append(uid)
	data.history.append(match_data.duplicate(true))
	if data.history.size() > 20:
		data.history.pop_front()
	for entry in entries:
		var username := _ensure_user(str(entry.name))
		if not data.profiles.has(username):
			data.profiles[username] = {}
		var mode_key := str(match_data.mode)
		if mode_key.trim_suffix("_blitz").trim_suffix("_alternate").trim_suffix("_series3").trim_suffix("_series5") not in MODES:
			continue
		if not data.profiles[username].has(mode_key):
			data.profiles[username][mode_key] = {"games": 0, "wins": 0, "losses": 0, "draws": 0, "points": 0,
				"streak": 0, "best_streak": 0, "fastest_win": -1.0, "moves": 0, "seconds": 0.0}
		var stats: Dictionary = data.profiles[username][mode_key]
		stats.games += 1
		stats.moves += int(entry.moves)
		stats.seconds += float(match_data.seconds)
		if int(entry.result) == 1:
			stats.wins += 1
			stats.points += 3
			stats.streak += 1
			stats.best_streak = maxi(int(stats.best_streak), int(stats.streak))
			if float(stats.fastest_win) < 0 or float(match_data.seconds) < float(stats.fastest_win):
				stats.fastest_win = float(match_data.seconds)
		elif int(entry.result) == 0:
			stats.draws += 1
			stats.points += 1
			stats.streak = 0
		else:
			stats.losses += 1
			stats.streak = 0
		var totals := {"games":0,"wins":0,"best_streak":0}
		for mode_stats in data.profiles[username].values():
			totals.games += int(mode_stats.games)
			totals.wins += int(mode_stats.wins)
			totals.best_streak = maxi(int(totals.best_streak),int(mode_stats.best_streak))
		var key := username.to_lower()
		if not data.achievements.has(key): data.achievements[key] = {}
		for id in Achievements.eligible(match_data,int(entry.result),totals):
			if not data.achievements[key].has(id):
				data.achievements[key][id] = Time.get_datetime_string_from_system()
				for item in Achievements.ITEMS:
					if item[0] == id: last_unlocks.append(username + " · " + item[1])
	save()
	return true

func ranking(mode_key: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for username in data.profiles:
		if mode_key == "*" and not data.profiles[username].is_empty():
			var stats := {"games":0,"wins":0,"losses":0,"draws":0,"points":0,"best_streak":0}
			for source in data.profiles[username].values():
				for key in ["games","wins","losses","draws","points"]: stats[key] += int(source.get(key,0))
				stats.best_streak = maxi(int(stats.best_streak),int(source.get("best_streak",0)))
			stats["name"] = username
			rows.append(stats)
		elif data.profiles[username].has(mode_key):
			var stats: Dictionary = data.profiles[username][mode_key].duplicate()
			stats["name"] = username
			rows.append(stats)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.points != b.points: return a.points > b.points
		var rate_a := float(a.wins) / maxi(1, int(a.games))
		var rate_b := float(b.wins) / maxi(1, int(b.games))
		if not is_equal_approx(rate_a, rate_b): return rate_a > rate_b
		if a.wins != b.wins: return a.wins > b.wins
		return str(a.name) < str(b.name))
	return rows

func _ensure_user(username: String) -> String:
	username = clean_name(username)
	var key := username.to_lower()
	if not data.users.has(key):
		data.users[key] = {"id": "%d-%d" % [int(Time.get_unix_time_from_system() * 1000), randi()], "name": username}
	return str(data.users[key].name)

func register_user(username: String) -> Dictionary:
	username = username.strip_edges()
	if username.length() < 2 or username.length() > 16 or username != clean_name(username) or username.to_lower().begins_with("ai"):
		return {"ok": false, "error": "用户名需为 2～16 字，不能含控制字符或以 AI 开头。"}
	if data.users.has(username.to_lower()):
		return {"ok": false, "error": "该用户名已注册，请切换到已有用户。"}
	if data.users.size() >= 3:
		return {"ok": false, "error": "最多注册 3 个账户，请先删除一个已有账户。"}
	_ensure_user(username)
	save()
	return {"ok": true, "name": username}

func users() -> Array[String]:
	var result: Array[String] = []
	for user in data.users.values(): result.append(str(user.name))
	result.sort()
	return result

func delete_history(uid: String) -> bool:
	for i in data.history.size():
		if str(data.history[i].uid) == uid:
			data.history.remove_at(i)
			save()
			return true
	return false

func clear_history() -> void:
	data.history.clear()
	save()

func clear_scores(mode_key: String, username: String = "") -> void:
	for user in data.profiles:
		if username.is_empty() or user == username:
			if mode_key == "*": data.profiles[user].clear()
			else: data.profiles[user].erase(mode_key)
	save()

func delete_user(username: String) -> bool:
	var key := username.to_lower()
	if not data.users.has(key) or data.users.size() <= 1: return false
	var canonical := str(data.users[key].name)
	data.users.erase(key)
	data.achievements.erase(key)
	data.profiles.erase(canonical)
	var fallback: String = users()[0]
	for setting in ["username", "opponent"]:
		if str(data.settings.get(setting, "")).is_empty() or str(data.settings.get(setting, "")).to_lower() == key: data.settings[setting] = fallback
	return save()

func avatar_for(username: String) -> int:
	var value := clampi(int(data.users.get(username.to_lower(),{}).get("avatar",0)),0,12)
	return value if avatar_unlocked(username,value) else 0

func set_avatar(username: String, value: int) -> bool:
	var key := username.to_lower()
	if not data.users.has(key) or not avatar_unlocked(username,value): return false
	data.users[key]["avatar"] = value
	save()
	return true

func frame_unlocked(username: String, value: int) -> bool:
	if value not in HUMAN_FRAMES: return false
	return value == 0 or data.achievements.get(username.to_lower(),{}).has(FRAME_REQUIREMENTS[value])
func frame_for(username: String) -> int:
	var value := clampi(int(data.users.get(username.to_lower(),{}).get("frame",0)),0,17)
	return value if frame_unlocked(username,value) else 0
func set_frame(username: String, value: int) -> bool:
	var key := username.to_lower()
	if not data.users.has(key) or not frame_unlocked(username,value): return false
	data.users[key]["frame"] = value
	save()
	return true

func avatar_unlocked(username: String, value: int) -> bool:
	if value < 0 or value >= AVATAR_REQUIREMENTS.size(): return false
	return value < 8 or data.achievements.get(username.to_lower(),{}).has(AVATAR_REQUIREMENTS[value])
