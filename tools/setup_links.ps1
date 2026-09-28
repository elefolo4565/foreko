# clone 後に一度実行する（Windows / PowerShell）。
# 共有部品（shared）とミニゲーム（minigames）の実体はリポジトリ直下にあり、
# 各 Godot プロジェクトからはジャンクションで参照する。ジャンクションは git 管理外。
#   pwsh -File tools/setup_links.ps1

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot

# プロジェクト → 張るリンク（プロジェクト内のパス = リポジトリ直下のパス）
$links = @{
	"foreko_world"     = @("shared", "minigames\smartball", "minigames\pachinko")
	"foreko_smartball" = @("shared", "minigames\smartball")
	"foreko_pachinko"  = @("shared", "minigames\pachinko")
}

foreach ($project in $links.Keys) {
	foreach ($rel in $links[$project]) {
		$link = Join-Path $repo "$project\$rel"
		$target = Join-Path $repo $rel
		if (Test-Path $link) {
			$item = Get-Item $link -Force
			if ($item.LinkType -eq "Junction") {
				Write-Host "ok     $project\$rel"
				continue
			}
			throw "$link はジャンクションではない実フォルダです。中身を確認してから手動で整理してください"
		}
		New-Item -ItemType Directory -Force (Split-Path -Parent $link) | Out-Null
		New-Item -ItemType Junction -Path $link -Target $target | Out-Null
		Write-Host "linked $project\$rel -> $rel"
	}
}
