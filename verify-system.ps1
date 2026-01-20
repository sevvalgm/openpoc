Write-Host "System Verification - OpenPoC Modern Workflow" -ForegroundColor Green
Write-Host ""

$checks = @{
    "Backend messaging module" = Test-Path "openpoc-backend\src\messaging\messaging.module.ts"
    "Frontend messaging widget" = Test-Path "openpoc-frontend\v0-open-po-c-dashboard-design-2\components\messaging\messaging-widget.tsx"
    "POC dashboard component" = Test-Path "openpoc-frontend\v0-open-po-c-dashboard-design-2\components\poc\poc-dashboard.tsx"
    "Demo cleanup utility" = Test-Path "openpoc-frontend\v0-open-po-c-dashboard-design-2\lib\utils\demo-cleanup.ts"
    "Backend build output" = Test-Path "openpoc-backend\dist"
    "Frontend build output" = Test-Path "openpoc-frontend\v0-open-po-c-dashboard-design-2\.next"
    "Database schema" = (Select-String -Path "openpoc-backend\prisma\schema.prisma" -Pattern "model Conversation" -Quiet)
    "Implementation guide" = Test-Path "IMPLEMENTATION_GUIDE.md"
}

$passed = 0
$failed = 0

foreach ($check in $checks.GetEnumerator()) {
    if ($check.Value) {
        Write-Host "[PASS] $($check.Key)" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "[FAIL] $($check.Key)" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "Results: $passed passed, $failed failed" -ForegroundColor Cyan
Write-Host ""

if ($failed -eq 0) {
    Write-Host "SUCCESS: System ready for deployment!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Run quickstart.ps1 to start services" -ForegroundColor White
    Write-Host "2. Frontend: http://localhost:3000" -ForegroundColor White
    Write-Host "3. Backend API: http://localhost:4041" -ForegroundColor White
}
