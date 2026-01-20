#!/bin/bash
# Quick Start Guide - OpenPoC Modern Workflow System

echo "🚀 OpenPoC System Startup..."
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not installed"
    exit 1
fi
if ! command -v docker &> /dev/null; then
    echo "⚠️  Docker not installed (optional, for containerized deployment)"
fi

echo "✅ Prerequisites OK"
echo ""

# Backend setup
echo "📦 Setting up Backend..."
cd openpoc-backend
npm install --legacy-peer-deps
npx prisma generate
npx prisma db push --skip-generate
npm run build

if [ $? -ne 0 ]; then
    echo "❌ Backend build failed"
    exit 1
fi
echo "✅ Backend ready"
echo ""

# Frontend setup
echo "🎨 Setting up Frontend..."
cd ../openpoc-frontend/v0-open-po-c-dashboard-design-2
npm install --legacy-peer-deps
npm run build

if [ $? -ne 0 ]; then
    echo "❌ Frontend build failed"
    exit 1
fi
echo "✅ Frontend ready"
echo ""

# Start services
echo "🎯 Starting services..."
echo ""
echo "Starting Backend on port 4041..."
cd ../../openpoc-backend
npm start &
BACKEND_PID=$!

sleep 5

echo "Starting Frontend on port 3000..."
cd ../openpoc-frontend/v0-open-po-c-dashboard-design-2
npm start &
FRONTEND_PID=$!

sleep 5

echo ""
echo "✅ System is running!"
echo ""
echo "📱 Frontend: http://localhost:3000"
echo "🔧 Backend: http://localhost:4041"
echo "📚 API Docs: http://localhost:4041/api"
echo ""
echo "🔑 Demo Credentials:"
echo "   Email: admin@securecorp.com"
echo "   Password: SecurePass123!"
echo ""
echo "Press Ctrl+C to stop all services"
echo ""

wait
