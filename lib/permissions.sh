#!/bin/bash

# =============================================================================
# Permissions Library for pgctl
# =============================================================================
# Functions for granting, revoking, and auditing database permissions
# Compatible with bash 3.x (macOS default)
# =============================================================================

# Prevent multiple sourcing
[[ -n "${PGCTL_PERMISSIONS_LOADED:-}" ]] && return
PGCTL_PERMISSIONS_LOADED=1

# Source common library
_PERMISSIONS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_PERMISSIONS_DIR}/common.sh"

# =============================================================================
# Permission Definitions (bash 3.x compatible)
# =============================================================================

# Get table permissions for a role type
get_table_permissions() {
    local role_type="$1"
    case "$role_type" in
        owner)           echo "ALL" ;;
        migration_user)  echo "ALL" ;;
        fullaccess_user) echo "SELECT, INSERT, UPDATE, DELETE" ;;
        app_user)        echo "SELECT, INSERT, UPDATE" ;;
        readonly_user)   echo "SELECT" ;;
        *)               echo "" ;;
    esac
}

# Get sequence permissions for a role type
get_sequence_permissions() {
    local role_type="$1"
    case "$role_type" in
        owner)           echo "ALL" ;;
        migration_user)  echo "ALL" ;;
        fullaccess_user) echo "USAGE, SELECT" ;;
        app_user)        echo "USAGE, SELECT" ;;
        readonly_user)   echo "SELECT" ;;
        *)               echo "" ;;
    esac
}

# Get function permissions for a role type
get_function_permissions() {
    local role_type="$1"
    case "$role_type" in
        owner)           echo "ALL" ;;
        migration_user)  echo "ALL" ;;
        fullaccess_user) echo "EXECUTE" ;;
        app_user)        echo "EXECUTE" ;;
        readonly_user)   echo "EXECUTE" ;;
        *)               echo "" ;;
    esac
}

# Get schema permissions for a role type
get_schema_permissions() {
    local role_type="$1"
    case "$role_type" in
        owner)           echo "ALL" ;;
        migration_user)  echo "CREATE, USAGE" ;;
        fullaccess_user) echo "USAGE" ;;
        app_user)        echo "USAGE" ;;
        readonly_user)   echo "USAGE" ;;
        *)               echo "" ;;
    esac
}

# =============================================================================
# Permission Grant Functions
# =============================================================================

# Grant table permissions to a user
grant_table_permissions() {
    local dbname="$1"
    local username="$2"
    local role_type="$3"  # owner, migration_user, fullaccess_user, app_user, readonly_user
    local schema="${4:-public}"
    
    local permissions
    permissions=$(get_table_permissions "$role_type")
    
    if [[ -z "$permissions" ]]; then
        log_error "Unknown role type: $role_type"
        return 1
    fi
    
    local sql="GRANT $permissions ON ALL TABLES IN SCHEMA $schema TO $username;"
    
    if psql_admin_quiet "$sql" "$dbname"; then
        return 0
    else
        log_error "Failed to grant table permissions to $username"
        return 1
    fi
}

# Grant sequence permissions to a user
grant_sequence_permissions() {
    local dbname="$1"
    local username="$2"
    local role_type="$3"
    local schema="${4:-public}"
    
    local permissions
    permissions=$(get_sequence_permissions "$role_type")
    
    if [[ -z "$permissions" ]]; then
        log_error "Unknown role type: $role_type"
        return 1
    fi
    
    local sql="GRANT $permissions ON ALL SEQUENCES IN SCHEMA $schema TO $username;"
    
    if psql_admin_quiet "$sql" "$dbname"; then
        return 0
    else
        log_error "Failed to grant sequence permissions to $username"
        return 1
    fi
}

# Grant function permissions to a user
grant_function_permissions() {
    local dbname="$1"
    local username="$2"
    local role_type="$3"
    local schema="${4:-public}"
    
    local permissions
    permissions=$(get_function_permissions "$role_type")
    
    if [[ -z "$permissions" ]]; then
        log_error "Unknown role type: $role_type"
        return 1
    fi
    
    local sql="GRANT $permissions ON ALL FUNCTIONS IN SCHEMA $schema TO $username;"
    
    if psql_admin_quiet "$sql" "$dbname"; then
        return 0
    else
        log_error "Failed to grant function permissions to $username"
        return 1
    fi
}

