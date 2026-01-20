#!/bin/bash

# =============================================================================
# Schema Library for pgctl
# =============================================================================
# Functions for creating, deleting, and listing schemas with schema-specific users
# =============================================================================

# Prevent multiple sourcing
[[ -n "${PGCTL_SCHEMA_LOADED:-}" ]] && return
PGCTL_SCHEMA_LOADED=1

# Source dependencies
_SCHEMA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_SCHEMA_DIR}/common.sh"
source "${_SCHEMA_DIR}/permissions.sh"

# =============================================================================
# Schema Creation
# =============================================================================

# Helper: Create schema in a single database
_create_schema_in_db() {
    local dbname="$1"
    local schemaname="$2"
    local owner_pass="$3"
    local migration_pass="$4"
    local fullaccess_pass="$5"
    local app_pass="$6"
    local readonly_pass="$7"
    
    # Define user prefix
    local prefix="${dbname}_${schemaname}"
    
    # Define user names
    local owner="${prefix}_owner"
    local migration="${prefix}_migration_user"
    local fullaccess="${prefix}_fullaccess_user"
    local app="${prefix}_app_user"
    local readonly="${prefix}_readonly_user"
    
    # Create schema owner user
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Creating $owner..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin_quiet \"CREATE ROLE $owner WITH LOGIN PASSWORD '$owner_pass';\""
    else
        echo -n "Creating $owner... "
        psql_admin_quiet "CREATE ROLE $owner WITH LOGIN PASSWORD '$owner_pass';"
    fi
    log_success "Schema owner created"
    
    # Create schema
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Creating schema $schemaname..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin_quiet \"CREATE SCHEMA $schemaname AUTHORIZATION $owner;\" \"$dbname\""
    else
        echo -n "Creating schema $schemaname... "
        psql_admin_quiet "CREATE SCHEMA $schemaname AUTHORIZATION $owner;" "$dbname"
    fi
    log_success "Schema created successfully"
    
    # Setting schema ownership is done via AUTHORIZATION above
    log_success "Ownership configured"
    
    # Create migration user
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Creating $migration..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin_quiet \"CREATE ROLE $migration WITH LOGIN PASSWORD '$migration_pass';\""
    else
        echo -n "Creating $migration... "
        psql_admin_quiet "CREATE ROLE $migration WITH LOGIN PASSWORD '$migration_pass';"
    fi
    log_success "Schema migration user created"
    
    # Create fullaccess user
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Creating $fullaccess..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin_quiet \"CREATE ROLE $fullaccess WITH LOGIN PASSWORD '$fullaccess_pass';\""
    else
        echo -n "Creating $fullaccess... "
        psql_admin_quiet "CREATE ROLE $fullaccess WITH LOGIN PASSWORD '$fullaccess_pass';"
    fi
    log_success "Schema fullaccess user created"
    
    # Create app user
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Creating $app..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin_quiet \"CREATE ROLE $app WITH LOGIN PASSWORD '$app_pass';\""
    else
        echo -n "Creating $app... "
        psql_admin_quiet "CREATE ROLE $app WITH LOGIN PASSWORD '$app_pass';"
    fi
    log_success "Schema app user created"
    
    # Create readonly user
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Creating $readonly..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin_quiet \"CREATE ROLE $readonly WITH LOGIN PASSWORD '$readonly_pass';\""
    else
        echo -n "Creating $readonly... "
        psql_admin_quiet "CREATE ROLE $readonly WITH LOGIN PASSWORD '$readonly_pass';"
    fi
    log_success "Schema readonly user created"
    
    # Configure schema permissions (per-user progress)
    log_info "Configuring schema permissions for 5 users..."
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Granting owner permissions..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'; grant_all_permissions '$dbname' '$owner' 'owner' '$schemaname'"
        gum spin --spinner dot --title "Granting migration_user permissions..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'; grant_all_permissions '$dbname' '$migration' 'migration_user' '$schemaname'"
        gum spin --spinner dot --title "Granting fullaccess_user permissions..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'; grant_all_permissions '$dbname' '$fullaccess' 'fullaccess_user' '$schemaname'"
        gum spin --spinner dot --title "Granting app_user permissions..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'; grant_all_permissions '$dbname' '$app' 'app_user' '$schemaname'"
        gum spin --spinner dot --title "Granting readonly_user permissions..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'; grant_all_permissions '$dbname' '$readonly' 'readonly_user' '$schemaname'"
    else
        echo "  → owner"
        grant_all_permissions "$dbname" "$owner" "owner" "$schemaname"
        echo "  → migration_user"
        grant_all_permissions "$dbname" "$migration" "migration_user" "$schemaname"
        echo "  → fullaccess_user"
        grant_all_permissions "$dbname" "$fullaccess" "fullaccess_user" "$schemaname"
        echo "  → app_user"
        grant_all_permissions "$dbname" "$app" "app_user" "$schemaname"
        echo "  → readonly_user"
        grant_all_permissions "$dbname" "$readonly" "readonly_user" "$schemaname"
    fi
    log_success "Schema permissions configured"
    
    # Revoke PUBLIC schema access (full isolation)
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Revoking PUBLIC schema access..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'
                     revoke_public_schema_access '$dbname' '$schemaname'
                     # Also revoke access to public schema for schema users
                     revoke_all_permissions '$dbname' '$owner' 'public'
                     revoke_all_permissions '$dbname' '$migration' 'public'
                     revoke_all_permissions '$dbname' '$fullaccess' 'public'
                     revoke_all_permissions '$dbname' '$app' 'public'
                     revoke_all_permissions '$dbname' '$readonly' 'public'"
    else
        echo -n "Revoking PUBLIC schema access... "
        revoke_public_schema_access "$dbname" "$schemaname"
        revoke_all_permissions "$dbname" "$owner" "public"
        revoke_all_permissions "$dbname" "$migration" "public"
        revoke_all_permissions "$dbname" "$fullaccess" "public"
        revoke_all_permissions "$dbname" "$app" "public"
        revoke_all_permissions "$dbname" "$readonly" "public"
    fi
    log_success "Full schema isolation enabled (no PUBLIC access)"
    
    # Configure default privileges for future objects
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Configuring default privileges..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'
                     set_default_privileges_for_all '$dbname' '$prefix' '$schemaname'"
    else
        echo -n "Configuring default privileges... "
        set_default_privileges_for_all "$dbname" "$prefix" "$schemaname"
    fi
    log_success "Default privileges configured for future objects"
    
    echo ""
    
    # Display success summary
    local summary="✓ Schema Setup Complete

Database: $dbname
Schema: $schemaname
Owner: $owner
Schema users created: 5
Isolation: Full (no PUBLIC/cross-schema)
Default privileges: ✓ Enabled
Status: Ready"
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum style --border rounded --padding "1 2" --border-foreground 10 "$summary"
    else
        log_box "$summary"
    fi
    
    # Return credential info for display (caller will handle display)
    echo "$owner|$owner_pass|owner"
    echo "$migration|$migration_pass|migration"
    echo "$fullaccess|$fullaccess_pass|fullaccess"
    echo "$app|$app_pass|app"
    echo "$readonly|$readonly_pass|readonly"
}

