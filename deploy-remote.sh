#!/bin/bash

# Remote deployment script for web-performance-project1-initial
# This script deploys the application to remote server via SSH

set -e  # Exit on any error

# Configuration from Jenkins environment variables
SSH_USER="${SSH_USER:-newbie}"
DEPLOY_SERVER="${DEPLOY_SERVER:-10.1.1.195}"
SSH_PORT="${SSH_PORT:-3334}"
WEB_SERVER="${WEB_SERVER:-10.1.1.195}"
SSH_KEY="${SSH_KEY}"
REMOTE_BASE_PATH="${REMOTE_BASE_PATH:-/usr/share/nginx/html/jenkins}"
DEPLOY_USER="${DEPLOY_USER:-lanlh}"
TIMESTAMP="${TIMESTAMP:-$(date +%Y%m%d%H%M%S)}"
KEEP_DEPLOYMENTS="${KEEP_DEPLOYMENTS:-5}"

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

# Validate required environment variables
validate_environment() {
    log "Validating environment variables..."
    
    if [[ -z "$SSH_KEY" ]]; then
        error "SSH_KEY environment variable is required"
        exit 1
    fi
    
    if [[ ! -f "$SSH_KEY" ]]; then
        error "SSH key file not found: $SSH_KEY"
        exit 1
    fi
    
    if [[ -z "$DEPLOY_SERVER" ]]; then
        error "DEPLOY_SERVER environment variable is required"
        exit 1
    fi
    
    success "Environment validation passed"
}

# Test SSH connection
test_ssh_connection() {
    log "Testing SSH connection to $SSH_USER@$DEPLOY_SERVER:$SSH_PORT..."
    
    if ssh -i "$SSH_KEY" -p "$SSH_PORT" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER@$DEPLOY_SERVER" "echo 'SSH connection successful'" >/dev/null 2>&1; then
        success "SSH connection test passed"
    else
        error "SSH connection failed"
        error "Check SSH credentials and server accessibility"
        exit 1
    fi
}

# Create remote directory structure
create_remote_directories() {
    log "Creating remote directory structure..."
    
    ssh -i "$SSH_KEY" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$DEPLOY_SERVER" "
        # Create base directories
        mkdir -p $REMOTE_BASE_PATH/$DEPLOY_USER/web-performance-project1-initial
        mkdir -p $REMOTE_BASE_PATH/$DEPLOY_USER/deploy/$TIMESTAMP
        
        # Verify directories were created
        if [[ ! -d '$REMOTE_BASE_PATH/$DEPLOY_USER/deploy/$TIMESTAMP' ]]; then
            echo 'Failed to create deployment directory'
            exit 1
        fi
        
        echo 'Remote directories created successfully'
    "
    
    success "Remote directory structure created"
}