# Grant schema permissions to a user
grant_schema_permissions() {
    local dbname="$1"
    local username="$2"
    local role_type="$3"
    local schema="${4:-public}"
    
    local permissions
    permissions=$(get_schema_permissions "$role_type")
    
    if [[ -z "$permissions" ]]; then
        log_error "Unknown role type: $role_type"
        return 1
    fi
    
    local sql="GRANT $permissions ON SCHEMA $schema TO $username;"
    
    if psql_admin_quiet "$sql" "$dbname"; then
        return 0
    else
        log_error "Failed to grant schema permissions to $username"
        return 1
    fi
}

# Grant all permissions for a role type
grant_all_permissions() {
    local dbname="$1"
    local username="$2"
    local role_type="$3"
    local schema="${4:-public}"
    
    log_info "Granting $role_type permissions to $username..."
    
    # Schema permissions
    echo "  → Schema access..."
    grant_schema_permissions "$dbname" "$username" "$role_type" "$schema" || return 1
    
    # Table permissions
    echo "  → Table permissions..."
    grant_table_permissions "$dbname" "$username" "$role_type" "$schema" || return 1
    
    # Sequence permissions
    echo "  → Sequence permissions..."
    grant_sequence_permissions "$dbname" "$username" "$role_type" "$schema" || return 1
    
    # Function permissions
    echo "  → Function permissions..."
    grant_function_permissions "$dbname" "$username" "$role_type" "$schema" || return 1
    
    log_success "All permissions granted to $username"
    return 0
}

# =============================================================================
# Default Privileges Functions
# =============================================================================

# Set default privileges for a user (for future objects)
set_default_privileges() {
    local dbname="$1"
    local grantor="$2"  # User who creates objects (usually migration_user or owner)
    local grantee="$3"  # User who receives permissions
    local role_type="$4"
    local schema="${5:-public}"
    
    local table_perms
    table_perms=$(get_table_permissions "$role_type")
    local seq_perms
    seq_perms=$(get_sequence_permissions "$role_type")
    local func_perms
    func_perms=$(get_function_permissions "$role_type")
    
    # Default privileges for tables
    local sql1="ALTER DEFAULT PRIVILEGES FOR ROLE $grantor IN SCHEMA $schema GRANT $table_perms ON TABLES TO $grantee;"
    
    # Default privileges for sequences
    local sql2="ALTER DEFAULT PRIVILEGES FOR ROLE $grantor IN SCHEMA $schema GRANT $seq_perms ON SEQUENCES TO $grantee;"
    
    # Default privileges for functions
    local sql3="ALTER DEFAULT PRIVILEGES FOR ROLE $grantor IN SCHEMA $schema GRANT $func_perms ON FUNCTIONS TO $grantee;"
    
    psql_admin_quiet "$sql1" "$dbname" || return 1
    psql_admin_quiet "$sql2" "$dbname" || return 1
    psql_admin_quiet "$sql3" "$dbname" || return 1
    
    return 0
}

# Set default privileges for all standard users
set_default_privileges_for_all() {
    local dbname="$1"
    local prefix="$2"  # e.g., "myapp_production" or "myapp_production_tenant_acme"
    local schema="${3:-public}"
    
    local owner="${prefix}_owner"
    local migration="${prefix}_migration_user"
    
    log_info "Configuring default privileges for future objects..."
    
    # Permissions granted by owner
    echo "  → Owner grants to migration_user..."
    set_default_privileges "$dbname" "$owner" "${prefix}_migration_user" "migration_user" "$schema" || return 1
    echo "  → Owner grants to fullaccess_user..."
    set_default_privileges "$dbname" "$owner" "${prefix}_fullaccess_user" "fullaccess_user" "$schema" || return 1
    echo "  → Owner grants to app_user..."
    set_default_privileges "$dbname" "$owner" "${prefix}_app_user" "app_user" "$schema" || return 1
    echo "  → Owner grants to readonly_user..."
    set_default_privileges "$dbname" "$owner" "${prefix}_readonly_user" "readonly_user" "$schema" || return 1
    
    # Permissions granted by migration_user
    echo "  → Migration user grants to fullaccess_user..."
    set_default_privileges "$dbname" "$migration" "${prefix}_fullaccess_user" "fullaccess_user" "$schema" || return 1
    echo "  → Migration user grants to app_user..."
    set_default_privileges "$dbname" "$migration" "${prefix}_app_user" "app_user" "$schema" || return 1
    echo "  → Migration user grants to readonly_user..."
    set_default_privileges "$dbname" "$migration" "${prefix}_readonly_user" "readonly_user" "$schema" || return 1
    
    log_success "Default privileges configured"
    return 0
}

