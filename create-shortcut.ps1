$TargetFile = "C:\Users\user\Documents\PALETSAY\pi-manager\start.bat"
$ShortcutPath = "$env:USERPROFILE\Desktop\Palet Sayim Manager.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = $TargetFile
$Shortcut.WorkingDirectory = "C:\Users\user\Documents\PALETSAY\pi-manager"
$Shortcut.IconLocation = "shell32.dll,3"
$Shortcut.Save()
Write-Host "Shortcut created at $ShortcutPath"
