#!/bin/bash
# Comprehensive backup management system

set -e

APACHE_HOME="/usr/local/apache2"
BACKUP_BASE_DIR="/workspaces/httpd/lab_environment/backup"
RETENTION_DAYS=30
LOG_FILE="/workspaces/httpd/lab_environment/logs/backup.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

create_backup() {
    local backup_type="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$BACKUP_BASE_DIR/${backup_type}_${timestamp}"
    
    mkdir -p "$backup_dir"
    
    case "$backup_type" in
        "full")
            log "Creating full backup..."
            
            # Backup web content
            tar -czf "$backup_dir/htdocs.tar.gz" -C "$APACHE_HOME" htdocs/
            
            # Backup configuration
            tar -czf "$backup_dir/conf.tar.gz" -C "$APACHE_HOME" conf/
            
            # Backup logs
            tar -czf "$backup_dir/logs.tar.gz" -C "$APACHE_HOME" logs/
            
            # Create manifest
            echo "backup_type=full" > "$backup_dir/manifest"
            echo "timestamp=$timestamp" >> "$backup_dir/manifest"
            echo "apache_version=$(httpd -v | head -1)" >> "$backup_dir/manifest"
            
            log "Full backup completed: $backup_dir"
            ;;
        
        "config")
            log "Creating configuration backup..."
            
            # Backup only configuration
            tar -czf "$backup_dir/conf.tar.gz" -C "$APACHE_HOME" conf/
            
            echo "backup_type=config" > "$backup_dir/manifest"
            echo "timestamp=$timestamp" >> "$backup_dir/manifest"
            
            log "Configuration backup completed: $backup_dir"
            ;;
        
        "data")
            log "Creating data backup..."
            
            # Backup only web content
            tar -czf "$backup_dir/htdocs.tar.gz" -C "$APACHE_HOME" htdocs/
            
            echo "backup_type=data" > "$backup_dir/manifest"
            echo "timestamp=$timestamp" >> "$backup_dir/manifest"
            
            log "Data backup completed: $backup_dir"
            ;;
    esac
    
    # Calculate backup size
    local size=$(du -sh "$backup_dir" | cut -f1)
    echo "backup_size=$size" >> "$backup_dir/manifest"
    
    echo "$backup_dir"
}

restore_backup() {
    local backup_dir="$1"
    
    if [ ! -d "$backup_dir" ]; then
        log "ERROR: Backup directory not found: $backup_dir"
        exit 1
    fi
    
    if [ ! -f "$backup_dir/manifest" ]; then
        log "ERROR: Invalid backup (no manifest): $backup_dir"
        exit 1
    fi
    
    source "$backup_dir/manifest"
    
    log "Restoring backup: $backup_dir (type: $backup_type, timestamp: $timestamp)"
    
    # Create current backup before restore
    log "Creating safety backup before restore..."
    safety_backup=$(create_backup "full")
    
    case "$backup_type" in
        "full"|"config")
            if [ -f "$backup_dir/conf.tar.gz" ]; then
                log "Restoring configuration..."
                rm -rf "$APACHE_HOME/conf.backup"
                mv "$APACHE_HOME/conf" "$APACHE_HOME/conf.backup"
                tar -xzf "$backup_dir/conf.tar.gz" -C "$APACHE_HOME/"
            fi
            ;&  # Fall through
        
        "full"|"data")
            if [ -f "$backup_dir/htdocs.tar.gz" ]; then
                log "Restoring web content..."
                rm -rf "$APACHE_HOME/htdocs.backup"
                mv "$APACHE_HOME/htdocs" "$APACHE_HOME/htdocs.backup"
                tar -xzf "$backup_dir/htdocs.tar.gz" -C "$APACHE_HOME/"
            fi
            ;;
    esac
    
    # Test configuration
    if "$APACHE_HOME/bin/httpd" -t; then
        log "Configuration test passed"
        # Graceful restart
        "$APACHE_HOME/bin/httpd" -k graceful
        log "Restore completed successfully"
    else
        log "ERROR: Configuration test failed, rolling back..."
        
        # Restore from safety backup
        if [ -d "$APACHE_HOME/conf.backup" ]; then
            rm -rf "$APACHE_HOME/conf"
            mv "$APACHE_HOME/conf.backup" "$APACHE_HOME/conf"
        fi
        
        if [ -d "$APACHE_HOME/htdocs.backup" ]; then
            rm -rf "$APACHE_HOME/htdocs"
            mv "$APACHE_HOME/htdocs.backup" "$APACHE_HOME/htdocs"
        fi
        
        exit 1
    fi
}

list_backups() {
    echo "Available backups:"
    echo "=================="
    
    for backup_dir in "$BACKUP_BASE_DIR"/*_[0-9]*; do
        if [ -d "$backup_dir" ] && [ -f "$backup_dir/manifest" ]; then
            source "$backup_dir/manifest"
            local size=$(du -sh "$backup_dir" | cut -f1)
            printf "%-20s %-10s %-15s %s\n" \
                   "$(basename $backup_dir)" \
                   "$backup_type" \
                   "$size" \
                   "$timestamp"
        fi
    done
}

cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days..."
    
    find "$BACKUP_BASE_DIR" -type d -name "*_[0-9]*" -mtime +$RETENTION_DAYS -exec rm -rf {} \;
    
    log "Cleanup completed"
}

verify_backup() {
    local backup_dir="$1"
    
    if [ ! -d "$backup_dir" ]; then
        echo "ERROR: Backup directory not found"
        return 1
    fi
    
    echo "Verifying backup: $backup_dir"
    
    # Check manifest
    if [ ! -f "$backup_dir/manifest" ]; then
        echo "❌ Missing manifest file"
        return 1
    fi
    
    source "$backup_dir/manifest"
    
    # Verify archives
    local status=0
    
    if [ -f "$backup_dir/htdocs.tar.gz" ]; then
        if tar -tzf "$backup_dir/htdocs.tar.gz" >/dev/null 2>&1; then
            echo "✅ htdocs.tar.gz - OK"
        else
            echo "❌ htdocs.tar.gz - CORRUPTED"
            status=1
        fi
    fi
    
    if [ -f "$backup_dir/conf.tar.gz" ]; then
        if tar -tzf "$backup_dir/conf.tar.gz" >/dev/null 2>&1; then
            echo "✅ conf.tar.gz - OK"
        else
            echo "❌ conf.tar.gz - CORRUPTED"
            status=1
        fi
    fi
    
    if [ -f "$backup_dir/logs.tar.gz" ]; then
        if tar -tzf "$backup_dir/logs.tar.gz" >/dev/null 2>&1; then
            echo "✅ logs.tar.gz - OK"
        else
            echo "❌ logs.tar.gz - CORRUPTED"
            status=1
        fi
    fi
    
    return $status
}

case "$1" in
    "create")
        backup_type="${2:-full}"
        create_backup "$backup_type"
        ;;
    "restore")
        restore_backup "$2"
        ;;
    "list")
        list_backups
        ;;
    "cleanup")
        cleanup_old_backups
        ;;
    "verify")
        verify_backup "$2"
        ;;
    *)
        echo "Usage: $0 {create|restore|list|cleanup|verify} [backup_type|backup_dir]"
        echo ""
        echo "Commands:"
        echo "  create [full|config|data]  - Create backup"
        echo "  restore <backup_dir>       - Restore from backup"
        echo "  list                       - List available backups"
        echo "  cleanup                    - Remove old backups"
        echo "  verify <backup_dir>        - Verify backup integrity"
        exit 1
        ;;
esac
