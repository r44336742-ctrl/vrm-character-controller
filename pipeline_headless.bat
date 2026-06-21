@echo off
set GODOT_BIN=godot4
:: Si "godot4" n'est pas reconnu par Windows, remplacez la ligne ci-dessus par le
:: chemin complet vers l'executable (idealement la version "console") :
:: set GODOT_BIN="C:\Godot\Godot_v4.6.3-stable_win64_console.exe"

:: Téléchargement headless des Export Templates (à adapter à la version exacte installée) :
:: curl -L -o templates.tpz https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz
:: powershell -Command "Expand-Archive -Path templates.tpz -DestinationPath %APPDATA%\Godot\export_templates\4.6.3.stable -Force"

echo --- IMPORT DES ASSETS ---
%GODOT_BIN% --headless --path . --import

echo --- VALIDATION DES SCENES ---
%GODOT_BIN% --headless --path . res://scenes/main.tscn --quit-after 5

echo --- EXPORT WINDOWS BUILD ---
if not exist build mkdir build
%GODOT_BIN% --headless --path . --export-release "Windows Desktop" build/jeu.exe

echo --- TERMINE ---
