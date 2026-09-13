@echo off
setlocal

set GODOT_PATH_FILE=%~dp0godot_path.txt

if exist "%GODOT_PATH_FILE%" (
    set /p GODOT_EXE=<"%GODOT_PATH_FILE%"
) else (
    echo Pierwsze uruchomienie - podaj pelna sciezke do pliku Godot_v4.7.2-stable_win64.exe
    echo ^(np. D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe^)
    set /p GODOT_EXE="Sciezka: "
    echo %GODOT_EXE%>"%GODOT_PATH_FILE%"
)

if not exist "%GODOT_EXE%" (
    echo.
    echo Nie znaleziono pliku: %GODOT_EXE%
    echo Sprawdz sciezke i sprobuj ponownie.
    del "%GODOT_PATH_FILE%" >nul 2>&1
    pause
    exit /b 1
)

"%GODOT_EXE%" --path "%~dp0."
