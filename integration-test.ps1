# integration-test.ps1
# Quick integration test script for backend and frontend (Windows PowerShell)

$BACKEND_URL = "http://localhost:4041"
$FRONTEND_URL = "http://localhost:3000"
$API_ENDPOINT = "/api/health"

Write-Host "`n🔗 OpenPoC Backend & Frontend Integration Test`n" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green

# Check Backend
Write-Host "`n1️⃣  Testing Backend Health..." -ForegroundColor Yellow

try {
    $response = Invoke-WebRequest -Uri "$BACKEND_URL$API_ENDPOINT" -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-Host "   ✅ Backend is responding on $BACKEND_URL" -ForegroundColor Green
        
        # Get health details
        $health = $response.Content | ConvertFrom-Json
        Write-Host "   Status: $($health.status)" -ForegroundColor Cyan
        Write-Host "   Environment: $($health.environment)" -ForegroundColor Cyan
        Write-Host "   Database: $($health.database)" -ForegroundColor Cyan
    }
} catch {
    Write-Host "   ❌ Backend is NOT responding" -ForegroundColor Red
    Write-Host "   Make sure backend is running on port 4041" -ForegroundColor Red
    exit 1
}

# Check Frontend
Write-Host "`n2️⃣  Testing Frontend Health..." -ForegroundColor Yellow

try {
    $response = Invoke-WebRequest -Uri $FRONTEND_URL -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-Host "   ✅ Frontend is responding on $FRONTEND_URL" -ForegroundColor Green
    }
} catch {
    Write-Host "   ⚠️  Frontend is NOT responding (might not be started yet)" -ForegroundColor Yellow
}

# Check API Endpoints
Write-Host "`n3️⃣  Testing Key API Endpoints..." -ForegroundColor Yellow

$endpoints = @(
    "/api/health",
    "/api/auth/login",
    "/api/auth/register",
    "/api/users",
    "/api/products",
    "/api/pocs"
)

foreach ($endpoint in $endpoints) {
    try {
        $response = Invoke-WebRequest -Uri "$BACKEND_URL$endpoint" -UseBasicParsing -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 401 -or $response.StatusCode -eq 400) {
            Write-Host "   ✅ $endpoint" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  $endpoint" -ForegroundColor Yellow
        }
    } catch {
        if ($_.Exception.Response.StatusCode -eq "Unauthorized" -or $_.Exception.Response.StatusCode -eq "BadRequest") {
            Write-Host "   ✅ $endpoint (auth required)" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  $endpoint" -ForegroundColor Yellow
        }
    }
}

# Check Database
Write-Host "`n4️⃣  Testing Database Connection..." -ForegroundColor Yellow

try {
    $response = Invoke-WebRequest -Uri "$BACKEND_URL$API_ENDPOINT" -UseBasicParsing -ErrorAction Stop
    $health = $response.Content | ConvertFrom-Json
    
    if ($health.database -eq "connected") {
        Write-Host "   ✅ Database is connected" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Database connection issue" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "   ❌ Could not check database status" -ForegroundColor Red
}

# Summary
Write-Host "`n=================================================" -ForegroundColor Green
Write-Host "✅ Integration test completed!`n" -ForegroundColor Green

Write-Host "📖 API Documentation:" -ForegroundColor Cyan
Write-Host "   http://localhost:4041/api/docs"
Write-Host ""
Write-Host "🌐 Frontend:" -ForegroundColor Cyan
Write-Host "   http://localhost:3000"
Write-Host ""
Write-Host "📋 Entegrasyon Rehberi:" -ForegroundColor Cyan
Write-Host "   INTEGRATION_GUIDE.md" 
Write-Host ""
