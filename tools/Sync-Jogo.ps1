# Espelha os addons do projeto na pasta do jogo (apaga la o que nao existe mais aqui)
# e confere o conteudo por hash. Uso: powershell -File tools\Sync-Jogo.ps1 [-DryRun]
param([switch]$DryRun)

$Src = Split-Path $PSScriptRoot -Parent
$Dst = "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns"
$Addons = "AzaathUI", "AzaathUI_Nav_EK", "AzaathUI_Nav_Kalimdor"
$failed = $false

foreach ($a in $Addons) {
    $from = Join-Path $Src $a; $to = Join-Path $Dst $a
    $opts = @("/MIR", "/R:1", "/W:1", "/NJH", "/NJS", "/NDL", "/NP", "/NFL")
    if ($DryRun) { $opts += "/L" }
    robocopy $from $to @opts | Out-Null
    if ($LASTEXITCODE -ge 8) { Write-Host "[$a] ERRO no robocopy (codigo $LASTEXITCODE)" -ForegroundColor Red; $failed = $true; continue }
    if ($DryRun) { Write-Host "[$a] simulacao concluida"; continue }

    # robocopy compara data+tamanho; aqui garantimos que o conteudo e identico
    $fixed = 0
    Get-ChildItem $from -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($from.Length + 1); $other = Join-Path $to $rel
        $same = (Test-Path -LiteralPath $other) -and (Get-Item -LiteralPath $other).Length -eq $_.Length
        if ($same -and $_.Extension -match '^\.(lua|xml|toc|ttf)$') {
            $same = (Get-FileHash -LiteralPath $_.FullName -Algorithm MD5).Hash -eq (Get-FileHash -LiteralPath $other -Algorithm MD5).Hash
        }
        if (-not $same) { Copy-Item -LiteralPath $_.FullName -Destination $other -Force; $fixed++ }
    }
    $n = (Get-ChildItem $from -Recurse -File).Count; $m = (Get-ChildItem $to -Recurse -File).Count
    $color = if ($n -eq $m) { "Green" } else { "Red" }
    Write-Host "[$a] $n arquivos no projeto, $m no jogo, $fixed corrigidos por hash" -ForegroundColor $color
    if ($n -ne $m) { $failed = $true }
}
if ($failed) { exit 1 }
