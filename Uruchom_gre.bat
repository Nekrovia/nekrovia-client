@echo off
setlocal EnableDelayedExpansion

set GODOT_PATH_FILE=%~dp0godot_path.txt

if exist "%GODOT_PATH_FILE%" (
    set /p GODOT_EXE=<"%GODOT_PATH_FILE%"
)

if not defined GODOT_EXE goto ask
if exist "!GODOT_EXE!" goto found
echo Zapisana sciezka nie dziala: !GODOT_EXE!
echo.

:ask
echo Podaj pelna sciezke do pliku Godot_v4.7.2-stable_win64.exe
echo ^(np. D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe^)
set /p GODOT_EXE="Sciezka: "

if not exist "!GODOT_EXE!" (
    echo.
    echo Nie znaleziono pliku: !GODOT_EXE!
    echo Sprawdz sciezke i sprobuj ponownie.
    pause
    exit /b 1
)

:found
echo !GODOT_EXE!>"%GODOT_PATH_FILE%"

if not exist "%~dp0.godot\global_script_class_cache.cfg" (
    echo Pierwsze uruchomienie na tym komputerze - importuje projekt, to potrwa chwile...
    "!GODOT_EXE!" --headless --editor --quit --path "%~dp0."
)

"!GODOT_EXE!" --path "%~dp0."
