# foreko_pachinko（パチンコ 開発用プロジェクト）

本体「フォレコの昭和商店街」（D:\gameProject\foreko_world）に組み込むパチンコを単体で開発するためのプロジェクト。
Godot Engine 4.7.2 / GDScript。起動するとすぐパチンコ台が始まる（shared/dev/minigame_launcher.tscn）。

## 構成
- minigames/pachinko/ - パチンコの実体（本体の minigames\pachinko からジャンクションで参照されている）
  - pachinko.tscn（入口）, pachinko.gd（BallTable を継承した 2D 台）
- shared/ - **ジャンクション** → D:\gameProject\foreko_world\shared（GameManager・Sound・BallTable 等の共有部品。本体が実体）
- project.godot の `[foreko] minigame_scene` で起動するミニゲームを指定

## 約束事
- ルートノードは `signal exit_requested()` を持つ（開発用では emit すると台を作り直す）
- 本体に頼るのは GameManager と Sound（shared/autoload）だけ
- 入力マップ・物理 tick（120）・画面サイズは本体の project.godot と揃える
- shared/ を変更すると本体とスマートボール開発用にも影響する
- 出玉率の計測は本体の `--shot=sim_pachinko:<強さ>` を使う（本体 CLAUDE.md 参照）。狙い目 0.35〜0.55 で約105%
