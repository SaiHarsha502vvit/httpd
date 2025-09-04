## 🛠️ **ADVANCED LAB EXERCISES CONTINUED**

### **Lab 4.1: MPM Performance Analysis (45 minutes)**

```bash
# Check current MPM
/usr/local/apache2/bin/httpd -V | grep -i "server mpm"

# Check loaded modules
/usr/local/apache2/bin/httpd -M | grep mmp
```

#### **Step 1: Create MPM Test Configurations**

Create three configuration files for testing:

**Create the configs directory:**
```bash
mkdir -p /workspaces/httpd/lab_environment/configs
```

**prefork_test.conf:**
```apache
# Prefork MPM Configuration for Testing
ServerRoot "/usr/local/apache2"
Listen 8081
PidFile logs/httpd_prefork.pid

LoadModule mpm_prefork_module modules/mod_mpm_prefork.so
LoadModule authz_core_module modules/mod_authz_core.so
LoadModule dir_module modules/mod_dir.so
LoadModule mime_module modules/mod_mime.so

<IfModule mpm_prefork_module>
    StartServers             5
    MinSpareServers          5
    MaxSpareServers          10
    MaxRequestWorkers        150
    MaxConnectionsPerChild   1000
</IfModule>

DocumentRoot "/usr/local/apache2/htdocs"
DirectoryIndex index.html

<Directory "/usr/local/apache2/htdocs">
    AllowOverride None
    Require all granted
</Directory>

TypesConfig conf/mime.types
```

**worker_test.conf:**
```apache
# Worker MPM Configuration for Testing
ServerRoot "/usr/local/apache2"
Listen 8082
PidFile logs/httpd_worker.pid

LoadModule mpm_worker_module modules/mod_mpm_worker.so
LoadModule authz_core_module modules/mod_authz_core.so
LoadModule dir_module modules/mod_dir.so
LoadModule mime_module modules/mod_mime.so

<IfModule mpm_worker_module>
    StartServers             2
    MaxRequestWorkers        150
    MinSpareThreads          25
    MaxSpareThreads          75
    ThreadsPerChild          25
    MaxConnectionsPerChild   1000
</IfModule>

DocumentRoot "/usr/local/apache2/htdocs"
DirectoryIndex index.html

<Directory "/usr/local/apache2/htdocs">
    AllowOverride None
    Require all granted
</Directory>

TypesConfig conf/mime.types
```

**event_test.conf:**
```apache
# Event MPM Configuration for Testing
ServerRoot "/usr/local/apache2"
Listen 8083
PidFile logs/httpd_event.pid

LoadModule mpm_event_module modules/mod_mpm_event.so
LoadModule authz_core_module modules/mod_authz_core.so
LoadModule dir_module modules/mod_dir.so
LoadModule mime_module modules/mod_mime.so

<IfModule mpm_event_module>
    StartServers             2
    MaxRequestWorkers        150
    MinSpareThreads          25
    MaxSpareThreads          75
    ThreadsPerChild          25
    MaxConnectionsPerChild   1000
    AsyncRequestWorkerFactor 2
</IfModule>

DocumentRoot "/usr/local/apache2/htdocs"
DirectoryIndex index.html

<Directory "/usr/local/apache2/htdocs">
    AllowOverride None
    Require all granted
</Directory>

TypesConfig conf/mime.types
```

#### **Step 2: Performance Testing Script**

Create a comprehensive testing script:

```bash
#!/bin/bash
# mpm_performance_test.sh

echo "=== Apache MPM Performance Comparison ==="

# Install Apache Bench if not available
if ! command -v ab &> /dev/null; then
    echo "Installing Apache Bench..."
    sudo apt-get update && sudo apt-get install -y apache2-utils
fi

# Test each MPM configuration
for mpm in prefork worker event; do
    port=$((8080 + $(echo "prefork worker event" | tr ' ' '\n' | grep -n $mpm | cut -d: -f1)))
    
    echo -e "\n--- Testing $mpm MPM (port $port) ---"
    
    # Start Apache with specific MPM config
    /usr/local/apache2/bin/httpd -f /workspaces/httpd/lab_environment/configs/${mpm}_test.conf &
    apache_pid=$!
    sleep 3
    
    # Wait for Apache to start
    if ! curl -s http://localhost:$port > /dev/null; then
        echo "Failed to start Apache with $mpm MPM"
        kill $apache_pid 2>/dev/null
        continue
    fi
    
    echo "✅ Apache started successfully with $mpm MPM"
    
    # Memory usage before load
    echo "📊 Memory usage (before load):"
    ps aux | grep httpd | grep -v grep | awk '{sum+=$6} END {print "Total RSS: " sum/1024 " MB"}'
    
    # Process/thread count
    echo "🔢 Process count:"
    ps aux | grep httpd | grep -v grep | wc -l
    
    # Load testing with Apache Bench
    echo "⚡ Load testing (1000 requests, concurrency 50):"
    ab -n 1000 -c 50 -q http://localhost:$port/ 2>/dev/null | grep -E "Requests per second|Time per request|Failed requests"
    
    # Memory usage after load
    echo "📈 Memory usage (after load):"
    ps aux | grep httpd | grep -v grep | awk '{sum+=$6} END {print "Total RSS: " sum/1024 " MB"}'
    
    # Stop Apache
    kill $apache_pid
    wait $apache_pid 2>/dev/null
    sleep 2
    echo "🔄 Stopped $mpm MPM test"
done

echo -e "\n=== Test Complete ==="
```

