#!/bin/bash

# Medication History Test Runner Script
# This script runs all medication history tests

set -e

echo "=================================="
echo "Medication History Test Suite"
echo "=================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}Error: Flutter is not installed or not in PATH${NC}"
    echo "Please install Flutter from https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo -e "${YELLOW}Running Unit Tests...${NC}"
echo "-----------------------------------"
flutter test test/medication_history_models_test.dart
echo ""

echo -e "${YELLOW}Running Widget Tests...${NC}"
echo "-----------------------------------"
flutter test test/medication_history_overlay_test.dart
echo ""

echo -e "${YELLOW}Running Integration Tests...${NC}"
echo "-----------------------------------"
echo "Note: Integration tests require a device or emulator"
flutter test integration_test/medication_history_integration_test.dart || echo -e "${YELLOW}Skipped (no device available)${NC}"
echo ""

echo -e "${GREEN}=================================="
echo "Test Suite Complete!"
echo "==================================${NC}"
echo ""

# Optional: Generate coverage report
read -p "Generate coverage report? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Generating coverage report...${NC}"
    flutter test --coverage test/medication_history_models_test.dart test/medication_history_overlay_test.dart
    
    if command -v genhtml &> /dev/null; then
        genhtml coverage/lcov.info -o coverage/html
        echo -e "${GREEN}Coverage report generated at coverage/html/index.html${NC}"
        
        # Open in browser (macOS)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            open coverage/html/index.html
        fi
    else
        echo -e "${YELLOW}Install lcov to generate HTML coverage report: brew install lcov${NC}"
    fi
fi
