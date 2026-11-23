# Migração única NewWorldUI -> AzaathUI na pasta do jogo (rodar com o jogo FECHADO).
# - Renomeia os SavedVariables (NewWorldUI.lua -> AzaathUI.lua) e troca os nomes dentro deles
# - Atualiza AddOns.txt (addons ligados por personagem) e bindings-cache.wtf (NWUI_* -> AZAATH_*)
# - Tira as pastas antigas de Interface\AddOns e sincroniza as novas (Sync-Jogo.ps1)
# - Recria a tarefa agendada de atualização com o nome novo
# Tudo que é alterado vai antes para tools\.cache\migracao-azaath-<data>\
# Uso: powershell -ExecutionPolicy Bypass -File tools\Migrar-Nome-Azaath.ps1
$ErrorActionPreference = "Stop"
$Game = "C:\Program Files (x86)\World of Warcraft\_forever_"
$WTF = Join-Path $Game "WTF"; $AddOns = Join-Path $Game "Interface\AddOns"
$Old = "NewWorld" + "UI"   # partido para a troca de nomes do projeto não reescrever esta linha

if (Get-Process -Name Wow, WowClassic -ErrorAction SilentlyContinue) {
    Write-Host "Feche o jogo antes (ele regrava os SavedVariables ao sair)." -ForegroundColor Red; exit 1
}
$Bk = Join-Path (Split-Path $PSScriptRoot -Parent) ("tools\.cache\migracao-azaath-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
New-Item -ItemType Directory -Force $Bk | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Backup($file) {
    $rel = $file.Substring($Game.Length + 1); $dst = Join-Path $Bk $rel
    New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null; Copy-Item -LiteralPath $file $dst -Force
}
function Convert-Text([string]$s) {
    $s = $s -creplace $Old, "AzaathUI" -creplace ("NW" + "UI_"), "AZAATH_"
    $s = [regex]::Replace($s, '"nw([A-Za-z_]*)"', '"az$1"')   # chaves/valores "nw", "nwclassic"...
    return $s
}

# 1) SavedVariables (conta e personagens), inclusive os .bak do jogo
$n = 0
Get-ChildItem $WTF -Recurse -File -Filter "$Old.lua*" | ForEach-Object {
    Backup $_.FullName
    $txt = [IO.File]::ReadAllText($_.FullName, $utf8)
    $new = Join-Path $_.DirectoryName ($_.Name -replace $Old, "AzaathUI")
    if (Test-Path -LiteralPath $new) { Backup $new }
    [IO.File]::WriteAllText($new, (Convert-Text $txt), $utf8)
    Remove-Item -LiteralPath $_.FullName; $n++
}
Write-Host "SavedVariables migrados: $n"

# 2) AddOns.txt e bindings-cache.wtf
Get-ChildItem $WTF -Recurse -File | Where-Object { $_.Name -in "AddOns.txt", "bindings-cache.wtf" } | ForEach-Object {
    $txt = [IO.File]::ReadAllText($_.FullName, $utf8); $new = Convert-Text $txt
    if ($new -cne $txt) { Backup $_.FullName; [IO.File]::WriteAllText($_.FullName, $new, $utf8); Write-Host "Atualizado: $($_.FullName.Substring($WTF.Length + 1))" }
}

# 3) Pastas antigas do addon -> backup (não apaga)
Get-ChildItem $AddOns -Directory | Where-Object { $_.Name -like "$Old*" } | ForEach-Object {
    Move-Item -LiteralPath $_.FullName (Join-Path $Bk $_.Name); Write-Host "Pasta antiga retirada: $($_.Name)"
}

# 4) Copia as pastas novas
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "Sync-Jogo.ps1")

# 5) Tarefa agendada com o nome antigo apontava para Atualizar-NWUI.bat (renomeado)
$task = Get-ScheduledTask -TaskName ($Old + "_AutoUpdateData") -ErrorAction SilentlyContinue
if ($task) {
    Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "Agendar-Atualizacao-Azaath.ps1")
}
Write-Host "Migração concluída. Backup em: $Bk" -ForegroundColor Green
