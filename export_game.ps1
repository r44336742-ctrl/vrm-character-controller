$ErrorActionPreference = "Stop"
$appData = $env:APPDATA
$templateDir = "$appData\Godot\export_templates\4.3.stable"
if (-not (Test-Path $templateDir)) {
    New-Item -ItemType Directory -Force -Path $templateDir | Out-Null
}

Write-Host "Downloading Godot 4.3 Export Templates..."
Invoke-WebRequest -Uri "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz" -OutFile "templates.zip"
Write-Host "Extracting Templates..."
Expand-Archive -Path "templates.zip" -DestinationPath "extracted_templates" -Force
Move-Item -Path "extracted_templates\templates\*" -Destination $templateDir -Force

Write-Host "Exporting Game..."
$godot = (Get-ChildItem -Filter Godot_v*-stable_win64_console.exe).FullName
& $godot --headless --path . --export-release "Windows Desktop" build/jeu.exe
Write-Host "Done!"