# Create a schema with 5 schema-specific users (supports multiselect databases)
create_schema() {
    local dbname="${1:-}"
    local schemaname="${2:-}"
    
    log_header "Schema Creation Wizard"
    
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
        selected_dbs=$(prompt_select_multiple "Select target database(s):" $databases)
        
        if [[ -z "$selected_dbs" ]]; then
            log_error "No databases selected"
            return 1
        fi
        
        # Get schema name (common for all databases)
        schemaname=$(prompt_input "Schema name")
        
        # Validate schema name
        if ! validate_schema_name "$schemaname"; then
            return 1
        fi
        
        # Get passwords once (reused for all databases)
        echo ""
        local owner_pass
        owner_pass=$(get_password "SCHEMA_OWNER_PASSWORD" "Schema owner password")
        
        local migration_pass
        migration_pass=$(get_password "SCHEMA_MIGRATION_PASSWORD" "Migration user password")
        
        local fullaccess_pass
        fullaccess_pass=$(get_password "SCHEMA_FULLACCESS_PASSWORD" "Full access user password")
        
        local app_pass
        app_pass=$(get_password "SCHEMA_APP_PASSWORD" "App user password")
        
        local readonly_pass
        readonly_pass=$(get_password "SCHEMA_READONLY_PASSWORD" "Read-only user password")
        
        echo ""
        
        # Collect credentials for display at the end
        local -a all_credentials=()
        
        # Create schema in each selected database
        while IFS= read -r db; do
            [[ -z "$db" ]] && continue
            
            if ! database_exists "$db"; then
                log_warning "Database '$db' does not exist, skipping"
                continue
            fi
            
            if schema_exists "$db" "$schemaname"; then
                log_warning "Schema '$schemaname' already exists in database '$db', skipping"
                continue
            fi
            
            # Validate user name lengths for this database
            local prefix="${db}_${schemaname}"
            if ! validate_user_names_length "$prefix"; then
                log_warning "Schema user names will exceed PostgreSQL limits for $db."
                if ! prompt_confirm "Continue with $db anyway?"; then
                    log_info "Skipping database $db"
                    continue
                fi
            fi
            
            echo ""
            log_info "Creating schema in database: $db"
            
            # Call helper to create schema
            local creds
            creds=$(_create_schema_in_db "$db" "$schemaname" "$owner_pass" "$migration_pass" "$fullaccess_pass" "$app_pass" "$readonly_pass")
            
            # Store credentials for this database
            while IFS= read -r cred_line; do
                [[ -z "$cred_line" ]] && continue
                all_credentials+=("$cred_line")
            done <<< "$creds"
            
            log_success "Schema created in $db"
        done <<< "$selected_dbs"
        
        echo ""
        
        # Display all credentials
        if [[ ${#all_credentials[@]} -gt 0 ]]; then
            display_credentials "CREDENTIALS FOR ALL DATABASES" \
                "Username|Password|Role" \
                "${all_credentials[@]}"
            
            log_warning "Save these credentials securely. They will not be shown again!"
        else
            log_warning "No schemas were created"
        fi
        
    else
        # Single database mode (CLI argument provided)
        # Verify database exists
        if ! database_exists "$dbname"; then
            log_error "Database '$dbname' does not exist"
            return 1
        fi
        
        # Get schema name if not provided
        if [[ -z "$schemaname" ]]; then
            schemaname=$(prompt_input "Schema name")
        fi
        
        # Validate schema name
        if ! validate_schema_name "$schemaname"; then
            return 1
        fi
        
        # Check if schema already exists
        if schema_exists "$dbname" "$schemaname"; then
            log_error "Schema '$schemaname' already exists in database '$dbname'"
            return 1
        fi
        
        # Define user prefix
        local prefix="${dbname}_${schemaname}"
        
        # Validate user name lengths
        if ! validate_user_names_length "$prefix"; then
            log_warning "Schema user names will exceed PostgreSQL limits."
            if ! prompt_confirm "Continue anyway?"; then
                return 1
            fi
        fi
        
        # Get passwords
        echo ""
        local owner_pass
        owner_pass=$(get_password "SCHEMA_OWNER_PASSWORD" "Schema owner password")
        
        local migration_pass
        migration_pass=$(get_password "SCHEMA_MIGRATION_PASSWORD" "Migration user password")
        
        local fullaccess_pass
        fullaccess_pass=$(get_password "SCHEMA_FULLACCESS_PASSWORD" "Full access user password")
        
        local app_pass
        app_pass=$(get_password "SCHEMA_APP_PASSWORD" "App user password")
        
        local readonly_pass
        readonly_pass=$(get_password "SCHEMA_READONLY_PASSWORD" "Read-only user password")
        
        echo ""
        
        # Create schema
        _create_schema_in_db "$dbname" "$schemaname" "$owner_pass" "$migration_pass" "$fullaccess_pass" "$app_pass" "$readonly_pass" > /dev/null
        
        # Display success summary
        local summary="✓ Schema Setup Complete

Database: $dbname
Schema: $schemaname
Owner: ${dbname}_${schemaname}_owner
Schema users created: 5
Isolation: Full (no PUBLIC/cross-schema)
Default privileges: ✓ Enabled
Status: Ready"
        
        if [[ "$GUM_AVAILABLE" == "true" ]]; then
            gum style --border rounded --padding "1 2" --border-foreground 10 "$summary"
        else
            log_box "$summary"
        fi
        
        # Display credentials
        local prefix="${dbname}_${schemaname}"
        local owner="${prefix}_owner"
        local migration="${prefix}_migration_user"
        local fullaccess="${prefix}_fullaccess_user"
        local app="${prefix}_app_user"
        local readonly="${prefix}_readonly_user"
        
        display_credentials "CREDENTIALS" \
            "Username|Password|Role" \
            "$owner|$owner_pass|owner" \
            "$migration|$migration_pass|migration" \
            "$fullaccess|$fullaccess_pass|fullaccess" \
            "$app|$app_pass|app" \
            "$readonly|$readonly_pass|readonly"
        
        display_connection_example "$app" "$dbname"
        
        log_warning "Save these credentials securely. They will not be shown again!"
    fi
}

# =============================================================================
# Schema Deletion
# =============================================================================

# Helper: Delete a single schema and its users
_delete_one_schema() {
    local dbname="$1"
    local schemaname="$2"
    
    # Delete schema with CASCADE
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Deleting schema $schemaname..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin_quiet \"DROP SCHEMA IF EXISTS $schemaname CASCADE;\" \"$dbname\""
    else
        echo -n "Deleting schema $schemaname... "
        psql_admin_quiet "DROP SCHEMA IF EXISTS $schemaname CASCADE;" "$dbname"
    fi
    log_success "Schema $schemaname deleted"
    
    # Delete users
    local prefix="${dbname}_${schemaname}"
    local users=("${prefix}_owner" "${prefix}_migration_user" "${prefix}_fullaccess_user" "${prefix}_app_user" "${prefix}_readonly_user")
    
    for user in "${users[@]}"; do
        if user_exists "$user"; then
            if [[ "$GUM_AVAILABLE" == "true" ]]; then
                gum spin --spinner dot --title "Deleting user $user..." -- \
                    bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin_quiet \"DROP ROLE IF EXISTS $user;\""
            else
                echo -n "Deleting user $user... "
                psql_admin_quiet "DROP ROLE IF EXISTS $user;"
            fi
            log_success "Deleted $user"
        fi
    done
}

# Delete a schema and its users (supports multiselect schemas)
delete_schema() {
    local dbname="${1:-}"
    local schemaname="${2:-}"
    
    log_header "Delete Schema"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    # Get database name if not provided
    if [[ -z "$dbname" ]]; then
        local databases
        databases=$(list_with_loading "databases" "list_databases_query")
        
        if [[ -z "$databases" ]]; then
            log_error "No databases found"
            return 1
        fi
        
        dbname=$(prompt_select "Select database:" $databases)
        
        if [[ -z "$dbname" ]]; then
            log_error "No database selected"
            return 1
        fi
    fi
    
    # Get schema name(s) if not provided
    if [[ -z "$schemaname" ]]; then
        local schemas
        schemas=$(list_with_loading "schemas" "list_schemas_query '$dbname'")
        
        if [[ -z "$schemas" ]]; then
            log_error "No custom schemas found in database '$dbname'"
            return 1
        fi
        
        # Use multiselect for interactive mode
        local selected_schemas
        selected_schemas=$(prompt_select_multiple "Select schema(s) to delete:" $schemas)
        
        if [[ -z "$selected_schemas" ]]; then
            log_error "No schemas selected"
            return 1
        fi
        
        # Build confirmation message
        log_warning "This will permanently delete from database '$dbname':"
        echo ""
        
        while IFS= read -r schema; do
            [[ -z "$schema" ]] && continue
            
            if ! schema_exists "$dbname" "$schema"; then
                continue
            fi
            
            local prefix="${dbname}_${schema}"
            local users=("${prefix}_owner" "${prefix}_migration_user" "${prefix}_fullaccess_user" "${prefix}_app_user" "${prefix}_readonly_user")
            
            echo "  Schema: $schema (with CASCADE)"
            echo "  Users:"
            for user in "${users[@]}"; do
                if user_exists "$user"; then
                    echo "    - $user"
                fi
            done
            echo ""
        done <<< "$selected_schemas"
        
        # Confirm deletion
        if ! prompt_confirm "Are you sure you want to delete these schema(s)?"; then
            log_info "Deletion cancelled"
            return 0
        fi
        
        # Delete each selected schema
        while IFS= read -r schema; do
            [[ -z "$schema" ]] && continue
            
            if ! schema_exists "$dbname" "$schema"; then
                log_warning "Schema '$schema' does not exist in '$dbname', skipping"
                continue
            fi
            
            echo ""
            log_info "Deleting schema: $schema"
            _delete_one_schema "$dbname" "$schema"
        done <<< "$selected_schemas"
        
        echo ""
        log_success "Selected schemas and associated users deleted successfully"
        
    else
        # Single schema mode (CLI argument provided)
        # Verify schema exists
        if ! schema_exists "$dbname" "$schemaname"; then
            log_error "Schema '$schemaname' does not exist in database '$dbname'"
            return 1
        fi
        
        # Define user prefix
        local prefix="${dbname}_${schemaname}"
        
        # List users that will be deleted
        local users=("${prefix}_owner" "${prefix}_migration_user" "${prefix}_fullaccess_user" "${prefix}_app_user" "${prefix}_readonly_user")
        
        log_warning "This will permanently delete:"
        echo "  Schema: $schemaname (with CASCADE)"
        echo "  Users:"
        for user in "${users[@]}"; do
            if user_exists "$user"; then
                echo "    - $user"
            fi
        done
        echo ""
        
        # Confirm deletion
        if ! prompt_confirm "Are you sure you want to delete this schema?"; then
            log_info "Deletion cancelled"
            return 0
        fi
        
        _delete_one_schema "$dbname" "$schemaname"
        
        echo ""
        log_success "Schema and all associated users deleted successfully"
    fi
}

# =============================================================================
# Schema Listing
# =============================================================================

# List all schemas in a database (supports multiselect databases)
list_schemas() {
    local dbname="${1:-}"
    
    log_header "Schemas"
    
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
        
        # List schemas for each selected database
        local first=true
        while IFS= read -r db; do
            [[ -z "$db" ]] && continue
            
            if ! database_exists "$db"; then
                log_warning "Database '$db' does not exist, skipping"
                continue
            fi
            
            # Add separator between databases
            if [[ "$first" == "false" ]]; then
                echo ""
                echo "---"
                echo ""
            fi
            first=false
            
            log_info "Database: $db"
            echo ""
            
            local sql="SELECT n.nspname AS schema_name,
                       pg_catalog.pg_get_userbyid(n.nspowner) AS owner,
                       (SELECT COUNT(*) FROM information_schema.tables t WHERE t.table_schema = n.nspname) AS table_count
                       FROM pg_catalog.pg_namespace n
                       WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
                       AND n.nspname NOT LIKE 'pg_%'
                       ORDER BY n.nspname;"
            
            if [[ "$GUM_AVAILABLE" == "true" ]]; then
                local result
                result=$(psql_admin "$sql" "$db" 2>/dev/null)
                echo "$result" | gum table
            else
                psql_admin "$sql" "$db"
            fi
        done <<< "$selected_dbs"
        
    else
        # Single database mode (CLI argument provided)
        log_info "Database: $dbname"
        echo ""
        
        local sql="SELECT n.nspname AS schema_name,
                   pg_catalog.pg_get_userbyid(n.nspowner) AS owner,
                   (SELECT COUNT(*) FROM information_schema.tables t WHERE t.table_schema = n.nspname) AS table_count
                   FROM pg_catalog.pg_namespace n
                   WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
                   AND n.nspname NOT LIKE 'pg_%'
                   ORDER BY n.nspname;"
        
        if [[ "$GUM_AVAILABLE" == "true" ]]; then
            local result
            result=$(psql_admin "$sql" "$dbname" 2>/dev/null)
            echo "$result" | gum table
        else
            psql_admin "$sql" "$dbname"
        fi
    fi
}

# List schema-specific users
list_schema_users() {
    local dbname="${1:-}"
    local schemaname="${2:-}"
    
    log_header "Schema Users"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    # Get database name if not provided
    if [[ -z "$dbname" ]]; then
        local databases
        databases=$(list_with_loading "databases" "list_databases_query")
        
        if [[ -z "$databases" ]]; then
            log_error "No databases found"
            return 1
        fi
        
        dbname=$(prompt_select "Select database:" $databases)
        
        if [[ -z "$dbname" ]]; then
            log_error "No database selected"
            return 1
        fi
    fi
    
    # Get schema name if not provided
    if [[ -z "$schemaname" ]]; then
        local schemas
        schemas=$(list_with_loading "schemas" "list_schemas_query '$dbname'")
        
        if [[ -z "$schemas" ]]; then
            log_error "No custom schemas found in database '$dbname'"
            return 1
        fi
        
        schemaname=$(prompt_select "Select schema:" $schemas)
        
        if [[ -z "$schemaname" ]]; then
            log_error "No schema selected"
            return 1
        fi
    fi
    
    log_info "Database: $dbname / Schema: $schemaname"
    echo ""
    
    local prefix="${dbname}_${schemaname}"
    
    local sql="SELECT rolname AS username,
               CASE 
                   WHEN rolname LIKE '%_owner' THEN 'owner'
                   WHEN rolname LIKE '%_migration_user' THEN 'migration'
                   WHEN rolname LIKE '%_fullaccess_user' THEN 'fullaccess'
                   WHEN rolname LIKE '%_app_user' THEN 'app'
                   WHEN rolname LIKE '%_readonly_user' THEN 'readonly'
                   ELSE 'unknown'
               END AS role_type,
               CASE WHEN rolcanlogin THEN 'Yes' ELSE 'No' END AS can_login
               FROM pg_roles
               WHERE rolname LIKE '${prefix}_%'
               ORDER BY rolname;"
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        local result
        result=$(psql_admin "$sql" 2>/dev/null)
        echo "$result" | gum table
    else
        psql_admin "$sql"
    fi
}

# =============================================================================
# Schema Access Management
# =============================================================================

# Grant existing user access to a schema
grant_schema_access() {
    log_header "Grant Schema Access"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    # Get database
    local databases
    databases=$(list_with_loading "databases" "list_databases_query")
    
    if [[ -z "$databases" ]]; then
        log_error "No databases found"
        return 1
    fi
    
    local dbname
    dbname=$(prompt_select "Select database:" $databases)
    
    if [[ -z "$dbname" ]]; then
        log_error "No database selected"
        return 1
    fi
    
    # Get schema
    local schemas
    schemas=$(list_with_loading "schemas" "list_schemas_query '$dbname'")
    
    if [[ -z "$schemas" ]]; then
        log_error "No custom schemas found"
        return 1
    fi
    
    local schemaname
    schemaname=$(prompt_select "Select schema:" $schemas)
    
    if [[ -z "$schemaname" ]]; then
        log_error "No schema selected"
        return 1
    fi
    
    # Get user(s) - use multiselect
    local users
    users=$(list_with_loading "users" "list_users_query")
    
    if [[ -z "$users" ]]; then
        log_error "No users found"
        return 1
    fi
    
    local selected_users
    selected_users=$(prompt_select_multiple "Select user(s):" $users)
    
    if [[ -z "$selected_users" ]]; then
        log_error "No users selected"
        return 1
    fi
    
    # Select permission level (applies to all selected users)
    local role_type
    role_type=$(prompt_select "Select permission level:" "readonly_user" "app_user" "fullaccess_user" "migration_user" "owner")
    
    if [[ -z "$role_type" ]]; then
        log_error "No permission level selected"
        return 1
    fi
    
    # Grant permissions to each selected user
    while IFS= read -r username; do
        [[ -z "$username" ]] && continue
        
        if [[ "$GUM_AVAILABLE" == "true" ]]; then
            gum spin --spinner dot --title "Granting $role_type permissions to $username on $schemaname..." -- \
                bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'; grant_all_permissions '$dbname' '$username' '$role_type' '$schemaname'"
        else
            echo -n "Granting $role_type permissions to $username on $schemaname... "
            grant_all_permissions "$dbname" "$username" "$role_type" "$schemaname"
        fi
        
        log_success "Granted $role_type permissions to $username on schema $schemaname"
    done <<< "$selected_users"
}

# =============================================================================
# Add Schema Users (Templated Users)
# =============================================================================

# Add/provision the 5 standard users to an existing schema
# This is idempotent - safe to run multiple times
add_schema_users() {
    local dbname="${1:-}"
    local schemaname="${2:-}"
    
    log_header "Add Schema Users"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    # Get database name if not provided
    if [[ -z "$dbname" ]]; then
        local databases
        databases=$(list_with_loading "databases" "list_databases_query")
        
        if [[ -z "$databases" ]]; then
            log_error "No databases found"
            return 1
        fi
        
        dbname=$(prompt_select "Select database:" $databases)
        
        if [[ -z "$dbname" ]]; then
            log_error "No database selected"
            return 1
        fi
    fi
    
    # Verify database exists
    if ! database_exists "$dbname"; then
        log_error "Database '$dbname' does not exist"
        return 1
    fi
    
    # Get schema name(s) if not provided
    if [[ -z "$schemaname" ]]; then
        local schemas
        schemas=$(list_with_loading "schemas" "list_schemas_query '$dbname'")
        
        if [[ -z "$schemas" ]]; then
            log_error "No custom schemas found in database '$dbname'"
            return 1
        fi
        
        # Use multiselect for interactive mode
        local selected_schemas
        selected_schemas=$(prompt_select_multiple "Select schema(s):" $schemas)
        
        if [[ -z "$selected_schemas" ]]; then
            log_error "No schemas selected"
            return 1
        fi
        
        # Collect credentials for all schemas
        local -a all_credentials=()
        
        # Process each selected schema
        # Note: Using process substitution to avoid subshell issues with array modifications
        while IFS= read -r schema; do
            [[ -z "$schema" ]] && continue
            
            if ! schema_exists "$dbname" "$schema"; then
                log_warning "Schema '$schema' does not exist in '$dbname', skipping"
                continue
            fi
            
            echo ""
            log_info "Processing schema: $schema"
            
            # Process this schema inline to collect credentials
            local prefix="${dbname}_${schema}"
            
            # Validate user name lengths
            if ! validate_user_names_length "$prefix"; then
                log_warning "Schema user names will exceed PostgreSQL limits."
                if ! prompt_confirm "Continue with $schema anyway?"; then
                    log_info "Skipping schema $schema"
                    continue
                fi
            fi
            
            # Define user names and their role types
            local -a user_names=("${prefix}_owner" "${prefix}_migration_user" "${prefix}_fullaccess_user" "${prefix}_app_user" "${prefix}_readonly_user")
            local -a role_types=("owner" "migration_user" "fullaccess_user" "app_user" "readonly_user")
            local -a role_labels=("owner" "migration" "fullaccess" "app" "readonly")
            local -a env_vars=("SCHEMA_OWNER_PASSWORD" "SCHEMA_MIGRATION_PASSWORD" "SCHEMA_FULLACCESS_PASSWORD" "SCHEMA_APP_PASSWORD" "SCHEMA_READONLY_PASSWORD")
            local -a prompts=("Schema owner password" "Migration user password" "Full access user password" "App user password" "Read-only user password")
            
            # Track which users exist and which need to be created
            local -a users_exist=()
            local -a users_missing=()
            local -a missing_indices=()
            
            echo "Checking existing users..."
            
            for i in "${!user_names[@]}"; do
                local username="${user_names[$i]}"
                if user_exists "$username"; then
                    log_success "$username exists"
                    users_exist+=("$username")
                else
                    log_warning "$username missing"
                    users_missing+=("$username")
                    missing_indices+=("$i")
                fi
            done
            
            echo ""
            
            # If there are missing users, get passwords and create them
            if [[ ${#users_missing[@]} -gt 0 ]]; then
                log_info "Creating ${#users_missing[@]} missing user(s)..."
                echo ""
                
                # Get passwords for missing users
                local -a passwords=()
                for idx in "${missing_indices[@]}"; do
                    local pass
                    pass=$(get_password "${env_vars[$idx]}" "${prompts[$idx]}")
                    passwords+=("$pass")
                done
                
                echo ""
                
                # Create missing users
                local pwd_idx=0
                for idx in "${missing_indices[@]}"; do
                    local username="${user_names[$idx]}"
                    local password="${passwords[$pwd_idx]}"
                    local role_label="${role_labels[$idx]}"
                    
                    if [[ "$GUM_AVAILABLE" == "true" ]]; then
                        gum spin --spinner dot --title "Creating $username..." -- \
                            bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin_quiet \"CREATE ROLE $username WITH LOGIN PASSWORD '$password';\""
                    else
                        echo -n "Creating $username... "
                        psql_admin_quiet "CREATE ROLE $username WITH LOGIN PASSWORD '$password';"
                    fi
                    log_success "Created $username"
                    
                    # Store credentials for display
                    all_credentials+=("$username|$password|$role_label")
                    
                    ((pwd_idx++))
                done
                
                echo ""
            else
                log_success "All 5 standard users already exist"
                echo ""
            fi
            
            # Grant/verify permissions for ALL users (existing and new)
            log_info "Configuring permissions for all users..."
            for i in "${!user_names[@]}"; do
                local user_label="${role_labels[$i]}"
                if [[ "$GUM_AVAILABLE" == "true" ]]; then
                    gum spin --spinner dot --title "Granting ${user_label} permissions..." -- \
                        bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'; grant_all_permissions '$dbname' '${user_names[$i]}' '${role_types[$i]}' '$schema' 2>/dev/null"
                else
                    echo "  → ${user_label}"
                    grant_all_permissions "$dbname" "${user_names[$i]}" "${role_types[$i]}" "$schema" 2>/dev/null || true
                fi
            done
            log_success "Schema permissions configured"
            
            # Revoke PUBLIC schema access (full isolation) - only for non-public schemas
            if [[ "$schema" != "public" ]]; then
                if [[ "$GUM_AVAILABLE" == "true" ]]; then
                    gum spin --spinner dot --title "Enforcing schema isolation..." -- \
                        bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'
                                 revoke_public_schema_access '$dbname' '$schema'
                                 for username in ${user_names[*]}; do
                                     revoke_all_permissions '$dbname' \"\$username\" 'public' 2>/dev/null
                                 done"
                else
                    echo -n "Enforcing schema isolation... "
                    revoke_public_schema_access "$dbname" "$schema"
                    for username in "${user_names[@]}"; do
                        revoke_all_permissions "$dbname" "$username" "public" 2>/dev/null || true
                    done
                fi
                log_success "Schema isolation enforced (no PUBLIC access)"
            else
                log_info "Skipping schema isolation (using public schema)"
            fi
            
            # Configure default privileges for future objects
            if [[ "$GUM_AVAILABLE" == "true" ]]; then
                gum spin --spinner dot --title "Setting default privileges..." -- \
                    bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'
                             set_default_privileges_for_all '$dbname' '$prefix' '$schema'"
            else
                echo -n "Setting default privileges... "
                set_default_privileges_for_all "$dbname" "$prefix" "$schema"
            fi
            log_success "Default privileges configured for future objects"
            
            echo ""
            
            # Display summary for this schema
            local users_created=${#users_missing[@]}
            local users_existing=${#users_exist[@]}
            
            local summary="✓ Schema Users Provisioned

Database: $dbname
Schema: $schema
Users created: $users_created
Users existing: $users_existing
Total users: 5
Isolation: Full (no PUBLIC/cross-schema)
Default privileges: ✓ Enabled
Status: Ready"
            
            if [[ "$GUM_AVAILABLE" == "true" ]]; then
                gum style --border rounded --padding "1 2" --border-foreground 10 "$summary"
            else
                log_box "$summary"
            fi
            
        done < <(echo "$selected_schemas")
        
        echo ""
        
        # Display all credentials at the end
        if [[ ${#all_credentials[@]} -gt 0 ]]; then
            log_info "Displaying credentials for ${#all_credentials[@]} newly created user(s)..."
            echo ""
            display_credentials "NEW CREDENTIALS FOR ALL SCHEMAS" \
                "Username|Password|Role" \
                "${all_credentials[@]}"
            echo ""
            log_warning "Save these credentials securely. They will not be shown again!"
        else
            log_info "No new users created. All users already existed."
            log_info "Permissions have been verified/repaired for all users."
        fi
        
        return 0
    fi
    
    # Single schema mode continues below
    # Verify schema exists
    if ! schema_exists "$dbname" "$schemaname"; then
        log_error "Schema '$schemaname' does not exist in database '$dbname'"
        return 1
    fi
    
    log_info "Database: $dbname"
    log_info "Schema: $schemaname"
    echo ""
    
    # Define user prefix
    local prefix="${dbname}_${schemaname}"
    
    # Validate user name lengths
    if ! validate_user_names_length "$prefix"; then
        log_warning "Schema user names will exceed PostgreSQL limits."
        if ! prompt_confirm "Continue anyway?"; then
            return 1
        fi
    fi
    
    # Define user names and their role types
    local -a user_names=("${prefix}_owner" "${prefix}_migration_user" "${prefix}_fullaccess_user" "${prefix}_app_user" "${prefix}_readonly_user")
    local -a role_types=("owner" "migration_user" "fullaccess_user" "app_user" "readonly_user")
    local -a role_labels=("owner" "migration" "fullaccess" "app" "readonly")
    local -a env_vars=("SCHEMA_OWNER_PASSWORD" "SCHEMA_MIGRATION_PASSWORD" "SCHEMA_FULLACCESS_PASSWORD" "SCHEMA_APP_PASSWORD" "SCHEMA_READONLY_PASSWORD")
    local -a prompts=("Schema owner password" "Migration user password" "Full access user password" "App user password" "Read-only user password")
    
    # Track which users exist and which need to be created
    local -a users_exist=()
    local -a users_missing=()
    local -a missing_indices=()
    
    echo "Checking existing users..."
    
    for i in "${!user_names[@]}"; do
        local username="${user_names[$i]}"
        if user_exists "$username"; then
            log_success "$username exists"
            users_exist+=("$username")
        else
            log_warning "$username missing"
            users_missing+=("$username")
            missing_indices+=("$i")
        fi
    done
    
    echo ""
    
    # Track credentials for newly created users
    local -a new_credentials=()
    
    # If there are missing users, get passwords and create them
    if [[ ${#users_missing[@]} -gt 0 ]]; then
        log_info "Creating ${#users_missing[@]} missing user(s)..."
        echo ""
        
        # Get passwords for missing users
        local -a passwords=()
        for idx in "${missing_indices[@]}"; do
            local pass
            pass=$(get_password "${env_vars[$idx]}" "${prompts[$idx]}")
            passwords+=("$pass")
        done
        
        echo ""
        
        # Create missing users
        local pwd_idx=0
        for idx in "${missing_indices[@]}"; do
            local username="${user_names[$idx]}"
            local password="${passwords[$pwd_idx]}"
            local role_label="${role_labels[$idx]}"
            
            if [[ "$GUM_AVAILABLE" == "true" ]]; then
                gum spin --spinner dot --title "Creating $username..." -- \
                    bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin_quiet \"CREATE ROLE $username WITH LOGIN PASSWORD '$password';\""
            else
                echo -n "Creating $username... "
                psql_admin_quiet "CREATE ROLE $username WITH LOGIN PASSWORD '$password';"
            fi
            log_success "Created $username"
            
            # Store credentials for display
            new_credentials+=("$username|$password|$role_label")
            
            ((pwd_idx++))
        done
        
        echo ""
    else
        log_success "All 5 standard users already exist"
        echo ""
    fi
    
    # Grant/verify permissions for ALL users (existing and new)
    log_info "Configuring permissions for all users..."
    for i in "${!user_names[@]}"; do
        local user_label="${role_labels[$i]}"
        if [[ "$GUM_AVAILABLE" == "true" ]]; then
            gum spin --spinner dot --title "Granting ${user_label} permissions..." -- \
                bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'; grant_all_permissions '$dbname' '${user_names[$i]}' '${role_types[$i]}' '$schemaname' 2>/dev/null"
        else
            echo "  → ${user_label}"
            grant_all_permissions "$dbname" "${user_names[$i]}" "${role_types[$i]}" "$schemaname" 2>/dev/null || true
        fi
    done
    log_success "Schema permissions configured"
    
    # Revoke PUBLIC schema access (full isolation) - only for non-public schemas
    if [[ "$schemaname" != "public" ]]; then
        if [[ "$GUM_AVAILABLE" == "true" ]]; then
            gum spin --spinner dot --title "Enforcing schema isolation..." -- \
                bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'
                         revoke_public_schema_access '$dbname' '$schemaname'
                         for username in ${user_names[*]}; do
                             revoke_all_permissions '$dbname' \"\$username\" 'public' 2>/dev/null
                         done"
        else
            echo -n "Enforcing schema isolation... "
            revoke_public_schema_access "$dbname" "$schemaname"
            for username in "${user_names[@]}"; do
                revoke_all_permissions "$dbname" "$username" "public" 2>/dev/null || true
            done
        fi
        log_success "Schema isolation enforced (no PUBLIC access)"
    else
        log_info "Skipping schema isolation (using public schema)"
    fi
    
    # Configure default privileges for future objects
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Setting default privileges..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'
                     set_default_privileges_for_all '$dbname' '$prefix' '$schemaname'"
    else
        echo -n "Setting default privileges... "
        set_default_privileges_for_all "$dbname" "$prefix" "$schemaname"
    fi
    log_success "Default privileges configured for future objects"
    
    echo ""
    
    # Display summary
    local users_created=${#users_missing[@]}
    local users_existing=${#users_exist[@]}
    
    local summary="✓ Schema Users Provisioned

Database: $dbname
Schema: $schemaname
Users created: $users_created
Users existing: $users_existing
Total users: 5
Isolation: Full (no PUBLIC/cross-schema)
Default privileges: ✓ Enabled
Status: Ready"
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum style --border rounded --padding "1 2" --border-foreground 10 "$summary"
    else
        log_box "$summary"
    fi
    
    # Display credentials for newly created users only
    if [[ ${#new_credentials[@]} -gt 0 ]]; then
        log_info "Displaying credentials for ${#new_credentials[@]} newly created user(s)..."
        echo ""
        display_credentials "NEW CREDENTIALS" \
            "Username|Password|Role" \
            "${new_credentials[@]}"
        echo ""
        display_connection_example "${user_names[3]}" "$dbname"
        echo ""
        log_warning "Save these credentials securely. They will not be shown again!"
    else
        echo ""
        log_info "No new users created. All users already existed."
        log_info "Permissions have been verified/repaired for all users."
    fi
}

# =============================================================================
# Command Wrappers for CLI
# =============================================================================

cmd_create_schema() {
    create_schema "$@"
}

cmd_delete_schema() {
    delete_schema "$@"
}

cmd_list_schemas() {
    list_schemas "$@"
}

cmd_list_schema_users() {
    list_schema_users "$@"
}

cmd_grant_schema_access() {
    grant_schema_access "$@"
}

cmd_add_schema_users() {
    add_schema_users "$@"
}

# =============================================================================
# Register Commands
# =============================================================================

register_command "Create Schema" "SCHEMA MANAGEMENT" "cmd_create_schema" \
    "Create a new schema with 5 standard users"

register_command "Delete Schema" "SCHEMA MANAGEMENT" "cmd_delete_schema" \
    "Delete a schema and all associated users"

register_command "List Schemas" "SCHEMA MANAGEMENT" "cmd_list_schemas" \
    "List all schemas in a database"

register_command "Grant Schema Access" "SCHEMA MANAGEMENT" "cmd_grant_schema_access" \
    "Grant existing user access to a schema"

register_command "Add Schema Users" "SCHEMA MANAGEMENT" "cmd_add_schema_users" \
    "Add/provision 5 standard users to a schema"
