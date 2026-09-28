extends Node
## ゲーム全体の状態（所持金・持ち玉・景品）とフォントを管理する。

signal money_changed(amount: int)
signal prizes_changed()
signal toast_requested(text: String)

const SAVE_PATH: String = "user://save.json"
const START_MONEY: int = 1000
const ALLOWANCE: int = 500

## 景品交換の品目（昭和の景品らしいもの）
const PRIZES: Array = [
	{"id": "caramel", "label": "キャラメル", "cost": 10},
	{"id": "ramune", "label": "ラムネ", "cost": 20},
	{"id": "menko", "label": "めんこ", "cost": 30},
	{"id": "choco", "label": "板チョコ", "cost": 50},
	{"id": "kanzume", "label": "みかんの缶詰", "cost": 100},
	{"id": "robot", "label": "ブリキのロボット", "cost": 300},
]

var money: int = START_MONEY
## 各店の貯玉 {"smartball": int, "pachinko": int}
var stored_balls: Dictionary = {"smartball": 0, "pachinko": 0}
## 景品の所持数 {id: count}
var prizes: Dictionary = {}
## 町に戻ったときの出現場所（店の id）
var return_shop: String = ""

## 開発用の自動撮影・シミュレーション中は本物のセーブを書き換えない
var save_enabled: bool = true

var font_ui: Font
var font_sign: Font
var font_pop: Font
var font_mincho: Font


func _ready() -> void:
	font_ui = _make_font(["BIZ UDGothic", "Yu Gothic UI", "Yu Gothic", "Meiryo"], 700, "Bold")
	font_sign = _make_font(["HGGyoshotai", "HG行書体", "HGSeikaishotaiPRO", "Yu Mincho", "MS Mincho"], 400, "Bold")
	font_pop = _make_font(["HGSoeiKakupoptai", "HG創英角ﾎﾟｯﾌﾟ体", "HG創英角ポップ体", "BIZ UDGothic", "Yu Gothic"], 700, "Black")
	font_mincho = _make_font(["HGMinchoE", "HG明朝E", "Yu Mincho", "MS Mincho"], 700, "Bold")
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			save_enabled = false
	load_game()


## Web ではシステムフォントが使えないので同梱の M PLUS Rounded 1c（OFL）を使う。
## デスクトップでは HG 系などのシステムフォントを優先し、無ければ同梱フォントにフォールバックする
func _make_font(names: Array, weight: int, bundled_weight: String) -> Font:
	var bundled: FontFile = load("res://shared/fonts/MPLUSRounded1c-%s.ttf" % bundled_weight)
	# 開発用：`-- --bundled-fonts` で Web と同じ同梱フォントを確認できる
	if OS.has_feature("web") or OS.get_cmdline_user_args().has("--bundled-fonts"):
		return bundled
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.fallbacks = [bundled]
	return f


func add_money(amount: int) -> void:
	money = maxi(0, money + amount)
	money_changed.emit(money)
	save_game()


func can_pay(amount: int) -> bool:
	return money >= amount


func add_prize(prize_id: String, count: int = 1) -> void:
	prizes[prize_id] = int(prizes.get(prize_id, 0)) + count
	prizes_changed.emit()
	save_game()


func get_prize_label(prize_id: String) -> String:
	for p: Dictionary in PRIZES:
		if p.get("id", "") == prize_id:
			return String(p.get("label", prize_id))
	return prize_id


func set_stored_balls(shop_id: String, count: int) -> void:
	stored_balls[shop_id] = maxi(0, count)
	save_game()


func get_stored_balls(shop_id: String) -> int:
	return int(stored_balls.get(shop_id, 0))


## お金も玉も尽きたら、おこづかいがもらえる
func check_allowance() -> void:
	var total_balls: int = 0
	for k: String in stored_balls.keys():
		total_balls += int(stored_balls[k])
	if money < 100 and total_balls <= 0:
		add_money(ALLOWANCE)
		toast_requested.emit("母ちゃんから おこづかい %d円 もらった！" % ALLOWANCE)


func to_dict() -> Dictionary:
	return {"money": money, "stored_balls": stored_balls, "prizes": prizes}


func from_dict(data: Dictionary) -> void:
	money = int(data.get("money", START_MONEY))
	var sb: Dictionary = data.get("stored_balls", {})
	for k: String in stored_balls.keys():
		stored_balls[k] = int(sb.get(k, 0))
	prizes = {}
	var pr: Dictionary = data.get("prizes", {})
	for k: Variant in pr.keys():
		prizes[String(k)] = int(pr[k])


func save_game() -> void:
	if not save_enabled:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		from_dict(parsed)
