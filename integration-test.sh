#!/bin/bash
# integration-test.sh
# Quick integration test script for backend and frontend

set -e

BACKEND_URL="http://localhost:4041"
FRONTEND_URL="http://localhost:3000"
API_ENDPOINT="/api/health"

echo "🔗 OpenPoC Backend & Frontend Integration Test"
echo "================================================="
echo ""

# Check Backend
echo "1️⃣  Testing Backend Health..."
if curl -s -f "$BACKEND_URL$API_ENDPOINT" > /dev/null; then
  echo "   ✅ Backend is responding on $BACKEND_URL"
  
  # Get health details
  HEALTH=$(curl -s "$BACKEND_URL$API_ENDPOINT")
  echo "   Status: $(echo $HEALTH | jq -r '.status')"
  echo "   Environment: $(echo $HEALTH | jq -r '.environment')"
  echo "   Database: $(echo $HEALTH | jq -r '.database')"
else
  echo "   ❌ Backend is NOT responding"
  echo "   Make sure backend is running on port 4041"
  exit 1
fi

echo ""

# Check Frontend
echo "2️⃣  Testing Frontend Health..."
if curl -s -f "$FRONTEND_URL" > /dev/null; then
  echo "   ✅ Frontend is responding on $FRONTEND_URL"
else
  echo "   ⚠️  Frontend is NOT responding (might not be started yet)"
fi

echo ""

# Check API Endpoints
echo "3️⃣  Testing Key API Endpoints..."
ENDPOINTS=(
  "/api/auth/login"
  "/api/auth/register"
  "/api/users"
  "/api/products"
  "/api/pocs"
  "/api/evaluations"
  "/api/partnership"
)

for endpoint in "${ENDPOINTS[@]}"; do
  if curl -s -I -f "$BACKEND_URL$endpoint" > /dev/null 2>&1; then
    echo "   ✅ $endpoint"
  else
    echo "   ⚠️  $endpoint (may require authentication)"
  fi
done

echo ""

# Check Database
echo "4️⃣  Testing Database Connection..."
HEALTH=$(curl -s "$BACKEND_URL$API_ENDPOINT" | jq -r '.database')
if [ "$HEALTH" = "connected" ]; then
  echo "   ✅ Database is connected"
else
  echo "   ❌ Database connection issue"
  exit 1
fi

echo ""
echo "================================================="
echo "✅ All integration tests completed!"
echo ""
echo "📖 API Documentation:"
echo "   http://localhost:4041/api/docs"
echo ""
echo "🌐 Frontend:"
echo "   http://localhost:3000"
echo ""
