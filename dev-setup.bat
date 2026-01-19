@echo off
REM Unified Development Script for OpenPoC (Windows Batch)
REM Usage: dev-setup.bat [command]

setlocal enabledelayedexpansion

set "Command=%1"
if "!Command!"=="" set "Command=help"

goto !Command!

:help
cls
echo.
echo ╔════════════════════════════════════════════════════════╗
echo ║   OpenPoC Unified Development Commands                 ║
echo ╚════════════════════════════════════════════════════════╝
echo.
echo Setup Commands:
echo   dev-setup.bat install         - Install all dependencies
echo   dev-setup.bat clean           - Clean all artifacts
echo.
echo Development Commands:
echo   dev-setup.bat dev             - Start backend and frontend
echo   dev-setup.bat dev-backend     - Start only backend
echo   dev-setup.bat dev-frontend    - Start only frontend
echo.
echo Build Commands:
echo   dev-setup.bat build           - Build both projects
echo   dev-setup.bat build-backend   - Build only backend
echo   dev-setup.bat build-frontend  - Build only frontend
echo.
echo Docker Commands:
echo   dev-setup.bat docker-up       - Start all containers
echo   dev-setup.bat docker-down     - Stop all containers
echo.
goto end

:install
echo.
echo 📦 Installing all dependencies...
echo.
echo   [1/3] Root dependencies...
call npm install
echo.
echo   [2/3] Backend dependencies...
cd openpoc-backend
call npm install
cd ..
echo.
echo   [3/3] Frontend dependencies...
cd openpoc-frontend\v0-open-po-c-dashboard-design-2
call npm install
cd ..\..\..
echo.
echo ✅ All dependencies installed!
goto end

:dev
echo.
echo 🚀 Starting OpenPoC (Backend + Frontend)...
echo.
echo   Backend:  http://localhost:4041
echo   Frontend: http://localhost:3000
echo   API Docs: http://localhost:4041/api/docs
echo.
echo   Press Ctrl+C to stop both servers
echo.
call npm run dev
goto end

:dev-backend
echo.
echo 🔵 Starting Backend only...
echo    http://localhost:4041
cd openpoc-backend
call npm run dev
cd ..
goto end

:dev-frontend
echo.
echo 🟢 Starting Frontend only...
echo    http://localhost:3000
cd openpoc-frontend\v0-open-po-c-dashboard-design-2
call npm run dev
cd ..\..\..
goto end

:build
echo.
echo 🔨 Building all projects...
echo.
echo   Building Backend...
cd openpoc-backend
call npm run build
cd ..
echo.
echo   Building Frontend...
cd openpoc-frontend\v0-open-po-c-dashboard-design-2
call npm run build
cd ..\..\..
echo.
echo ✅ Build completed!
goto end

:build-backend
echo.
echo 🔨 Building Backend...
cd openpoc-backend
call npm run build
cd ..
goto end

:build-frontend
echo.
echo 🔨 Building Frontend...
cd openpoc-frontend\v0-open-po-c-dashboard-design-2
call npm run build
cd ..\..\..
goto end

:clean
echo.
echo 🧹 Cleaning all artifacts...
echo.
if exist node_modules (
    echo   Removing root node_modules...
    rmdir /s /q node_modules
)
if exist openpoc-backend\node_modules (
    echo   Removing backend node_modules...
    rmdir /s /q openpoc-backend\node_modules
)
if exist openpoc-frontend\v0-open-po-c-dashboard-design-2\node_modules (
    echo   Removing frontend node_modules...
    rmdir /s /q openpoc-frontend\v0-open-po-c-dashboard-design-2\node_modules
)
if exist openpoc-backend\dist (
    echo   Removing backend dist...
    rmdir /s /q openpoc-backend\dist
)
if exist openpoc-frontend\v0-open-po-c-dashboard-design-2\.next (
    echo   Removing frontend .next...
    rmdir /s /q openpoc-frontend\v0-open-po-c-dashboard-design-2\.next
)
echo.
echo ✅ Clean completed!
goto end

:docker-up
echo.
echo 🐳 Starting Docker containers...
docker-compose up
goto end

:docker-down
echo.
echo 🛑 Stopping Docker containers...
docker-compose down
goto end

:end
endlocal