# =============================================================================
# Permission Revocation Functions
# =============================================================================

# Revoke all permissions from a user on a schema
revoke_all_permissions() {
    local dbname="$1"
    local username="$2"
    local schema="${3:-public}"
    
    local sql
    sql="REVOKE ALL ON ALL TABLES IN SCHEMA $schema FROM $username;
         REVOKE ALL ON ALL SEQUENCES IN SCHEMA $schema FROM $username;
         REVOKE ALL ON ALL FUNCTIONS IN SCHEMA $schema FROM $username;
         REVOKE ALL ON SCHEMA $schema FROM $username;"
    
    psql_admin_quiet "$sql" "$dbname"
}

# Revoke PUBLIC permissions from schema
revoke_public_schema_access() {
    local dbname="$1"
    local schema="${2:-public}"
    
    local sql="REVOKE ALL ON SCHEMA $schema FROM PUBLIC;"
    psql_admin_quiet "$sql" "$dbname"
}

# =============================================================================
# Permission Query Functions
# =============================================================================

# Get user's table permissions
get_user_table_permissions() {
    local dbname="$1"
    local username="$2"
    
    local sql="SELECT table_schema, table_name, privilege_type 
               FROM information_schema.role_table_grants 
               WHERE grantee = '$username' 
               ORDER BY table_schema, table_name, privilege_type;"
    
    psql_admin "$sql" "$dbname"
}

# Get user's schema permissions
get_user_schema_permissions() {
    local dbname="$1"
    local username="$2"
    
    local sql="SELECT nspname AS schema_name, 
               CASE WHEN has_schema_privilege('$username', nspname, 'USAGE') THEN 'USAGE' ELSE '' END AS usage,
               CASE WHEN has_schema_privilege('$username', nspname, 'CREATE') THEN 'CREATE' ELSE '' END AS create
               FROM pg_namespace
               WHERE nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
               ORDER BY nspname;"
    
    psql_admin "$sql" "$dbname"
}

# =============================================================================
# Interactive Permission Commands
# =============================================================================

# Grant permissions to existing objects (interactive, supports multiselect databases)
cmd_grant_existing() {
    local dbname="${1:-}"
    
    log_header "Grant Permissions to Existing Objects"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    # Get database name(s) if not provided
    if [[ -z "$dbname" ]]; then
        local databases
        databases=$(list_with_loading "databases" "list_databases_query")
        
        if [[ -z "$databases" ]]; then
            log_error "No databases found"
            return 1
        fi
        
        # Use multiselect for interactive mode
        local selected_dbs
        selected_dbs=$(prompt_select_multiple "Select database(s):" $databases)
        
        if [[ -z "$selected_dbs" ]]; then
            log_error "No databases selected"
            return 1
        fi
        
        # Apply permissions to each selected database
        local db_count=0
        local db_total=$(echo "$selected_dbs" | wc -l)
        while IFS= read -r db; do
            [[ -z "$db" ]] && continue
            ((db_count++))
            log_info "Processing database $db_count of $db_total: $db"
            
            if ! database_exists "$db"; then
                log_warning "Database '$db' does not exist, skipping"
                continue
            fi
            
            # Get list of users for this database
            local db_users
            db_users=$(list_with_loading "users" "list_users_query" | grep "^${db}_" || true)
            
            if [[ -z "$db_users" ]]; then
                log_warning "No users found for database: $db, skipping"
                continue
            fi
            
            echo ""
            log_info "Applying permissions to existing objects in $db..."
            
            local prefix="$db"
            local roles="owner migration_user fullaccess_user app_user readonly_user"
            
            for role in $roles; do
                local username="${prefix}_${role}"
                
                if user_exists "$username"; then
                    if [[ "$GUM_AVAILABLE" == "true" ]]; then
                        gum spin --spinner dot --title "Granting permissions to $username..." -- \
                            bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'; grant_all_permissions '$db' '$username' '$role' 'public'"
                    else
                        echo -n "Granting permissions to $username... "
                        grant_all_permissions "$db" "$username" "$role" "public"
                        echo "done"
                    fi
                    log_success "Permissions granted to $username"
                fi
            done
        done <<< "$selected_dbs"
        
        echo ""
        log_success "All permissions applied to existing objects in selected databases"
        
    else
        # Single database mode (CLI argument provided)
        # Get list of users for this database
        local db_users
        db_users=$(list_with_loading "users" "list_users_query" | grep "^${dbname}_" || true)
        
        if [[ -z "$db_users" ]]; then
            log_warning "No users found for database: $dbname"
            return 1
        fi
        
        log_info "Applying permissions to existing objects in $dbname..."
        
        local prefix="$dbname"
        local roles="owner migration_user fullaccess_user app_user readonly_user"
        
        for role in $roles; do
            local username="${prefix}_${role}"
            
            if user_exists "$username"; then
                if [[ "$GUM_AVAILABLE" == "true" ]]; then
                    gum spin --spinner dot --title "Granting permissions to $username..." -- \
                        bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'; grant_all_permissions '$dbname' '$username' '$role' 'public'"
                else
                    echo -n "Granting permissions to $username... "
                    grant_all_permissions "$dbname" "$username" "$role" "public"
                    echo "done"
                fi
                log_success "Permissions granted to $username"
            fi
        done
        
        log_success "All permissions applied to existing objects"
    fi
}