# Upload deployment files
upload_files() {
    log "Uploading deployment files to remote server..."
    
    # Check if deploy-staging directory exists
    if [[ ! -d "deploy-staging" ]]; then
        error "deploy-staging directory not found"
        error "Make sure deployment files are prepared first"
        exit 1
    fi
    
    # Upload files to timestamped directory
    log "Uploading to timestamped directory: $TIMESTAMP"
    if scp -i "$SSH_KEY" -P "$SSH_PORT" -o StrictHostKeyChecking=no -r deploy-staging/* "$SSH_USER@$DEPLOY_SERVER:$REMOTE_BASE_PATH/$DEPLOY_USER/deploy/$TIMESTAMP/"; then
        success "Files uploaded to timestamped directory"
    else
        error "Failed to upload files to timestamped directory"
        exit 1
    fi
    
    # Also copy to main project directory for direct access
    log "Uploading to main project directory..."
    if scp -i "$SSH_KEY" -P "$SSH_PORT" -o StrictHostKeyChecking=no -r deploy-staging/* "$SSH_USER@$DEPLOY_SERVER:$REMOTE_BASE_PATH/$DEPLOY_USER/web-performance-project1-initial/"; then
        success "Files uploaded to main project directory"
    else
        warning "Failed to upload to main project directory (non-critical)"
    fi
}

# Update current symlink
update_symlink() {
    log "Updating current symlink..."
    
    ssh -i "$SSH_KEY" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$DEPLOY_SERVER" "
        cd $REMOTE_BASE_PATH/$DEPLOY_USER/deploy
        
        # Remove existing symlink if it exists
        if [[ -L 'current' ]]; then
            rm -f current
        elif [[ -d 'current' ]]; then
            echo 'Warning: current is a directory, removing...'
            rm -rf current
        fi
        
        # Create new symlink
        ln -sf $TIMESTAMP current
        
        # Verify symlink
        if [[ -L 'current' ]] && [[ \"\$(readlink current)\" == '$TIMESTAMP' ]]; then
            echo 'Symlink updated successfully'
            ls -la current/
        else
            echo 'Failed to create symlink'
            exit 1
        fi
    "
    
    success "Current symlink updated"
}

# Cleanup old deployments
cleanup_old_deployments() {
    log "Cleaning up old deployments (keeping last $KEEP_DEPLOYMENTS)..."
    
    ssh -i "$SSH_KEY" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$DEPLOY_SERVER" "
        cd $REMOTE_BASE_PATH/$DEPLOY_USER/deploy
        
        # Count current deployments
        DEPLOYMENT_COUNT=\$(ls -1 | grep -E '^[0-9]{14}$' | wc -l)
        echo \"Current deployments: \$DEPLOYMENT_COUNT\"
        
        if [[ \$DEPLOYMENT_COUNT -gt $KEEP_DEPLOYMENTS ]]; then
            # Get directories to delete (oldest first, skip the most recent ones)
            DIRS_TO_DELETE=\$(ls -1t | grep -E '^[0-9]{14}$' | tail -n +\$(($KEEP_DEPLOYMENTS + 1)))
            
            if [[ -n \"\$DIRS_TO_DELETE\" ]]; then
                echo \"Removing old deployments: \$DIRS_TO_DELETE\"
                echo \"\$DIRS_TO_DELETE\" | xargs rm -rf
                echo \"Cleanup completed\"
            fi
        else
            echo \"No cleanup needed\"
        fi
        
        # Show remaining deployments
        echo \"Remaining deployments:\"
        ls -la | grep -E '^d.*[0-9]{14}' || echo 'No dated directories found'
    "
    
    success "Old deployments cleaned up"
}

# Verify deployment
verify_deployment() {
    log "Verifying deployment..."
    
    # Check if files exist in current deployment
    ssh -i "$SSH_KEY" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$DEPLOY_SERVER" "
        cd $REMOTE_BASE_PATH/$DEPLOY_USER/deploy/current
        
        # Check essential files
        ESSENTIAL_FILES='index.html 404.html css js images'
        for file in \$ESSENTIAL_FILES; do
            if [[ -e \"\$file\" ]]; then
                echo \"✓ \$file exists\"
            else
                echo \"✗ \$file missing\"
            fi
        done
        
        echo \"Deployment verification completed\"
    "
    
    success "Deployment verification completed"
}

# Display deployment information
show_deployment_info() {
    log "Deployment Information:"
    echo "  SSH Server: $SSH_USER@$DEPLOY_SERVER:$SSH_PORT"
    echo "  Web Server: $WEB_SERVER"
    echo "  Deploy User: $DEPLOY_USER"
    echo "  Timestamp: $TIMESTAMP"
    echo "  Remote Path: $REMOTE_BASE_PATH/$DEPLOY_USER/"
    echo ""
    echo "  Access URLs:"
    echo "  🌐 Current: http://$WEB_SERVER/jenkins/$DEPLOY_USER/current/"
    echo "  📁 Project: http://$WEB_SERVER/jenkins/$DEPLOY_USER/web-performance-project1-initial/"
    echo "  📅 Timestamped: http://$WEB_SERVER/jenkins/$DEPLOY_USER/deploy/$TIMESTAMP/"
}

# Main deployment function
main() {
    log "Starting remote deployment..."
    
    # Run deployment steps
    validate_environment
    test_ssh_connection
    create_remote_directories
    upload_files
    update_symlink
    cleanup_old_deployments
    verify_deployment
    show_deployment_info
    
    success "🚀 Remote deployment completed successfully!"
}

# Handle script interruption
trap 'error "Remote deployment interrupted"; exit 1' INT TERM

# Run main function
main "$@"