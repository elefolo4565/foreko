# foreko_smartball（スマートボール 開発用プロジェクト）

本体「フォレコの昭和商店街」（D:\gameProject\foreko_world）に組み込むスマートボールを単体で開発するためのプロジェクト。
Godot Engine 4.7.2 / GDScript。起動するとすぐスマートボール台が始まる（shared/dev/minigame_launcher.tscn）。

## 構成
- minigames/smartball/ - スマートボールの実体（本体の minigames\smartball からジャンクションで参照されている）
  - smartball.tscn（入口）, smart_ball_3d.gd（SmartBall3D）, smart_ball_editor.gd（調整モード F2）, board_layout.json（台の設計）
- shared/ - **ジャンクション** → D:\gameProject\foreko_world\shared（GameManager・Sound・BallTable 等の共有部品。本体が実体）
- project.godot の `[foreko] minigame_scene` で起動するミニゲームを指定

## 約束事
- ルートノードは `signal exit_requested()` を持つ（開発用では emit すると台を作り直す）
- 本体に頼るのは GameManager と Sound（shared/autoload）だけ
- 調整モードで保存すると board_layout.json（台の設計）に書かれ、本体にもそのまま反映される
- 入力マップ・物理 tick（120）・画面サイズは本体の project.godot と揃える
- shared/ を変更すると本体とパチンコ開発用にも影響する
