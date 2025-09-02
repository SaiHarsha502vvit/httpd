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
