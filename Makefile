# Unified Development Commands
# Usage: make [command]

.PHONY: help install dev build test lint clean docker-up docker-down

help:
	@echo "OpenPoC Unified Development Commands:"
	@echo ""
	@echo "Setup Commands:"
	@echo "  make install         - Install all dependencies"
	@echo "  make clean           - Clean all node_modules and build artifacts"
	@echo ""
	@echo "Development Commands:"
	@echo "  make dev             - Start backend & frontend together (RECOMMENDED)"
	@echo "  make dev-backend     - Start only backend"
	@echo "  make dev-frontend    - Start only frontend"
	@echo ""
	@echo "Build Commands:"
	@echo "  make build-all       - Build both backend and frontend"
	@echo "  make build-backend   - Build only backend"
	@echo "  make build-frontend  - Build only frontend"
	@echo ""
	@echo "Testing & Linting:"
	@echo "  make test            - Run all tests"
	@echo "  make test-backend    - Run backend tests"
	@echo "  make test-frontend   - Run frontend tests"
	@echo "  make lint            - Run linters"
	@echo ""
	@echo "Docker Commands:"
	@echo "  make docker-build    - Build Docker images"
	@echo "  make docker-up       - Start all containers"
	@echo "  make docker-down     - Stop all containers"
	@echo ""

install:
	@echo "Installing all dependencies..."
	npm install
	cd openpoc-backend && npm install
	cd ../openpoc-frontend/v0-open-po-c-dashboard-design-2 && npm install

dev:
	@echo "Starting OpenPoC (Backend + Frontend)..."
	npm run dev

dev-backend:
	@echo "Starting Backend only..."
	cd openpoc-backend && npm run dev

dev-frontend:
	@echo "Starting Frontend only..."
	cd openpoc-frontend/v0-open-po-c-dashboard-design-2 && npm run dev

build-all:
	@echo "Building both projects..."
	npm run build:all

build-backend:
	@echo "Building Backend..."
	cd openpoc-backend && npm run build

build-frontend:
	@echo "Building Frontend..."
	cd openpoc-frontend/v0-open-po-c-dashboard-design-2 && npm run build

test:
	@echo "Running all tests..."
	npm run test

test-backend:
	@echo "Running Backend tests..."
	cd openpoc-backend && npm test

test-frontend:
	@echo "Running Frontend tests..."
	cd openpoc-frontend/v0-open-po-c-dashboard-design-2 && npm test

lint:
	@echo "Running linters..."
	npm run lint

clean:
	@echo "Cleaning all artifacts..."
	npm run clean

docker-build:
	@echo "Building Docker images..."
	docker-compose build

docker-up:
	@echo "Starting Docker containers..."
	docker-compose up

docker-down:
	@echo "Stopping Docker containers..."
	docker-compose down

.DEFAULT_GOAL := help
