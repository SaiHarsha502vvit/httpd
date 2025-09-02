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
