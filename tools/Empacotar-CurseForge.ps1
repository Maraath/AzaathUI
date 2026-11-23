# Gera o .zip para envio manual ao CurseForge: dist\AzaathUI-<versao>.zip
# Dentro do zip ficam as 3 pastas de addon na raiz (AzaathUI/, AzaathUI_Nav_EK/, AzaathUI_Nav_Kalimdor/).
# Usa barras "/" nos caminhos (o Compress-Archive do PowerShell 5.1 grava "\" e quebra a instalacao).
# Uso: powershell -File tools\Empacotar-CurseForge.ps1
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

$Src = Split-Path $PSScriptRoot -Parent
$Addons = "AzaathUI", "AzaathUI_Nav_EK", "AzaathUI_Nav_Kalimdor"
# Nada de arquivo de desenvolvimento dentro do pacote
$Skip = '(^|[\\/])(\.git|\.github|\.vscode|\.claude)([\\/]|$)|\.(psd|bak|orig|tmp|log|webp)$|(^|[\\/])(CLAUDE|AGENTS)\.md$|Thumbs\.db$|desktop\.ini$'

$toc = Get-Content (Join-Path $Src "AzaathUI\AzaathUI.toc") -Encoding UTF8
$ver = ($toc | Where-Object { $_ -match '^## Version:\s*(.+)$' } | Select-Object -First 1) -replace '^## Version:\s*', ''
if (-not $ver) { Write-Host "Sem '## Version:' no AzaathUI.toc" -ForegroundColor Red; exit 1 }

$dist = Join-Path $Src "dist"
New-Item -ItemType Directory -Force $dist | Out-Null
$zipPath = Join-Path $dist "AzaathUI-$($ver.Trim()).zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

$zip = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')
$n = 0; $skipped = @()
try {
    foreach ($a in $Addons) {
        $root = Join-Path $Src $a
        Get-ChildItem $root -Recurse -File -Force | ForEach-Object {
            $rel = $a + "/" + $_.FullName.Substring($root.Length + 1).Replace('\', '/')
            if ($rel -match $Skip) { $skipped += $rel; return }
            [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $rel, 'Optimal')
            $n++
        }
    }
} finally { $zip.Dispose() }

$mb = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
Write-Host "Pacote: $zipPath ($n arquivos, $mb MB)" -ForegroundColor Green
if ($skipped) { Write-Host "Ignorados: $($skipped -join ', ')" -ForegroundColor Yellow }
