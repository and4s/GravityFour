extends RefCounted
const ITEMS := [
	["first_game", "踏入棋局", "完成一场正式对局"],
	["first_win", "胜利初尝", "赢得一场正式对局"],
	["games10", "棋盘常客", "累计完成 10 场正式对局"],
	["games50", "百变棋路", "累计完成 50 场正式对局"],
	["wins10", "十胜达人", "累计赢得 10 场正式对局"],
	["streak3", "势如破竹", "同一模式取得 3 连胜"],
	["normal_win", "进阶挑战", "击败普通 AI"],
	["hard_win", "深度博弈", "击败困难 AI"],
	["master_win", "登峰造极", "击败大师 AI，解锁大师金冠"],
	["online_win", "隔空对弈", "赢得一场联机对局"],
	["space_win", "空间视野", "通过三个坐标轴同时变化的空间对角线获胜"],
	["fast_win", "速战速决", "在 9 手以内连成四子获胜"],
	["master_late", "破晓逆刃", "执后手，以四子连线击败困难 AI，解锁曜影龙"],
	["master_space", "天穹穿梭", "以空间对角线击败困难 AI，解锁天穹执政官"],
	["master_dual", "双星绝杀", "最后一手同时形成两个不同方向的四子连线，击败困难 AI"],
	["master_sweep", "不败棋圣", "在三局两胜 / 五局三胜中零封困难 AI，整场不用悔棋或提示"],
	["master_comeback", "逆冕归来", "五局三胜中先输两局，再连赢三局战胜困难 AI，不用悔棋或提示"],
	["master_fast", "十五手锋芒", "15 手内以四子连线击败困难 AI，不靠超时获胜"]
]
static func eligible(match_data: Dictionary, result: int, stats: Dictionary) -> Array[String]:
	if bool(match_data.get("assisted",false)): return []
	var ids: Array[String] = ["first_game"]
	if int(stats.get("games",0)) >= 10: ids.append("games10")
	if int(stats.get("games",0)) >= 50: ids.append("games50")
	if int(stats.get("wins",0)) >= 10: ids.append("wins10")
	if int(stats.get("best_streak",0)) >= 3: ids.append("streak3")
	if result != 1: return ids
	ids.append("first_win")
	var mode := str(match_data.mode)
	if mode.begins_with("ai_normal"): ids.append("normal_win")
	if mode.begins_with("ai_hard"): ids.append("hard_win")
	if mode.begins_with("ai_master"): ids.append("master_win")
	if mode.begins_with("online"): ids.append("online_win")
	if (mode.begins_with("ai_hard") or mode.begins_with("ai_master")) and not bool(match_data.get("assisted",false)):
		var line_win: bool = match_data.get("final_snapshot",{}).get("line",[]).size() >= 4
		if line_win and int(match_data.get("own_side",0)) in [1,2] and int(match_data.get("first_side",1)) != int(match_data.get("own_side",0)): ids.append("master_late")
		if line_win and int(match_data.get("winning_axes",0)) >= 2: ids.append("master_dual")
		if line_win and int(match_data.get("plies",125)) <= 15: ids.append("master_fast")
		var champion: bool = int(match_data.get("series_winner",0)) > 0 and int(match_data.get("series_winner",0)) == int(match_data.get("own_side",0))
		if champion and not bool(match_data.get("series_assisted",true)):
			var own: int = int(match_data.own_side)
			var scores: Array = match_data.get("series_scores",[0,0])
			if scores[2-own] == 0: ids.append("master_sweep")
			var results: Array = match_data.get("series_results",[])
			if int(match_data.get("series_target",0)) == 3 and results.size() >= 5:
				var decisive: Array = results.filter(func(value: int) -> bool: return value in [1,2])
				if decisive.size() == 5 and decisive[0] != own and decisive[1] != own and decisive[2] == own and decisive[3] == own and decisive[4] == own: ids.append("master_comeback")
	var line: Array = match_data.get("final_snapshot",{}).get("line",[])
	if line.size() >= 4:
		if int(match_data.get("plies",125)) <= 9: ids.append("fast_win")
		var a: Array = line[0]
		var b: Array = line[1]
		if a[0] != b[0] and a[1] != b[1] and a[2] != b[2]:
			ids.append("space_win")
			if mode.begins_with("ai_hard") or mode.begins_with("ai_master"): ids.append("master_space")
	return ids