### **Lab 4.2: Source Code Deep-Dive (90 minutes)**

#### **Understanding Apache's Request Processing Pipeline**

Let's examine the actual Apache source code to understand how requests flow through the system.

**Key Source Files to Analyze:**
1. `server/core.c` - Core request processing
2. `server/mpm/*/mpm.c` - Multi-processing modules
3. `server/protocol.c` - HTTP protocol handling
4. `modules/http/http_core.c` - HTTP-specific processing

Let's examine the core request processing:

```bash
# Navigate to Apache source
cd /workspaces/httpd

# Examine the main request processing function
grep -n "ap_process_request" server/core.c | head -5

# Look at the hook system
grep -A 10 "ap_run_translate_name" server/core.c

# Examine MPM differences
ls -la server/mpm/
```

**Request Processing Flow Analysis:**

```c
// From server/core.c - ap_process_request_internal()
AP_DECLARE(void) ap_process_request_internal(request_rec *r)
{
    int access_status;

    /* Phase 1: Location walk - determine configuration */
    if ((access_status = ap_location_walk(r))) {
        ap_die(access_status, r);
        return;
    }

    /* Phase 2: Header parsing and validation */
    if ((access_status = ap_process_request_internal(r))) {
        ap_die(access_status, r);
        return;
    }

    /* Phase 3: Run request hooks in order */
    if ((access_status = ap_run_translate_name(r))) {
        if (access_status == DECLINED) {
            /* No module handled translation, use default */
            access_status = ap_core_translate(r);
        }
        if (access_status != OK) {
            ap_die(access_status, r);
            return;
        }
    }

    /* Continue through all phases... */
}
```

**Hook System Analysis:**

Apache's modularity comes from its hook system. Let's trace how hooks work:

```c
// From include/ap_hooks.h
#define AP_IMPLEMENT_HOOK_RUN_ALL(ns,link,ret,name,args_decl,args_use,ok,decline) \
link##_DECLARE(ret) ns##_run_##name args_decl \
{ \
    ns##_LINK_##name##_t *pHook; \
    int rv; \
    \
    for(pHook=G_LINK_##ns##_##name;pHook;pHook=pHook->pNext) { \
        rv=pHook->pFunc args_use; \
        if(rv != ok && rv != decline) \
            return rv; \
    } \
    return ok; \
}
```

This macro creates functions that run through all registered hook functions for a particular phase.

#### **Memory Pool System Deep-Dive**

Apache's memory management uses APR pools:

```c
// From server/main.c - main()
int main(int argc, const char * const argv[])
{
    apr_pool_t *conf_pool;
    apr_pool_t *log_pool;
    apr_pool_t *temp_pool;

    /* Initialize APR */
    if (apr_app_initialize(&argc, &argv, NULL) != APR_SUCCESS) {
        ap_log_error(APLOG_MARK, APLOG_STARTUP|APLOG_ERR, 0, NULL, APLOGNO(00015)
                     "apr_app_initialize() failed. Exiting.");
        return 1;
    }

    /* Create the configuration pool */
    apr_pool_create(&conf_pool, NULL);
    apr_pool_tag(conf_pool, "conf");

    /* Pool cleanup is automatic - no malloc/free needed */
}
```

**Pool Hierarchy:**
```
Process Pool (never destroyed)
├── Configuration Pool (destroyed on restart)
│   ├── Server Pool (per virtual host)
│   └── Module Pools (per module)
└── Request Pool (destroyed after each request)
    ├── Connection Pool (per connection)
    └── Transaction Pools (per HTTP transaction)
```

### **Lab 4.3: Module Development Workshop (45 minutes)**

Let's create a custom Apache module to understand the architecture:

**hello_world_module.c:**
```c
#include "httpd.h"
#include "http_config.h"
#include "http_protocol.h"
#include "ap_config.h"
#include "apr_strings.h"

/* Module declaration */
module AP_MODULE_DECLARE_DATA hello_world_module;

/* Configuration structure */
typedef struct {
    int enabled;
    char *message;
} hello_world_config;

/* Configuration creation functions */
static void *create_hello_world_config(apr_pool_t *pool, char *path)
{
    hello_world_config *cfg = apr_pcalloc(pool, sizeof(hello_world_config));
    cfg->enabled = 0;
    cfg->message = "Hello, World!";
    return cfg;
}

/* Directive handlers */
static const char *set_hello_enabled(cmd_parms *cmd, void *cfg, int flag)
{
    hello_world_config *config = (hello_world_config *)cfg;
    config->enabled = flag;
    return NULL;
}

static const char *set_hello_message(cmd_parms *cmd, void *cfg, const char *arg)
{
    hello_world_config *config = (hello_world_config *)cfg;
    config->message = apr_pstrdup(cmd->pool, arg);
    return NULL;
}

/* Request handler */
static int hello_world_handler(request_rec *r)
{
    hello_world_config *cfg = ap_get_module_config(r->per_dir_config, 
                                                  &hello_world_module);
    
    if (!cfg->enabled) {
        return DECLINED;
    }
    
    /* Set content type */
    ap_set_content_type(r, "text/html");
    
    /* Send response */
    ap_rprintf(r, 
        "<!DOCTYPE html>\n"
        "<html><head><title>Apache Module Test</title></head>\n"
        "<body>\n"
        "<h1>%s</h1>\n"
        "<p>Request URI: %s</p>\n"
        "<p>Server: %s</p>\n"
        "<p>Current Time: %ld</p>\n"
        "</body></html>\n",
        cfg->message,
        r->uri,
        r->server->server_hostname,
        (long)apr_time_now()
    );
    
    return OK;
}

/* Configuration directives */
static const command_rec hello_world_directives[] = {
    AP_INIT_FLAG("HelloEnabled", set_hello_enabled, NULL, OR_ALL,
                 "Enable or disable hello world module"),
    AP_INIT_TAKE1("HelloMessage", set_hello_message, NULL, OR_ALL,
                  "Set the hello world message"),
    {NULL}
};

/* Hook registration */
static void hello_world_register_hooks(apr_pool_t *p)
{
    ap_hook_handler(hello_world_handler, NULL, NULL, APR_HOOK_MIDDLE);
}

/* Module definition */
module AP_MODULE_DECLARE_DATA hello_world_module = {
    STANDARD20_MODULE_STUFF,
    create_hello_world_config,    /* create per-dir config structures */
    NULL,                         /* merge per-directory config structures */
    NULL,                         /* create per-server config structures */
    NULL,                         /* merge per-server config structures */
    hello_world_directives,       /* table of config file commands */
    hello_world_register_hooks    /* register hooks */
};
```

**Module Compilation & Testing:**
```bash
# Create the module file
cat > /workspaces/httpd/hello_world_module.c << 'EOF'
[Module code from above]
EOF

# Try to compile the module (may not work in dev container, but educational)
/usr/local/apache2/bin/apxs -c hello_world_module.c

# If compilation works, install it
# /usr/local/apache2/bin/apxs -i -a hello_world_module.la
```

---

## 🏗️ **SECTION 5: APACHE ARCHITECTURE DEEP-DIVE (1 hour)**

### **5.1 Core Architecture Components**

