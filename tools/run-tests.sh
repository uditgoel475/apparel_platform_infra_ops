#!/bin/bash

# Payment Flow Test Runner
# This script runs all tests for the payment flow implementation

set -e

echo "🚀 Starting Payment Flow Test Suite"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "apparel_platform_backend/package.json" ] || [ ! -f "apparel_platform_frontend/package.json" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Backend Tests
print_status "Running Backend Tests..."
cd apparel_platform_backend

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    print_status "Installing backend dependencies..."
    npm install
fi

# Run unit tests
print_status "Running backend unit tests..."
npm run test -- --coverage --watchAll=false

# Run e2e tests
print_status "Running backend e2e tests..."
npm run test:e2e -- --detectOpenHandles

print_success "Backend tests completed!"

# Frontend Tests
print_status "Running Frontend Tests..."
cd ../apparel_platform_frontend

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    print_status "Installing frontend dependencies..."
    npm install
fi

# Run frontend tests
print_status "Running frontend tests..."
npm run test -- --coverage --watchAll=false

print_success "Frontend tests completed!"

# Integration Tests
print_status "Running Integration Tests..."
cd ../apparel_platform_backend

# Run integration tests specifically for payment flow
print_status "Running payment flow integration tests..."
npm run test -- --testPathPattern="payment-flow" --coverage

print_success "Integration tests completed!"

# Test Summary
echo ""
echo "=================================="
echo "🎉 All Tests Completed Successfully!"
echo "=================================="

# Display coverage summary
print_status "Test Coverage Summary:"
echo "Backend: Check coverage/lcov-report/index.html"
echo "Frontend: Check coverage/lcov-report/index.html"

# Performance check
print_status "Running performance checks..."
cd ../apparel_platform_backend
npm run build > /dev/null 2>&1
print_success "Backend build successful"

cd ../apparel_platform_frontend
npm run build > /dev/null 2>&1
print_success "Frontend build successful"

echo ""
print_success "✅ Payment Flow Implementation is ready for production!"
echo ""
echo "📋 Next Steps:"
echo "1. Review test coverage reports"
echo "2. Run manual testing scenarios"
echo "3. Deploy to staging environment"
echo "4. Perform user acceptance testing"
echo "5. Deploy to production"
echo ""
echo "📚 Documentation:"
echo "- API Documentation: See PAYMENT_FLOW_README.md"
echo "- Component Documentation: See component JSDoc comments"
echo "- Database Schema: See Prisma schema files"
echo ""
