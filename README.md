# フォレコの昭和商店街

昭和の商店街を foreko で歩き、スマートボールやパチンコで遊ぶゲーム（Godot 4.7.2）。

- Web 版: https://elefolo4565.github.io/foreko/ （`main` に push すると GitHub Actions で自動ビルド・公開）

## 構成

```
foreko/
├─ foreko_world/        本体（町・foreko・ミニゲームの切り替え）
├─ foreko_smartball/    スマートボール開発用プロジェクト（起動するとすぐ台が始まる）
├─ foreko_pachinko/     パチンコ開発用プロジェクト
├─ shared/              共有部品（GameManager・Sound・持ち玉 UI・フォント・BGM）
├─ minigames/
│   ├─ smartball/       スマートボール本体
│   └─ pachinko/        パチンコ本体
├─ tools/setup_links.ps1
└─ .github/workflows/deploy-web.yml
```

`shared/` と `minigames/` の実体はリポジトリ直下にあり、各 Godot プロジェクトからは
ジャンクション（Windows）で参照します。**clone したら最初に一度**次を実行してください。

```powershell
pwsh -File tools/setup_links.ps1
```

GitHub Actions では、ジャンクションの代わりにコピーして `foreko_world` に組み込んでから Web 向けに書き出します。

## ライセンス・素材
- フォント: M PLUS Rounded 1c（SIL Open Font License 1.1, `shared/fonts/OFL.txt`）
- BGM: 軍艦行進曲（1941年 帝国海軍軍楽隊の録音、パブリックドメイン, Wikimedia Commons）
