@echo off
setlocal EnableDelayedExpansion

set GODOT_PATH_FILE=%~dp0godot_path.txt
set LAST_IMPORT_FILE=%~dp0.last_import_commit.txt

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

set CURRENT_COMMIT=
for /f "delims=" %%i in ('git -C "%~dp0." rev-parse HEAD 2^>nul') do set CURRENT_COMMIT=%%i

set LAST_COMMIT=
if exist "%LAST_IMPORT_FILE%" set /p LAST_COMMIT=<"%LAST_IMPORT_FILE%"

if defined CURRENT_COMMIT if not "!CURRENT_COMMIT!"=="!LAST_COMMIT!" (
    echo Wykryto nowy kod od ostatniego importu - czyszcze cache Godota i importuje od nowa, to potrwa chwile...
    if exist "%~dp0.godot" rmdir /s /q "%~dp0.godot"
    "!GODOT_EXE!" --headless --editor --quit --path "%~dp0."
    echo !CURRENT_COMMIT!>"%LAST_IMPORT_FILE%"
)

"!GODOT_EXE!" --path "%~dp0."
