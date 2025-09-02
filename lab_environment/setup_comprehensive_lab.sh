#!/bin/bash
# setup_comprehensive_lab.sh - Complete hands-on lab environment setup

set -e

echo "=== Setting up Complete Multi-Role IT Professional Lab ==="

# Variables
APACHE_HOME="/usr/local/apache2"
LAB_DIR="/workspaces/httpd/lab_environment"
WEB_ROOT="$APACHE_HOME/htdocs"

# Create lab directory structure
echo "[+] Creating lab directory structure..."
mkdir -p "$LAB_DIR"/{security,monitoring,automation,backup,configs,logs,scripts,certs}

# 1. SECURITY LAB SETUP
echo "[+] Setting up Security Lab..."

# Create security configuration
cat > "$LAB_DIR/security/security.conf" << 'EOF'
# Advanced Apache Security Configuration
# Load required modules
LoadModule headers_module modules/mod_headers.so
LoadModule rewrite_module modules/mod_rewrite.so
LoadModule ssl_module modules/mod_ssl.so

# Hide server information
ServerTokens Prod
ServerSignature Off

# Security headers
Header always set X-Frame-Options DENY
Header always set X-Content-Type-Options nosniff
Header always set X-XSS-Protection "1; mode=block"
Header always set Referrer-Policy "strict-origin-when-cross-origin"
Header always set Permissions-Policy "geolocation=(), microphone=(), camera=()"

# Content Security Policy
Header always set Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:;"

# Remove ETag headers (information disclosure)
Header unset ETag
FileETag None

# Clickjacking protection
Header always append X-Frame-Options SAMEORIGIN

# Rate limiting with mod_evasive (if available)
<IfModule mod_evasive24.c>
    DOSHashTableSize    512
    DOSPageCount        3
    DOSPageInterval     1
    DOSSiteCount        50
    DOSSiteInterval     1
    DOSBlockingPeriod   600
</IfModule>

# Hide sensitive files
<FilesMatch "^\.">
    Require all denied
</FilesMatch>

<FilesMatch "\.(bak|config|sql|fla|psd|ini|log|sh|inc|swp|dist)$">
    Require all denied
</FilesMatch>

# Directory browsing protection
Options -Indexes

# Disable dangerous HTTP methods
<LimitExcept GET POST HEAD>
    Require all denied
</LimitExcept>

# Server status protection
<Location "/server-status">
    Require local
    Require ip 127.0.0.1
</Location>

<Location "/server-info">
    Require local
    Require ip 127.0.0.1
</Location>
EOF

# 2. MONITORING LAB SETUP
echo "[+] Setting up Monitoring Lab..."

# Create monitoring scripts
cat > "$LAB_DIR/monitoring/system_monitor.py" << 'EOF'
#!/usr/bin/env python3
"""
System Monitoring Script for Apache and System Resources
"""

import psutil
import time
import json
import subprocess
import os
from datetime import datetime

