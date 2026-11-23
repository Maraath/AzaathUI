# Cria uma tarefa agendada no Windows para atualizar os dados do AzaathUI automaticamente
# todo dia às 04:00 (ou assim que o PC ligar, se estava desligado nesse horário).

$TaskName = "AzaathUI_AutoUpdateData"
$BatPath  = "D:\ProjectAzaath\tools\Atualizar-Azaath.bat"

$Action    = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$BatPath`"" -WorkingDirectory "D:\ProjectAzaath"
$Trigger   = New-ScheduledTaskTrigger -Daily -At 04:00AM
$Settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description "Atualiza automaticamente QuestDB e mapas do AzaathUI." -Force | Out-Null

Write-Host "Tarefa agendada '$TaskName' criada com sucesso! O Azaath sera atualizado automaticamente todos os dias." -ForegroundColor Green
