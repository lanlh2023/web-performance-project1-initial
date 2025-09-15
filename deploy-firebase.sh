#!/bin/bash

# Firebase deployment script for web-performance-project1-initial
# This script deploys the application to Firebase Hosting

set -e  # Exit on any error

# Configuration
PROJECT_NAME="web-performance-project1-initial"
FIREBASE_PROJECT_ID="lanlh-workshop2"  # From your Firebase config
BUILD_DIR="dist"  # Directory to deploy
CREDENTIALS_FILE="${GOOGLE_APPLICATION_CREDENTIALS:-}"
FIREBASE_SERVICE_ACCOUNT_KEY="${FIREBASE_SERVICE_ACCOUNT_KEY:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Setup credentials from Jenkins secret or file
setup_credentials() {
    log "Setting up Firebase credentials..."
    
    if [[ -n "$FIREBASE_SERVICE_ACCOUNT_KEY" ]]; then
        # Using Jenkins secret - create temporary credentials file
        TEMP_CREDENTIALS_FILE="/tmp/firebase-credentials-$$.json"
        echo "$FIREBASE_SERVICE_ACCOUNT_KEY" > "$TEMP_CREDENTIALS_FILE"
        export GOOGLE_APPLICATION_CREDENTIALS="$TEMP_CREDENTIALS_FILE"
        CREDENTIALS_FILE="$TEMP_CREDENTIALS_FILE"
        log "Using Firebase service account key from Jenkins secret"
    elif [[ -n "$CREDENTIALS_FILE" && -f "$CREDENTIALS_FILE" ]]; then
        # Using existing file
        log "Using existing credentials file: $CREDENTIALS_FILE"
    else
        error "No Firebase credentials found!"
        error "Either set FIREBASE_SERVICE_ACCOUNT_KEY (Jenkins secret) or GOOGLE_APPLICATION_CREDENTIALS (file path)"
        exit 1
    fi
    
    success "Firebase credentials configured"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if firebase CLI is installed
    if ! command -v firebase &> /dev/null; then
        error "Firebase CLI is not installed"
        error "Install it with: npm install -g firebase-tools"
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Prepare build directory
prepare_build() {
    log "Preparing build directory..."
    
    # Remove existing build directory
    if [[ -d "$BUILD_DIR" ]]; then
        rm -rf "$BUILD_DIR"
    fi
    
    # Create build directory
    mkdir -p "$BUILD_DIR"
    
    # Copy essential files for deployment
    ESSENTIAL_FILES=(
        "index.html"
        "404.html"
        "css"
        "js"
        "images"
    )
    
    for item in "${ESSENTIAL_FILES[@]}"; do
        if [[ -e "$item" ]]; then
            log "Copying $item to build directory..."
            cp -r "$item" "$BUILD_DIR/"
        else
            warning "File/directory $item not found, skipping..."
        fi
    done
    
    success "Build directory prepared"
}


# Deploy to Firebase
deploy_to_firebase() {
    log "Deploying to Firebase Hosting..."
    
    # Ensure we're using the correct authentication method
    # Unset any FIREBASE_TOKEN to avoid deprecated auth warning
    unset FIREBASE_TOKEN 2>/dev/null || true
    
    # Verify Firebase configuration
    log "Verifying Firebase configuration..."
    if [[ ! -f "firebase.json" ]]; then
        error "firebase.json not found"
        error "Run 'firebase init' to initialize Firebase configuration"
        exit 1
    fi
    
    # Verify authentication
    log "Verifying Firebase authentication..."
    log "GOOGLE_APPLICATION_CREDENTIALS: $GOOGLE_APPLICATION_CREDENTIALS"
    
    # Check if credentials file exists and is readable
    if [[ ! -f "$GOOGLE_APPLICATION_CREDENTIALS" ]]; then
        error "Credentials file not found: $GOOGLE_APPLICATION_CREDENTIALS"
        exit 1
    fi
    
    # Test Firebase authentication with projects list
    if ! firebase projects:list >/dev/null 2>&1; then
        error "Firebase authentication failed"
        error "Credentials file: $GOOGLE_APPLICATION_CREDENTIALS"
        error "Project ID: $FIREBASE_PROJECT_ID"
        # Show first few lines of credentials for debugging (without private key)
        log "Credentials file content (first 3 lines):"
        head -3 "$GOOGLE_APPLICATION_CREDENTIALS" || true
        exit 1
    fi
    
    log "Firebase authentication successful"
    
    # Deploy to Firebase
    log "Starting Firebase deployment..."
    NODE_OPTIONS="--max-old-space-size=4096" firebase deploy --only hosting --project="$FIREBASE_PROJECT_ID" --non-interactive
    
    success "Deployment to Firebase completed"
}

# Get deployment URL
get_deployment_url() {
    log "Getting deployment information..."
    
    local hosting_url="https://${FIREBASE_PROJECT_ID}.web.app"
    local custom_domain_url="https://${FIREBASE_PROJECT_ID}.firebaseapp.com"
    
    echo ""
    echo "🚀 Deployment completed successfully!"
    echo ""
    echo "📱 Your application is now live at:"
    echo "   Primary URL: $hosting_url"
    echo "   Alternative: $custom_domain_url"
    echo ""
    echo "🔧 Project Information:"
    echo "   Project ID: $FIREBASE_PROJECT_ID"
    echo "   Build Directory: $BUILD_DIR"
    echo "   Deployment Time: $(date)"
}

# Cleanup build directory and temporary files
cleanup() {
    # Clean up temporary credentials file if created
    if [[ -n "$TEMP_CREDENTIALS_FILE" && -f "$TEMP_CREDENTIALS_FILE" ]]; then
        log "Cleaning up temporary credentials file..."
        rm -f "$TEMP_CREDENTIALS_FILE"
    fi
    
    # Clean up build directory
    if [[ "$1" == "--keep-build" ]]; then
        log "Keeping build directory as requested"
    else
        log "Cleaning up build directory..."
        rm -rf "$BUILD_DIR"
        success "Cleanup completed"
    fi
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --keep-build    Keep the build directory after deployment"
    echo "  --help         Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  FIREBASE_SERVICE_ACCOUNT_KEY      Firebase service account key JSON content (for Jenkins)"
    echo "  GOOGLE_APPLICATION_CREDENTIALS    Path to Firebase service account key JSON file"
    echo ""
    echo "Examples:"
    echo "  # Using Jenkins secret:"
    echo "  export FIREBASE_SERVICE_ACCOUNT_KEY='{\\"type\\": \\"service_account\\", ...}'"
    echo "  $0"
    echo ""
    echo "  # Using file path:"
    echo "  export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json"
    echo "  $0"
}

# Main deployment process
main() {
    local keep_build=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --keep-build)
                keep_build=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    log "Starting Firebase deployment of $PROJECT_NAME..."
    
    # Run deployment steps
    check_prerequisites
    setup_credentials
    prepare_build
    deploy_to_firebase
    get_deployment_url
    
    # Cleanup
    if [[ "$keep_build" == true ]]; then
        cleanup --keep-build
    else
        cleanup
    fi
    
    success "🎉 Firebase deployment completed successfully!"
}

# Handle script interruption
trap 'error "Deployment interrupted"; cleanup; exit 1' INT TERM

# Run main function with all arguments
main "$@"
