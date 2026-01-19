# Unified Development Script for OpenPoC
# Usage: .\dev-setup.ps1 [command]

param(
    [string]$Command = "help"
)

$BackendPath = "openpoc-backend"
$FrontendPath = "openpoc-frontend/v0-open-po-c-dashboard-design-2"

# Show help
if ($Command -eq "help") {
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║   OpenPoC Unified Development Commands                 ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Setup Commands:" -ForegroundColor Yellow
    Write-Host "  .\dev-setup.ps1 install         - Install all dependencies" -ForegroundColor Green
    Write-Host "  .\dev-setup.ps1 clean           - Clean all node_modules and artifacts" -ForegroundColor Green
    Write-Host ""
    Write-Host "Development Commands:" -ForegroundColor Yellow
    Write-Host "  .\dev-setup.ps1 dev             - Start backend and frontend together" -ForegroundColor Green
    Write-Host "  .\dev-setup.ps1 dev-backend     - Start only backend" -ForegroundColor Green
    Write-Host "  .\dev-setup.ps1 dev-frontend    - Start only frontend" -ForegroundColor Green
    Write-Host ""
    Write-Host "Build Commands:" -ForegroundColor Yellow
    Write-Host "  .\dev-setup.ps1 build           - Build both projects" -ForegroundColor Green
    Write-Host "  .\dev-setup.ps1 build-backend   - Build only backend" -ForegroundColor Green
    Write-Host "  .\dev-setup.ps1 build-frontend  - Build only frontend" -ForegroundColor Green
    Write-Host ""
    Write-Host "Testing and Linting:" -ForegroundColor Yellow
    Write-Host "  .\dev-setup.ps1 test            - Run all tests" -ForegroundColor Green
    Write-Host "  .\dev-setup.ps1 lint            - Run linters" -ForegroundColor Green
    Write-Host ""
    Write-Host "Docker Commands:" -ForegroundColor Yellow
    Write-Host "  .\dev-setup.ps1 docker-up       - Start all containers" -ForegroundColor Green
    Write-Host "  .\dev-setup.ps1 docker-down     - Stop all containers" -ForegroundColor Green
    Write-Host ""
    exit 0
}

# Install dependencies
if ($Command -eq "install") {
    Write-Host "`n📦 Installing all dependencies..." -ForegroundColor Cyan
    
    Write-Host "`n  [1/3] Root dependencies..." -ForegroundColor Blue
    npm install
    
    Write-Host "`n  [2/3] Backend dependencies..." -ForegroundColor Blue
    Push-Location $BackendPath
    npm install
    Pop-Location
    
    Write-Host "`n  [3/3] Frontend dependencies..." -ForegroundColor Blue
    Push-Location $FrontendPath
    npm install
    Pop-Location
    
    Write-Host "`n✅ All dependencies installed!" -ForegroundColor Green
    exit 0
}

# Start development
if ($Command -eq "dev") {
    Write-Host "`n🚀 Starting OpenPoC (Backend + Frontend)..." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Backend:  http://localhost:4041" -ForegroundColor Blue
    Write-Host "  Frontend: http://localhost:3000" -ForegroundColor Green
    Write-Host "  API Docs: http://localhost:4041/api/docs" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Press Ctrl+C to stop both servers" -ForegroundColor Gray
    Write-Host ""
    
    npm run dev
    exit 0
}

# Start backend only
if ($Command -eq "dev-backend") {
    Write-Host "`n🔵 Starting Backend only..." -ForegroundColor Cyan
    Write-Host "   http://localhost:4041" -ForegroundColor Blue
    Push-Location $BackendPath
    npm run dev
    Pop-Location
    exit 0
}

# Start frontend only
if ($Command -eq "dev-frontend") {
    Write-Host "`n🟢 Starting Frontend only..." -ForegroundColor Cyan
    Write-Host "   http://localhost:3000" -ForegroundColor Green
    Push-Location $FrontendPath
    npm run dev
    Pop-Location
    exit 0
}

# Build all
if ($Command -eq "build" -or $Command -eq "build-all") {
    Write-Host "`n🔨 Building all projects..." -ForegroundColor Cyan
    
    Write-Host "`n  Building Backend..." -ForegroundColor Blue
    Push-Location $BackendPath
    npm run build
    $backendBuild = $?
    Pop-Location
    
    Write-Host "`n  Building Frontend..." -ForegroundColor Green
    Push-Location $FrontendPath
    npm run build
    $frontendBuild = $?
    Pop-Location
    
    if ($backendBuild -and $frontendBuild) {
        Write-Host "`n✅ Build completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "`n❌ Build failed!" -ForegroundColor Red
    }
    exit 0
}

# Build backend
if ($Command -eq "build-backend") {
    Write-Host "`n🔨 Building Backend..." -ForegroundColor Cyan
    Push-Location $BackendPath
    npm run build
    Pop-Location
    exit 0
}

# Build frontend
if ($Command -eq "build-frontend") {
    Write-Host "`n🔨 Building Frontend..." -ForegroundColor Cyan
    Push-Location $FrontendPath
    npm run build
    Pop-Location
    exit 0
}

# Clean all
if ($Command -eq "clean") {
    Write-Host "`n🧹 Cleaning all artifacts..." -ForegroundColor Cyan
    
    Write-Host "`n  Removing node_modules..." -ForegroundColor Gray
    if (Test-Path "node_modules") { Remove-Item "node_modules" -Recurse -Force }
    if (Test-Path "$BackendPath/node_modules") { Remove-Item "$BackendPath/node_modules" -Recurse -Force }
    if (Test-Path "$FrontendPath/node_modules") { Remove-Item "$FrontendPath/node_modules" -Recurse -Force }
    
    Write-Host "`n  Removing build artifacts..." -ForegroundColor Gray
    if (Test-Path "$BackendPath/dist") { Remove-Item "$BackendPath/dist" -Recurse -Force }
    if (Test-Path "$FrontendPath/.next") { Remove-Item "$FrontendPath/.next" -Recurse -Force }
    if (Test-Path "$FrontendPath/dist") { Remove-Item "$FrontendPath/dist" -Recurse -Force }
    
    Write-Host "`n✅ Clean completed!" -ForegroundColor Green
    exit 0
}

# Test all
if ($Command -eq "test") {
    Write-Host "`n🧪 Running all tests..." -ForegroundColor Cyan
    npm run test
    exit 0
}

# Lint all
if ($Command -eq "lint") {
    Write-Host "`n✨ Running linters..." -ForegroundColor Cyan
    npm run lint
    exit 0
}

# Docker up
if ($Command -eq "docker-up") {
    Write-Host "`n🐳 Starting Docker containers..." -ForegroundColor Cyan
    docker-compose up
    exit 0
}

# Docker down
if ($Command -eq "docker-down") {
    Write-Host "`n🛑 Stopping Docker containers..." -ForegroundColor Cyan
    docker-compose down
    exit 0
}

# Unknown command
Write-Host "❌ Unknown command: $Command" -ForegroundColor Red
Write-Host ""
Write-Host "Run '.\dev-setup.ps1 help' to see available commands" -ForegroundColor Yellow
