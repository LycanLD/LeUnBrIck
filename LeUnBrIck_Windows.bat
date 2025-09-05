@echo off
REM ---- Check for Python ----
python --version >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo Python is not installed or not in PATH.
    pause
    exit /b
)

REM ---- Upgrade pip first (optional but recommended) ----
python -m pip install --upgrade pip

REM ---- Install requests ----
python -m pip install requests

REM ---- Run main.py ----
python main.py