class SystemMonitor:
    def __init__(self):
        self.apache_pid_file = "/usr/local/apache2/logs/httpd.pid"
        self.apache_access_log = "/usr/local/apache2/logs/access_log"
        self.apache_error_log = "/usr/local/apache2/logs/error_log"
    
    def get_system_metrics(self):
        """Get system resource metrics"""
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        network = psutil.net_io_counters()
        
        return {
            'timestamp': datetime.now().isoformat(),
            'cpu_percent': cpu_percent,
            'memory': {
                'total': memory.total,
                'available': memory.available,
                'percent': memory.percent,
                'used': memory.used
            },
            'disk': {
                'total': disk.total,
                'used': disk.used,
                'free': disk.free,
                'percent': (disk.used / disk.total) * 100
            },
            'network': {
                'bytes_sent': network.bytes_sent,
                'bytes_recv': network.bytes_recv,
                'packets_sent': network.packets_sent,
                'packets_recv': network.packets_recv
            }
        }
    
    def get_apache_metrics(self):
        """Get Apache-specific metrics"""
        metrics = {
            'timestamp': datetime.now().isoformat(),
            'status': 'unknown',
            'processes': 0,
            'connections': 0,
            'recent_requests': 0,
            'recent_errors': 0
        }
        
        try:
            # Check if Apache is running
            if os.path.exists(self.apache_pid_file):
                with open(self.apache_pid_file) as f:
                    pid = int(f.read().strip())
                if psutil.pid_exists(pid):
                    metrics['status'] = 'running'
                    
                    # Count Apache processes
                    apache_processes = [p for p in psutil.process_iter(['pid', 'name']) 
                                      if p.info['name'] == 'httpd']
                    metrics['processes'] = len(apache_processes)
                    
                    # Count active connections
                    result = subprocess.run(['netstat', '-an'], capture_output=True, text=True)
                    connections = len([line for line in result.stdout.split('\n') 
                                     if ':8080' in line and 'ESTABLISHED' in line])
                    metrics['connections'] = connections
            else:
                metrics['status'] = 'stopped'
            
            # Recent requests (last minute)
            if os.path.exists(self.apache_access_log):
                result = subprocess.run([
                    'tail', '-n', '1000', self.apache_access_log
                ], capture_output=True, text=True)
                
                current_time = time.time()
                recent_requests = 0
                
                for line in result.stdout.split('\n'):
                    if line.strip():
                        try:
                            # Basic parsing - in production, use proper log parsing
                            parts = line.split()
                            if len(parts) > 3:
                                # This is a simplified timestamp parsing
                                recent_requests += 1
                        except:
                            continue
                
                metrics['recent_requests'] = recent_requests
            
            # Recent errors
            if os.path.exists(self.apache_error_log):
                result = subprocess.run([
                    'tail', '-n', '100', self.apache_error_log
                ], capture_output=True, text=True)
                
                error_lines = [line for line in result.stdout.split('\n') 
                              if 'error' in line.lower()]
                metrics['recent_errors'] = len(error_lines)
        
        except Exception as e:
            print(f"Error getting Apache metrics: {e}")
        
        return metrics
    
    def generate_report(self):
        """Generate comprehensive monitoring report"""
        system_metrics = self.get_system_metrics()
        apache_metrics = self.get_apache_metrics()
        
        report = {
            'timestamp': datetime.now().isoformat(),
            'system': system_metrics,
            'apache': apache_metrics,
            'alerts': []
        }
        
        # Generate alerts based on thresholds
        if system_metrics['cpu_percent'] > 80:
            report['alerts'].append({
                'level': 'WARNING',
                'component': 'system',
                'message': f"High CPU usage: {system_metrics['cpu_percent']:.1f}%"
            })
        
        if system_metrics['memory']['percent'] > 90:
            report['alerts'].append({
                'level': 'CRITICAL',
                'component': 'system',
                'message': f"High memory usage: {system_metrics['memory']['percent']:.1f}%"
            })
        
        if system_metrics['disk']['percent'] > 85:
            report['alerts'].append({
                'level': 'WARNING',
                'component': 'system',
                'message': f"High disk usage: {system_metrics['disk']['percent']:.1f}%"
            })
        
        if apache_metrics['status'] != 'running':
            report['alerts'].append({
                'level': 'CRITICAL',
                'component': 'apache',
                'message': "Apache is not running"
            })
        
        if apache_metrics['recent_errors'] > 5:
            report['alerts'].append({
                'level': 'WARNING',
                'component': 'apache',
                'message': f"High error rate: {apache_metrics['recent_errors']} errors recently"
            })
        
        return report
    
    def save_metrics(self, report, filename):
        """Save metrics to file"""
        with open(filename, 'a') as f:
            f.write(json.dumps(report) + '\n')
    
    def display_dashboard(self, report):
        """Display monitoring dashboard in terminal"""
        print("\033[2J\033[H")  # Clear screen
        print("=" * 60)
        print(f"SYSTEM MONITORING DASHBOARD - {report['timestamp']}")
        print("=" * 60)
        
        # System metrics
        print(f"\n📊 SYSTEM METRICS:")
        print(f"CPU Usage:    {report['system']['cpu_percent']:6.1f}%")
        print(f"Memory Usage: {report['system']['memory']['percent']:6.1f}%")
        print(f"Disk Usage:   {report['system']['disk']['percent']:6.1f}%")
        
        # Apache metrics
        print(f"\n🌐 APACHE METRICS:")
        print(f"Status:       {report['apache']['status']:>10}")
        print(f"Processes:    {report['apache']['processes']:>10}")
        print(f"Connections:  {report['apache']['connections']:>10}")
        print(f"Recent Req:   {report['apache']['recent_requests']:>10}")
        print(f"Recent Err:   {report['apache']['recent_errors']:>10}")
        
        # Alerts
        if report['alerts']:
            print(f"\n🚨 ALERTS ({len(report['alerts'])}):")
            for alert in report['alerts']:
                level_icon = "🔴" if alert['level'] == 'CRITICAL' else "🟡"
                print(f"  {level_icon} {alert['level']}: {alert['message']}")
        else:
            print(f"\n✅ NO ALERTS - System running normally")
        
        print("\nPress Ctrl+C to stop monitoring...")