# Audit permissions (interactive, supports multiselect databases)
cmd_audit() {
    local dbname="${1:-}"
    
    log_header "Permission Audit Report"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    # Get database name(s) if not provided
    if [[ -z "$dbname" ]]; then
        local databases
        databases=$(list_with_loading "databases" "list_databases_query")
        
        if [[ -z "$databases" ]]; then
            log_error "No databases found"
            return 1
        fi
        
        # Use multiselect for interactive mode
        local selected_dbs
        selected_dbs=$(prompt_select_multiple "Select database(s):" $databases)
        
        if [[ -z "$selected_dbs" ]]; then
            log_error "No databases selected"
            return 1
        fi
        
        # Generate audit for each selected database
        local first=true
        local db_count=0
        local db_total=$(echo "$selected_dbs" | wc -l)
        while IFS= read -r db; do
            [[ -z "$db" ]] && continue
            ((db_count++))
            log_info "Auditing database $db_count of $db_total: $db"
            
            if ! database_exists "$db"; then
                log_warning "Database '$db' does not exist, skipping"
                continue
            fi
            
            # Add separator between databases
            if [[ "$first" == "false" ]]; then
                echo ""
                echo "========================================"
                echo ""
            fi
            first=false
            
            _audit_one_database "$db"
        done <<< "$selected_dbs"
        
    else
        # Single database mode (CLI argument provided)
        _audit_one_database "$dbname"
    fi
}

# Helper: Audit one database
_audit_one_database() {
    local dbname="$1"
    
    log_info "Database: $dbname"
    log_info "Generated: $(date)"
    echo ""
    
    # Get table counts by user
    local sql="SELECT grantee, 
               COUNT(DISTINCT table_name) as table_count,
               STRING_AGG(DISTINCT privilege_type, ', ' ORDER BY privilege_type) as privileges
               FROM information_schema.role_table_grants 
               WHERE table_schema = 'public'
               AND grantee LIKE '${dbname}_%'
               GROUP BY grantee
               ORDER BY grantee;"
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        local result
        result=$(psql_admin "$sql" "$dbname" 2>/dev/null)
        echo "$result" | gum table
    else
        psql_admin "$sql" "$dbname"
    fi
    
    echo ""
    
    # Summary
    local table_count
    table_count=$(psql_admin "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" "$dbname" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    local seq_count
    seq_count=$(psql_admin "SELECT COUNT(*) FROM information_schema.sequences WHERE sequence_schema = 'public';" "$dbname" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    local func_count
    func_count=$(psql_admin "SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'public';" "$dbname" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    log_info "Summary:"
    echo "  Tables:    ${table_count:-0}"
    echo "  Sequences: ${seq_count:-0}"
    echo "  Functions: ${func_count:-0}"
}

# =============================================================================
# Register Commands
# =============================================================================

register_command "Grant Existing Objects" "PERMISSION MANAGEMENT" "cmd_grant_existing" \
    "Apply permissions to existing database objects"

register_command "Audit Permissions" "PERMISSION MANAGEMENT" "cmd_audit" \
    "Generate permission audit report"
