# 第一个窗口：运行 opencode.ps1，最小化，不等待
Start-Process powershell -ArgumentList "-NoExit -ExecutionPolicy Bypass -WindowStyle Minimized -Command `"& '$env:APPDATA\npm\opencode.ps1'`""

# 延迟 15 秒
Start-Sleep -Seconds 15

# 第二个窗口：运行 cc-connect.ps1，最小化
Start-Process powershell -ArgumentList "-NoExit -ExecutionPolicy Bypass -WindowStyle Minimized -Command `"& '$env:APPDATA\npm\cc-connect.ps1'`""