if __name__ == "__main__":
    monitor = SystemMonitor()
    metrics_file = "/workspaces/httpd/lab_environment/logs/system_metrics.jsonl"
    
    try:
        while True:
            report = monitor.generate_report()
            monitor.display_dashboard(report)
            monitor.save_metrics(report, metrics_file)
            time.sleep(5)
    except KeyboardInterrupt:
        print("\nMonitoring stopped.")
EOF

chmod +x "$LAB_DIR/monitoring/system_monitor.py"

# 3. AUTOMATION LAB SETUP
echo "[+] Setting up Automation Lab..."

# Create automation scripts
cat > "$LAB_DIR/automation/deploy_script.sh" << 'EOF'
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
EOF

chmod +x "$LAB_DIR/automation/deploy_script.sh"

# 4. BACKUP LAB SETUP
echo "[+] Setting up Backup Lab..."

cat > "$LAB_DIR/backup/backup_manager.sh" << 'EOF'
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
EOF

chmod +x "$LAB_DIR/backup/backup_manager.sh"

# 5. CREATE SAMPLE WEB APPLICATIONS
echo "[+] Creating sample web applications..."

# Create a vulnerability testing lab
mkdir -p "$WEB_ROOT/security-lab"

cat > "$WEB_ROOT/security-lab/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Security Testing Lab</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .warning { background: #fff3cd; border: 1px solid #ffeaa7; padding: 20px; border-radius: 5px; }
        .lab-section { margin: 20px 0; padding: 20px; border: 1px solid #ddd; border-radius: 5px; }
        .vulnerable { background: #f8d7da; }
        .secure { background: #d4edda; }
    </style>
</head>
<body>
    <h1>🛡️ Security Testing Laboratory</h1>
    
    <div class="warning">
        <h3>⚠️ Warning</h3>
        <p>This is a controlled security testing environment. These examples contain intentional vulnerabilities for educational purposes only. Never deploy these examples in production!</p>
    </div>
    
    <div class="lab-section vulnerable">
        <h3>🔴 Vulnerable Examples (For Testing)</h3>
        
        <h4>1. Cross-Site Scripting (XSS)</h4>
        <form action="xss-test.php" method="GET">
            <input type="text" name="input" placeholder="Enter some text">
            <button type="submit">Submit</button>
        </form>
        <p><small>Try: &lt;script&gt;alert('XSS')&lt;/script&gt;</small></p>
        
        <h4>2. SQL Injection Test</h4>
        <form action="sql-test.php" method="GET">
            <input type="text" name="id" placeholder="User ID">
            <button type="submit">Search</button>
        </form>
        <p><small>Try: 1' OR '1'='1</small></p>
        
        <h4>3. Directory Traversal</h4>
        <form action="file-read.php" method="GET">
            <input type="text" name="file" placeholder="Filename">
            <button type="submit">Read File</button>
        </form>
        <p><small>Try: ../../../etc/passwd</small></p>
    </div>
    
    <div class="lab-section secure">
        <h3>🟢 Secure Examples (Best Practices)</h3>
        
        <h4>1. Input Validation</h4>
        <form action="secure-form.php" method="POST">
            <input type="text" name="username" placeholder="Username" required pattern="[a-zA-Z0-9_]{3,20}">
            <input type="email" name="email" placeholder="Email" required>
            <button type="submit">Submit Securely</button>
        </form>
        
        <h4>2. CSRF Protection</h4>
        <form action="csrf-protected.php" method="POST">
            <input type="hidden" name="csrf_token" value="<?php echo bin2hex(random_bytes(32)); ?>">
            <input type="text" name="data" placeholder="Protected data">
            <button type="submit">Submit with CSRF Token</button>
        </form>
    </div>
    
    <div class="lab-section">
        <h3>📊 Security Testing Tools</h3>
        <ul>
            <li><strong>OWASP ZAP:</strong> Web application security scanner</li>
            <li><strong>Burp Suite:</strong> Web vulnerability scanner</li>
            <li><strong>Nikto:</strong> Web server scanner</li>
            <li><strong>SQLmap:</strong> SQL injection testing tool</li>
            <li><strong>XSStrike:</strong> XSS detection suite</li>
        </ul>
    </div>
    
    <div class="lab-section">
        <h3>🔧 Manual Testing Checklist</h3>
        <ul>
            <li>Test input validation on all forms</li>
            <li>Check for XSS vulnerabilities</li>
            <li>Test for SQL injection</li>
            <li>Verify authentication and authorization</li>
            <li>Check session management</li>
            <li>Test file upload functionality</li>
            <li>Verify HTTPS implementation</li>
            <li>Check security headers</li>
        </ul>
    </div>
</body>
</html>
EOF

# Create a monitoring dashboard
cat > "$WEB_ROOT/monitoring-dashboard.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>System Monitoring Dashboard</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .dashboard { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .card h3 { margin-top: 0; color: #333; }
        .metric { display: flex; justify-content: space-between; margin: 10px 0; }
        .metric-value { font-weight: bold; }
        .status-good { color: #28a745; }
        .status-warning { color: #ffc107; }
        .status-critical { color: #dc3545; }
        .progress-bar { width: 100%; height: 20px; background: #e9ecef; border-radius: 10px; overflow: hidden; }
        .progress-fill { height: 100%; background: linear-gradient(90deg, #28a745, #ffc107, #dc3545); transition: width 0.3s; }
        #refresh-btn { background: #007bff; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer; }
        #refresh-btn:hover { background: #0056b3; }
    </style>
</head>
<body>
    <h1>📊 System Monitoring Dashboard</h1>
    <button id="refresh-btn" onclick="refreshData()">🔄 Refresh Data</button>
    
    <div class="dashboard">
        <div class="card">
            <h3>🖥️ System Resources</h3>
            <div class="metric">
                <span>CPU Usage:</span>
                <span class="metric-value" id="cpu-usage">Loading...</span>
            </div>
            <div class="progress-bar">
                <div class="progress-fill" id="cpu-progress" style="width: 0%"></div>
            </div>
            
            <div class="metric">
                <span>Memory Usage:</span>
                <span class="metric-value" id="memory-usage">Loading...</span>
            </div>
            <div class="progress-bar">
                <div class="progress-fill" id="memory-progress" style="width: 0%"></div>
            </div>
            
            <div class="metric">
                <span>Disk Usage:</span>
                <span class="metric-value" id="disk-usage">Loading...</span>
            </div>
            <div class="progress-bar">
                <div class="progress-fill" id="disk-progress" style="width: 0%"></div>
            </div>
        </div>
        
        <div class="card">
            <h3>🌐 Apache Status</h3>
            <div class="metric">
                <span>Status:</span>
                <span class="metric-value" id="apache-status">Loading...</span>
            </div>
            <div class="metric">
                <span>Active Connections:</span>
                <span class="metric-value" id="apache-connections">Loading...</span>
            </div>
            <div class="metric">
                <span>Processes:</span>
                <span class="metric-value" id="apache-processes">Loading...</span>
            </div>
            <div class="metric">
                <span>Uptime:</span>
                <span class="metric-value" id="apache-uptime">Loading...</span>
            </div>
        </div>
        
        <div class="card">
            <h3>🔒 Security Status</h3>
            <div class="metric">
                <span>SSL Status:</span>
                <span class="metric-value" id="ssl-status">Loading...</span>
            </div>
            <div class="metric">
                <span>Failed Login Attempts:</span>
                <span class="metric-value" id="failed-logins">Loading...</span>
            </div>
            <div class="metric">
                <span>Blocked IPs:</span>
                <span class="metric-value" id="blocked-ips">Loading...</span>
            </div>
            <div class="metric">
                <span>Last Security Scan:</span>
                <span class="metric-value" id="last-scan">Loading...</span>
            </div>
        </div>
        
        <div class="card">
            <h3>📈 Performance Metrics</h3>
            <div class="metric">
                <span>Requests/sec:</span>
                <span class="metric-value" id="requests-per-sec">Loading...</span>
            </div>
            <div class="metric">
                <span>Average Response Time:</span>
                <span class="metric-value" id="avg-response-time">Loading...</span>
            </div>
            <div class="metric">
                <span>Error Rate:</span>
                <span class="metric-value" id="error-rate">Loading...</span>
            </div>
            <div class="metric">
                <span>Cache Hit Rate:</span>
                <span class="metric-value" id="cache-hit-rate">Loading...</span>
            </div>
        </div>
    </div>
    
    <script>
        function refreshData() {
            // Simulate data fetching - replace with actual API calls
            document.getElementById('cpu-usage').textContent = (Math.random() * 100).toFixed(1) + '%';
            document.getElementById('memory-usage').textContent = (Math.random() * 100).toFixed(1) + '%';
            document.getElementById('disk-usage').textContent = (Math.random() * 100).toFixed(1) + '%';
            
            document.getElementById('apache-status').textContent = 'Running';
            document.getElementById('apache-status').className = 'metric-value status-good';
            
            document.getElementById('apache-connections').textContent = Math.floor(Math.random() * 50);
            document.getElementById('apache-processes').textContent = '4';
            document.getElementById('apache-uptime').textContent = '2 days, 14:32:15';
            
            // Update progress bars
            const cpuPercent = parseFloat(document.getElementById('cpu-usage').textContent);
            document.getElementById('cpu-progress').style.width = cpuPercent + '%';
            
            const memoryPercent = parseFloat(document.getElementById('memory-usage').textContent);
            document.getElementById('memory-progress').style.width = memoryPercent + '%';
            
            const diskPercent = parseFloat(document.getElementById('disk-usage').textContent);
            document.getElementById('disk-progress').style.width = diskPercent + '%';
        }
        
        // Auto-refresh every 30 seconds
        setInterval(refreshData, 30000);
        
        // Initial load
        refreshData();
    </script>
</body>
</html>
EOF

# 6. CREATE DOCUMENTATION
echo "[+] Creating lab documentation..."

cat > "$LAB_DIR/README.md" << 'EOF'
# Multi-Role IT Professional Lab Environment

This lab environment provides hands-on experience with:

## 🔧 Lab Components

### 1. Security Lab (`/security-lab/`)
- **Purpose**: Practice web application security testing
- **Location**: http://localhost:8080/security-lab/
- **Features**: 
  - Intentional vulnerabilities for testing
  - Security scanning practice
  - Secure coding examples

### 2. Monitoring Dashboard
- **Purpose**: System and application monitoring
- **Location**: http://localhost:8080/monitoring-dashboard.html
- **Script**: `monitoring/system_monitor.py`
- **Usage**: 
  ```bash
  python3 /workspaces/httpd/lab_environment/monitoring/system_monitor.py
  ```

### 3. Automation Tools
- **Deployment Script**: `automation/deploy_script.sh`
- **Usage**:
  ```bash
  # Deploy new content
  ./automation/deploy_script.sh /path/to/source deploy
  
  # Rollback deployment
  ./automation/deploy_script.sh /path/to/source rollback
  
  # Test deployment
  ./automation/deploy_script.sh /path/to/source test
  ```

### 4. Backup Management
- **Script**: `backup/backup_manager.sh`
- **Usage**:
  ```bash
  # Create full backup
  ./backup/backup_manager.sh create full
  
  # List backups
  ./backup/backup_manager.sh list
  
  # Restore backup
  ./backup/backup_manager.sh restore /path/to/backup
  
  # Verify backup
  ./backup/backup_manager.sh verify /path/to/backup
  ```

## 🚀 Getting Started

1. **Start Apache** (if not running):
   ```bash
   sudo /usr/local/apache2/bin/httpd -k start
   ```

2. **Apply Security Configuration**:
   ```bash
   sudo cp security/security.conf /usr/local/apache2/conf/extra/
   echo "Include conf/extra/security.conf" | sudo tee -a /usr/local/apache2/conf/httpd.conf
   sudo /usr/local/apache2/bin/httpd -k graceful
   ```

3. **Start Monitoring**:
   ```bash
   python3 monitoring/system_monitor.py
   ```

4. **Create Your First Backup**:
   ```bash
   ./backup/backup_manager.sh create full
   ```

## 📚 Learning Exercises

### Exercise 1: Security Testing
1. Navigate to http://localhost:8080/security-lab/
2. Test each vulnerability example
3. Use tools like `curl`, `nikto`, or browser dev tools
4. Document findings and remediation steps

### Exercise 2: System Monitoring
1. Run the monitoring script
2. Generate load on the system
3. Observe metric changes
4. Set up alerting thresholds

### Exercise 3: Deployment Automation
1. Create a simple web page
2. Use the deployment script to deploy it
3. Test the rollback functionality
4. Modify the script to add new features

### Exercise 4: Backup and Recovery
1. Create different types of backups
2. Simulate a system failure
3. Practice recovery procedures
4. Verify backup integrity

## 🔍 Advanced Challenges

1. **Implement SSL/TLS**:
   - Generate self-signed certificates
   - Configure HTTPS
   - Test SSL configuration

2. **Set up Load Balancing**:
   - Configure multiple Apache instances
   - Implement load balancing
   - Test failover scenarios

3. **Database Integration**:
   - Install and configure MySQL/PostgreSQL
   - Create web applications with database backends
   - Implement backup strategies for databases

4. **Container Deployment**:
   - Create Docker images for the lab environment
   - Set up Kubernetes deployment
   - Implement CI/CD pipelines

## 📖 Additional Resources

- [OWASP Web Security Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)
- [Apache HTTP Server Documentation](https://httpd.apache.org/docs/)
- [Linux System Administration Guide](https://tldp.org/LDP/sag/html/)
- [DevOps Best Practices](https://devops.com/best-practices/)

## 🛠️ Tools to Install

```bash
# Security tools
sudo apt update
sudo apt install -y nmap nikto dirb gobuster sqlmap

# Monitoring tools
pip3 install psutil requests beautifulsoup4

# Development tools
sudo apt install -y git curl wget jq
```
EOF

# 7. SET PERMISSIONS
echo "[+] Setting proper permissions..."
chown -R $(whoami):$(whoami) "$LAB_DIR"
chmod -R 755 "$LAB_DIR"
chmod +x "$LAB_DIR"/{automation,backup,monitoring}/*.{sh,py}

echo ""
echo "=========================================="
echo "🎉 LAB ENVIRONMENT SETUP COMPLETE!"
echo "=========================================="
echo ""
echo "📍 Lab Location: $LAB_DIR"
echo "🌐 Security Lab: http://localhost:8080/security-lab/"
echo "📊 Monitoring: http://localhost:8080/monitoring-dashboard.html"
echo ""
echo "🚀 Quick Start Commands:"
echo "  Monitor System: python3 $LAB_DIR/monitoring/system_monitor.py"
echo "  Create Backup:  $LAB_DIR/backup/backup_manager.sh create full"
echo "  Security Scan:  nikto -h http://localhost:8080"
echo ""
echo "📚 Read the full documentation: $LAB_DIR/README.md"
echo ""
EOF

chmod +x /workspaces/httpd/lab_environment/setup_comprehensive_lab.sh
