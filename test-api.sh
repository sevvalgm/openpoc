#!/bin/bash

# API Test Script for OpenPOC
# Tests partnerships and products endpoints

BASE_URL="http://localhost:4041"
TOKEN="${1:-}" # Get token from env or arg

if [ -z "$TOKEN" ]; then
  echo "❌ Error: JWT token required"
  echo "Usage: $0 <jwt_token>"
  exit 1
fi

echo "🧪 Starting API Tests..."
echo "📍 Base URL: $BASE_URL"
echo "🔐 Using token: ${TOKEN:0:20}..."

# Test 1: Get user info
echo -e "\n\n1️⃣  Testing GET /users/me"
curl -X GET "$BASE_URL/users/me" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" | jq '.'

# Test 2: Get my companies
echo -e "\n\n2️⃣  Testing GET /companies/my-companies"
curl -X GET "$BASE_URL/companies/my-companies" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" | jq '.'

# Test 3: Get partnerships
echo -e "\n\n3️⃣  Testing GET /partnerships"
curl -X GET "$BASE_URL/partnerships" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" | jq '.'

# Test 4: Get partnership summary
echo -e "\n\n4️⃣  Testing GET /partnerships/summary/dashboard"
curl -X GET "$BASE_URL/partnerships/summary/dashboard" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" | jq '.'

# Test 5: Create partnership request
echo -e "\n\n5️⃣  Testing POST /partnership-requests"
curl -X POST "$BASE_URL/partnership-requests" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "targetEmail": "test@example.com",
    "detailType": "STRATEGIC",
    "message": "Test partnership request"
  }' | jq '.'

echo -e "\n\n✅ API Tests Completed!"
