@echo off
set "PATH=%LOCALAPPDATA%\Programs\MinGit\cmd;%PATH%"
cd /d "D:\gAmeros\Chess in time"
echo ========================================================
echo  Chess in Time - Subiendo nueva pantalla a GitHub
echo ========================================================
echo.
git push origin main
echo.
echo Si ya se subio, GitHub Actions esta compilando el APK.
echo Podes cerrar esta ventana.
pause
