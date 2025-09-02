#!/bin/bash
# Automated deployment script with rollback capability

set -e

# Configuration
APACHE_HOME="/usr/local/apache2"
BACKUP_DIR="/workspaces/httpd/lab_environment/backup"
DEPLOY_LOG="/workspaces/httpd/lab_environment/logs/deploy.log"
WEB_ROOT="$APACHE_HOME/htdocs"

# Functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$DEPLOY_LOG"
}

backup_current() {
    local backup_name="backup_$(date +%Y%m%d_%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    log "Creating backup: $backup_name"
    mkdir -p "$backup_path"
    
    # Backup web content
    cp -r "$WEB_ROOT" "$backup_path/"
    
    # Backup configuration
    cp -r "$APACHE_HOME/conf" "$backup_path/"
    
    log "Backup completed: $backup_path"
    echo "$backup_path" > "$BACKUP_DIR/latest_backup"
}

deploy_content() {
    local source_dir="$1"
    
    if [ ! -d "$source_dir" ]; then
        log "ERROR: Source directory $source_dir not found"
        exit 1
    fi
    
    log "Deploying content from $source_dir"
    
    # Copy new content
    cp -r "$source_dir"/* "$WEB_ROOT/"
    
    # Set proper permissions
    chown -R $(whoami):$(whoami) "$WEB_ROOT"
    chmod -R 644 "$WEB_ROOT"
    find "$WEB_ROOT" -type d -exec chmod 755 {} \;
    
    log "Content deployment completed"
}

test_deployment() {
    log "Testing deployment..."
    
    # Test Apache configuration
    "$APACHE_HOME/bin/httpd" -t
    if [ $? -ne 0 ]; then
        log "ERROR: Apache configuration test failed"
        return 1
    fi
    
    # Test HTTP response
    if command -v curl &> /dev/null; then
        response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080)
        if [ "$response" != "200" ]; then
            log "ERROR: HTTP test failed (got $response, expected 200)"
            return 1
        fi
    fi
    
    log "Deployment tests passed"
    return 0
}

rollback() {
    local backup_path=$(cat "$BACKUP_DIR/latest_backup" 2>/dev/null)
    
    if [ -z "$backup_path" ] || [ ! -d "$backup_path" ]; then
        log "ERROR: No backup found for rollback"
        exit 1
    fi
    
    log "Rolling back to: $backup_path"
    
    # Restore web content
    rm -rf "$WEB_ROOT"
    cp -r "$backup_path/htdocs" "$APACHE_HOME/"
    
    # Restore configuration
    cp -r "$backup_path/conf" "$APACHE_HOME/"
    
    # Reload Apache
    "$APACHE_HOME/bin/httpd" -k graceful
    
    log "Rollback completed"
}

# Main deployment process
main() {
    local source_dir="$1"
    local action="${2:-deploy}"
    
    case "$action" in
        "deploy")
            if [ -z "$source_dir" ]; then
                echo "Usage: $0 <source_directory> [deploy|rollback|test]"
                exit 1
            fi
            
            log "Starting deployment process"
            backup_current
            deploy_content "$source_dir"
            
            if test_deployment; then
                log "Deployment successful"
                # Reload Apache gracefully
                "$APACHE_HOME/bin/httpd" -k graceful
            else
                log "Deployment failed, initiating rollback"
                rollback
                exit 1
            fi
            ;;
        "rollback")
            rollback
            ;;
        "test")
            test_deployment
            ;;
        *)
            echo "Usage: $0 <source_directory> [deploy|rollback|test]"
            exit 1
            ;;
    esac
}

main "$@"
