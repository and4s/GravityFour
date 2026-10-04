extends Node

const VERSION := "3.9.0"
signal changed
var info: Dictionary = {}
var status := "填写 GitHub 仓库后可检查更新。"
var release_url := ""
var busy := false
var request: HTTPRequest

func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/app_info.json"))
	if parsed is Dictionary: info = parsed
	request = HTTPRequest.new()
	request.timeout = 12
	request.body_size_limit = 1048576
	add_child(request)
	request.request_completed.connect(_completed)

static func repository(value: String) -> String:
	value = value.strip_edges().trim_prefix("https://github.com/").trim_suffix("/")
	var pattern := RegEx.new()
	pattern.compile("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
	return value if pattern.search(value) != null and not ".." in value else ""

static func newer(tag: String, current: String = VERSION) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^v?([0-9]+)\\.([0-9]+)\\.([0-9]+)$")
	var remote := pattern.search(tag)
	var local := pattern.search(current)
	if remote == null or local == null: return false
	for i in range(1, 4):
		var a := int(remote.get_string(i))
		var b := int(local.get_string(i))
		if a != b: return a > b
	return false

func check(repo: String) -> void:
	if busy: return
	release_url = ""
	repo = repository(repo)
	if repo.is_empty():
		status = "请填写有效仓库：用户名/仓库名，或 GitHub 仓库链接。"
		changed.emit()
		return
	busy = true
	status = "正在检查 GitHub 最新正式版本…"
	changed.emit()
	var error := request.request("https://api.github.com/repos/%s/releases/latest" % repo, ["Accept: application/vnd.github+json", "X-GitHub-Api-Version: 2026-03-10", "User-Agent: GravityFour/" + VERSION])
	if error != OK:
		busy = false
		status = "无法启动更新检查：" + error_string(error)
		changed.emit()

func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		status = "检查失败，请检查网络连接后重试。"
	elif code == 404:
		status = "仓库不存在、非公开，或尚未发布正式 Release。"
	elif code in [403, 429]:
		status = "GitHub 请求频率受限，请稍后再试。"
	elif code != 200:
		status = "更新服务器返回错误：HTTP %d。" % code
	else:
		var data: Variant = JSON.parse_string(body.get_string_from_utf8())
		if not data is Dictionary or not data.get("tag_name") is String:
			status = "更新信息格式无效。"
		else:
			var tag := str(data.tag_name)
			var pattern := RegEx.new()
			pattern.compile("^v?[0-9]+\\.[0-9]+\\.[0-9]+$")
			if pattern.search(tag) == null:
				status = "Release 标签需为 v数字.数字.数字，例如 v3.9.1。"
			elif newer(tag):
				var url := str(data.get("html_url", ""))
				if url.begins_with("https://github.com/"):
					release_url = url
					status = "发现新版本 %s，当前版本 %s。" % [tag, VERSION]
				else: status = "更新页面地址无效。"
			else: status = "当前版本 %s 已是最新版本。" % VERSION
	changed.emit()