#### **Apache Process Architecture Diagram**
```
Apache HTTP Server Architecture (2.4.x)

┌─────────────────────────────────────────────────────────────┐
│                    Parent Process                           │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │ Config Manager  │  │ Module Loader   │  │ Process Mgr  │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
│                           │                                 │
│                           ▼                                 │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Module Registry                            │ │
│  │  ┌───────────┐ ┌──────────────┐ ┌────────────────────┐  │ │
│  │  │ mod_core  │ │ mod_http     │ │ mod_ssl            │  │ │
│  │  │ mod_authz │ │ mod_rewrite  │ │ mod_proxy          │  │ │
│  │  │ mod_mime  │ │ mod_headers  │ │ [150+ modules]     │  │ │
│  │  └───────────┘ └──────────────┘ └────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Child Processes (MPM)                    │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ Worker 1    │    │ Worker 2    │    │ Worker N    │     │
│  │             │    │             │    │             │     │
│  │ Request     │    │ Request     │    │ Request     │     │
│  │ Processing  │    │ Processing  │    │ Processing  │     │
│  │ Pipeline    │    │ Pipeline    │    │ Pipeline    │     │
│  │             │    │             │    │             │     │
│  │ ┌─────────┐ │    │ ┌─────────┐ │    │ ┌─────────┐ │     │
│  │ │ HTTP    │ │    │ │ HTTP    │ │    │ │ HTTP    │ │     │
│  │ │ Parser  │ │    │ │ Parser  │ │    │ │ Parser  │ │     │
│  │ └─────────┘ │    │ └─────────┘ │    │ └─────────┘ │     │
│  │ ┌─────────┐ │    │ ┌─────────┐ │    │ ┌─────────┐ │     │
│  │ │ Module  │ │    │ │ Module  │ │    │ │ Module  │ │     │
│  │ │ Chain   │ │    │ │ Chain   │ │    │ │ Chain   │ │     │
│  │ └─────────┘ │    │ └─────────┘ │    │ └─────────┘ │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

### **5.2 Request Processing Phases**

Apache processes every HTTP request through exactly **11 phases**:

```c
// From server/request.c - Phase constants
typedef enum {
    AP_PHASE_TRANSLATE_NAME,     /* translate URL to filename */
    AP_PHASE_CHECK_USER_ID,      /* check username/password */
    AP_PHASE_AUTH,               /* check authorization */
    AP_PHASE_ACCESS_CHECKER,     /* check access by host, etc */
    AP_PHASE_CHECK_TYPE,         /* check/set content type */
    AP_PHASE_FIXUPS,            /* last chance for modules */
    AP_PHASE_INSERT_FILTER,     /* insert filters */
    AP_PHASE_HANDLER,           /* generate content */
    AP_PHASE_LOG_TRANSACTION,   /* log the transaction */
    AP_PHASE_CLEANUP,           /* cleanup */
    AP_PHASE_CHILD_INIT         /* child initialization */
} ap_phase_t;
```

**Detailed Phase Analysis:**

**Phase 1: URI Translation**
```c
// Example: mod_rewrite in action
static int rewrite_translate_name(request_rec *r)
{
    rewrite_perdir_conf *dconf = ap_get_module_config(r->per_dir_config, 
                                                     &rewrite_module);
    
    /* Apply rewrite rules */
    if (apply_rewrite_rules(r, dconf->rules) == ACTION_STATUS) {
        return DECLINED;
    }
    
    /* URL was rewritten, set new filename */
    r->filename = apr_pstrcat(r->pool, document_root, r->uri, NULL);
    return OK;
}
```

**Phase 2-3: Authentication & Authorization**
```c
// Example: Basic authentication flow
static int basic_auth_check_user_id(request_rec *r)
{
    const char *auth_line = apr_table_get(r->headers_in, "Authorization");
    
    if (!auth_line || strncmp(auth_line, "Basic ", 6)) {
        /* No authentication provided */
        return HTTP_UNAUTHORIZED;
    }
    
    /* Decode base64 credentials */
    char *decoded = ap_pbase64decode(r->pool, auth_line + 6);
    char *username = decoded;
    char *password = strchr(decoded, ':');
    
    if (password) {
        *password++ = '\0';
        
        /* Verify against user database */
        if (verify_user_password(username, password)) {
            r->user = apr_pstrdup(r->pool, username);
            return OK;
        }
    }
    
    return HTTP_UNAUTHORIZED;
}
```

### **5.3 Memory Management Architecture**

#### **APR Pool System Deep Analysis**

Apache's memory management is built on APR (Apache Portable Runtime) pools:

```c
// Pool creation hierarchy
struct apr_pool_t {
    apr_pool_t *parent;           /* Parent pool */
    apr_pool_t *child;            /* First child pool */
    apr_pool_t *sibling;          /* Next sibling pool */
    
    const char **cleanups;        /* Cleanup functions */
    apr_allocator_t *allocator;   /* Memory allocator */
    
    char *first_avail;            /* First available byte */
    char *endp;                   /* End of available memory */
};
```

**Memory Allocation Strategy:**
```c
// Fast allocation from pool
APR_DECLARE(void *) apr_palloc(apr_pool_t *pool, apr_size_t size)
{
    void *mem;
    
    /* Align size to machine word boundary */
    size = APR_ALIGN_DEFAULT(size);
    
    if (size < MAX_INDEX) {
        /* Use pool's free list for small allocations */
        mem = pool->free_list[FREELIST_IDX(size)];
        if (mem) {
            pool->free_list[FREELIST_IDX(size)] = *(void **)mem;
            return mem;
        }
    }
    
    /* Allocate from pool's current block */
    if ((pool->first_avail + size) <= pool->endp) {
        mem = pool->first_avail;
        pool->first_avail += size;
        return mem;
    }
    
    /* Need new memory block */
    return new_block(pool, size);
}
```

**Why Pools Matter:**
1. **No memory leaks** - automatic cleanup when pool destroyed
2. **Fast allocation** - no malloc/free overhead
3. **Cache locality** - related data stored together
4. **Thread safety** - each thread has own pools
