# フォレコの昭和商店街

Godot Engine 4.7.2 で開発する、昭和の商店街を foreko で歩き、スマートボール・パチンコで遊ぶゲーム。
このプロジェクトが**本体（メイン）**。ミニゲームは別プロジェクトで開発し、ジャンクションで取り込んでいる。

## 技術スタック
- Godot Engine 4.7.2（D:\godot\Godot_v4.7.2-stable_win64.exe）/ GDScript / Forward+

## リポジトリ構成（GitHub: elefolo4565/foreko、ローカル: D:/gameProject/foreko）
```
foreko/
├─ foreko_world\          本体（このプロジェクト）
│   ├─ shared\            → ジャンクション: foreko\shared
│   └─ minigames\{smartball,pachinko}\ → ジャンクション: foreko\minigames\...
├─ foreko_smartball\      スマートボール開発用（shared・minigames\smartball をジャンクションで参照）
├─ foreko_pachinko\       パチンコ開発用（shared・minigames\pachinko をジャンクションで参照）
├─ shared\  minigames\    実体（git 管理）
├─ tools\setup_links.ps1  clone 後にジャンクションを作る
└─ .github\workflows\deploy-web.yml  main に push → Web 書き出し → GitHub Pages
```
- ジャンクションは .gitignore 済み。Actions ではコピーして組み込む
- Web 版: https://elefolo4565.github.io/foreko/ （Compatibility 描画・スレッド無し・同梱フォント）
- 分割前のバックアップ: D:/gameProject/foreko_world_backup_20260929

## ディレクトリ構成（本体）
- scenes/main.tscn - ルートのみ。全て scripts/main.gd がコードで生成
- scripts/main.gd - 町とミニゲームの切り替え。`MINIGAMES` 辞書（店 ID → 入口シーン）でミニゲームを読み込む
- scripts/world/ - town.gd（3D商店街）, player.gd（foreko 操作）, auto_rig.gd（リグ修復）
- shared/autoload/ - GameManager（所持金・貯玉・景品・フォント・セーブ）, Sound（BGM・効果音の実行時合成）
- shared/ - ball_table.gd（持ち玉・玉貸し・景品交換 UI の基底 BallTable）, ball.gd（TableBall）, builder.gd（WorldBuilder）
- shared/sounds/gunkan_march.ogg（PD: Wikimedia Commons, 1941年 海軍軍楽隊）
- shared/dev/minigame_launcher.tscn - 開発用プロジェクトの起動シーン（本体では使わない）
- assets/models/foreko.glb

## ミニゲームの約束事（新しいミニゲームを追加するとき）
- 入口は `res://minigames/<id>/<id>.tscn`。ルートノードは `signal exit_requested()` を持ち、遊び終わったら emit する
- 本体に頼るのは Autoload の GameManager（money / add_money / get_stored_balls / set_stored_balls / add_prize / toast_requested）と Sound だけ
- 持ち玉 UI は shared の BallTable を継承（パチンコ）するか、子として持つ（スマートボールの SmartHud）
- 追加手順: 開発用プロジェクトを作る（foreko_smartball の project.godot をコピーし name と [foreko] minigame_scene を変更、
  shared\ をジャンクション）→ 本体の minigames\<id> にジャンクション → main.gd の MINIGAMES と town.gd の店に追加
- 入力マップ・物理 tick（120）・画面サイズは project.godot 側の設定なので、3 プロジェクトで手で揃える
- class_name は 3 プロジェクト共通の名前空間になるので重複させない

## 注意事項
- **foreko.glb（Tripo 製）のリグは壊れている**：骨格がメッシュに対し Y 軸 90° ずれ、全頂点ウェイトが Hips 100%。
  AutoRig.rebuild() で骨位置を合わせ直し、骨からの距離でウェイトを再計算している。モデルを差し替えたら要確認
- 和文フォント: デスクトップは SystemFont（HG行書体等）優先＋同梱 M PLUS Rounded 1c にフォールバック。Web は同梱フォントのみ
  （`-- --bundled-fonts` と `--rendering-method gl_compatibility` でデスクトップでも Web 相当を確認できる）
- スマートボールの台の配置: 開発用プロジェクトの調整モード（F2）で保存すると res://minigames/smartball/board_layout.json（台の設計）に書かれ、
  本体にも反映される。本体で保存すると user://smartball_layout.json（プレイヤーの配置、設計より優先）
- Web 版の UI 文字は project.godot の gui/theme/custom_font（同梱 Bold）で日本語化している。root.theme の default_font だけでは Web で □ に化けた
- Web 書き出しプリセット（export_presets.cfg）は include_filter に *.json を入れて board_layout.json を含めている
- 開発用の --shot 実行中は GameManager.save_enabled=false で本物のセーブを書かない
- ルートの foreko.glb は元データ（インポート対象外にしたい場合は .import を skip に）

## 開発用コマンド（main.gd の _debug_capture）
- 撮影: `Godot --path . -- --shot=<town|char|charside|smartball|smartball_edit|pachinko> --out=<png> --wait=<秒>`
- 出玉率: `Godot --headless --path . -- --shot=sim_pachinko:<強さ0-1> --wait=200` / `--shot=sim_smartball --wait=300`
  （4倍速だが物理 tick を 480 にして実機と同じ 1/120 秒ステップで計算する）

## Godot ナレッジベース参照
- ~/.claude/gamedev/godot/ （gdscript-pitfalls.md ほか）
