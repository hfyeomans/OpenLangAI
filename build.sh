#!/bin/bash
# Build script for OpenLangAI
# Ensures consistent use of iPhone 16 Pro with iOS 18.5

# Set device configuration
DEVICE_NAME="iPhone 16 Pro"
OS_VERSION="18.5"
DESTINATION="platform=iOS Simulator,name=${DEVICE_NAME},OS=${OS_VERSION}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[OpenLangAI]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if xcodegen is installed
if ! command -v xcodegen &> /dev/null; then
    print_error "xcodegen is not installed. Please install it with: brew install xcodegen"
    exit 1
fi

# Parse command line arguments
COMMAND=${1:-build}

case $COMMAND in
    generate)
        print_status "Generating Xcode project..."
        xcodegen generate
        ;;
    
    build)
        print_status "Building OpenLangAI for ${DEVICE_NAME} (iOS ${OS_VERSION})..."
        xcodebuild -project OpenLangAI.xcodeproj \
                   -scheme OpenLangAI \
                   -destination "${DESTINATION}" \
                   build
        ;;
    
    test)
        print_status "Running tests on ${DEVICE_NAME} (iOS ${OS_VERSION})..."
        xcodebuild test -project OpenLangAI.xcodeproj \
                        -scheme OpenLangAI \
                        -destination "${DESTINATION}"
        ;;
    
    clean)
        print_status "Cleaning build artifacts..."
        xcodebuild -project OpenLangAI.xcodeproj \
                   -scheme OpenLangAI \
                   clean
        ;;
    
    all)
        print_status "Running full build pipeline..."
        $0 generate && $0 clean && $0 build && $0 test
        ;;
    
    *)
        echo "Usage: $0 {generate|build|test|clean|all}"
        echo ""
        echo "Commands:"
        echo "  generate - Generate Xcode project with xcodegen"
        echo "  build    - Build the project for ${DEVICE_NAME} (iOS ${OS_VERSION})"
        echo "  test     - Run tests on ${DEVICE_NAME} (iOS ${OS_VERSION})"
        echo "  clean    - Clean build artifacts"
        echo "  all      - Run all steps (generate, clean, build, test)"
        exit 1
        ;;
esac

if [ $? -eq 0 ]; then
    print_status "✅ ${COMMAND} completed successfully!"
else
    print_error "❌ ${COMMAND} failed!"
    exit 1
fi