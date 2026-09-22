@echo off
title Tamkeen AI Unified Backend
echo ========================================================
echo   Tamkeen AI Unified Backend (FastAPI + 3 AI Models)
echo ========================================================
echo Starting server on http://0.0.0.0:8000 ...
cd /d "%~dp0"
"C:\Users\NITRO\AppData\Local\Programs\Python\Python312\python.exe" -m uvicorn server:app --host 0.0.0.0 --port 8000 --reload
pause
