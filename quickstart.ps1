# Quick Start Guide - OpenPoC Modern Workflow System (Windows PowerShell)

Write-Host "🚀 OpenPoC System Startup..." -ForegroundColor Green
Write-Host ""

# Check prerequisites
Write-Host "📋 Checking prerequisites..." -ForegroundColor Yellow
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Node.js not installed" -ForegroundColor Red
    exit 1
}
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "⚠️  Docker not installed (optional)" -ForegroundColor Yellow
}

Write-Host "✅ Prerequisites OK" -ForegroundColor Green
Write-Host ""

# Backend setup
Write-Host "📦 Setting up Backend..." -ForegroundColor Yellow
Push-Location openpoc-backend
npm install --legacy-peer-deps
npx prisma generate
npx prisma db push --skip-generate
npm run build

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Backend build failed" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Backend ready" -ForegroundColor Green
Write-Host ""

# Frontend setup
Write-Host "🎨 Setting up Frontend..." -ForegroundColor Yellow
Push-Location ..\openpoc-frontend\v0-open-po-c-dashboard-design-2
npm install --legacy-peer-deps
npm run build

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Frontend build failed" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Frontend ready" -ForegroundColor Green
Write-Host ""

# Show next steps
Write-Host "🎯 Startup Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Backend:  cd openpoc-backend && npm start" -ForegroundColor White
Write-Host "2. Frontend: cd openpoc-frontend\v0-open-po-c-dashboard-design-2 && npm start" -ForegroundColor White
Write-Host ""
Write-Host "📱 Access:" -ForegroundColor Cyan
Write-Host "   Frontend: http://localhost:3000" -ForegroundColor White
Write-Host "   Backend:  http://localhost:4041" -ForegroundColor White
Write-Host "   API Docs: http://localhost:4041/api" -ForegroundColor White
Write-Host ""
Write-Host "🔑 Demo Credentials:" -ForegroundColor Cyan
Write-Host "   Email:    admin@securecorp.com" -ForegroundColor White
Write-Host "   Password: SecurePass123!" -ForegroundColor White
Write-Host ""

Pop-Location
Pop-Location
