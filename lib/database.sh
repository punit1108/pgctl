#!/bin/bash

# =============================================================================
# Database Library for pgctl
# =============================================================================
# Functions for creating, deleting, and listing databases
# =============================================================================

# Prevent multiple sourcing
[[ -n "${PGCTL_DATABASE_LOADED:-}" ]] && return
PGCTL_DATABASE_LOADED=1

# Source dependencies
_DATABASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_DATABASE_DIR}/common.sh"
source "${_DATABASE_DIR}/permissions.sh"

# =============================================================================
# Database Creation
# =============================================================================

# Create a database with 5 standard users
create_database() {
    local dbname="${1:-}"
    
    log_header "PostgreSQL Database Creation"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    # Get database name if not provided
    if [[ -z "$dbname" ]]; then
        dbname=$(prompt_input "Database name")
    fi
    
    # Validate database name
    if ! validate_database_name "$dbname"; then
        return 1
    fi
    
    # Validate user name lengths
    if ! validate_user_names_length "$dbname"; then
        log_warning "Would you like to continue with shorter name?"
        if ! prompt_confirm "Continue anyway?"; then
            return 1
        fi
    fi
    
    # Check if database already exists
    if database_exists "$dbname"; then
        log_error "Database '$dbname' already exists"
        return 1
    fi
    
    # Define user names
    local owner="${dbname}_owner"
    local migration="${dbname}_migration_user"
    local fullaccess="${dbname}_fullaccess_user"
    local app="${dbname}_app_user"
    local readonly="${dbname}_readonly_user"
    
    # Get passwords
    echo ""
    local owner_pass
    owner_pass=$(get_password "DB_OWNER_PASSWORD" "Owner password")
    
    local migration_pass
    migration_pass=$(get_password "DB_MIGRATION_PASSWORD" "Migration user password")
    
    local fullaccess_pass
    fullaccess_pass=$(get_password "DB_FULLACCESS_PASSWORD" "Full access user password")
    
    local app_pass
    app_pass=$(get_password "DB_APP_PASSWORD" "App user password")
    
    local readonly_pass
    readonly_pass=$(get_password "DB_READONLY_PASSWORD" "Read-only user password")
    
    echo ""
    
    # Create database
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Creating database $dbname..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin_quiet \"CREATE DATABASE $dbname;\""
    else
        echo -n "Creating database $dbname... "
        psql_admin_quiet "CREATE DATABASE $dbname;"
    fi
    log_success "Database created successfully"
    
    # Create owner user
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Creating $owner..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin_quiet \"CREATE ROLE $owner WITH LOGIN PASSWORD '$owner_pass' CREATEDB CREATEROLE;\""
    else
        echo -n "Creating $owner... "
        psql_admin_quiet "CREATE ROLE $owner WITH LOGIN PASSWORD '$owner_pass' CREATEDB CREATEROLE;"
    fi
    log_success "Database owner created"
    
    # Set database ownership
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Setting database ownership..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin_quiet \"ALTER DATABASE $dbname OWNER TO $owner;\""
    else
        echo -n "Setting database ownership... "
        psql_admin_quiet "ALTER DATABASE $dbname OWNER TO $owner;"
    fi
    log_success "Ownership configured"
    
    # Create migration user
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Creating $migration..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin_quiet \"CREATE ROLE $migration WITH LOGIN PASSWORD '$migration_pass';\""
    else
        echo -n "Creating $migration... "
        psql_admin_quiet "CREATE ROLE $migration WITH LOGIN PASSWORD '$migration_pass';"
    fi
    log_success "Migration user created"
    
    # Create fullaccess user
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Creating $fullaccess..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin_quiet \"CREATE ROLE $fullaccess WITH LOGIN PASSWORD '$fullaccess_pass';\""
    else
        echo -n "Creating $fullaccess... "
        psql_admin_quiet "CREATE ROLE $fullaccess WITH LOGIN PASSWORD '$fullaccess_pass';"
    fi
    log_success "Full access user created"
    
    # Create app user
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Creating $app..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin_quiet \"CREATE ROLE $app WITH LOGIN PASSWORD '$app_pass';\""
    else
        echo -n "Creating $app... "
        psql_admin_quiet "CREATE ROLE $app WITH LOGIN PASSWORD '$app_pass';"
    fi
    log_success "App user created"
    
    # Create readonly user
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Creating $readonly..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin_quiet \"CREATE ROLE $readonly WITH LOGIN PASSWORD '$readonly_pass';\""
    else
        echo -n "Creating $readonly... "
        psql_admin_quiet "CREATE ROLE $readonly WITH LOGIN PASSWORD '$readonly_pass';"
    fi
    log_success "Read-only user created"
    
    # Configure permissions (per-user progress)
    log_info "Configuring permissions for 5 users..."
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Granting owner permissions..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'; grant_all_permissions '$dbname' '$owner' 'owner' 'public'"
        gum spin --spinner dot --title "Granting migration_user permissions..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'; grant_all_permissions '$dbname' '$migration' 'migration_user' 'public'"
        gum spin --spinner dot --title "Granting fullaccess_user permissions..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'; grant_all_permissions '$dbname' '$fullaccess' 'fullaccess_user' 'public'"
        gum spin --spinner dot --title "Granting app_user permissions..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'; grant_all_permissions '$dbname' '$app' 'app_user' 'public'"
        gum spin --spinner dot --title "Granting readonly_user permissions..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'; grant_all_permissions '$dbname' '$readonly' 'readonly_user' 'public'"
    else
        echo "  → owner"
        grant_all_permissions "$dbname" "$owner" "owner" "public"
        echo "  → migration_user"
        grant_all_permissions "$dbname" "$migration" "migration_user" "public"
        echo "  → fullaccess_user"
        grant_all_permissions "$dbname" "$fullaccess" "fullaccess_user" "public"
        echo "  → app_user"
        grant_all_permissions "$dbname" "$app" "app_user" "public"
        echo "  → readonly_user"
        grant_all_permissions "$dbname" "$readonly" "readonly_user" "public"
    fi
    log_success "Permissions configured"
    
    # Configure default privileges for future objects
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Configuring default privileges..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'
                     set_default_privileges_for_all '$dbname' '$dbname' 'public'"
    else
        echo -n "Configuring default privileges... "
        set_default_privileges_for_all "$dbname" "$dbname" "public"
    fi
    log_success "Default privileges set for future objects"
    
    echo ""
    
    # Display success summary
    local summary="✓ Database Setup Complete

Database: $dbname
Owner: $owner
Users created: 5
Status: Ready"
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum style --border rounded --padding "1 2" --border-foreground 10 "$summary"
    else
        log_box "$summary"
    fi
    
    # Display credentials
    display_credentials "CREDENTIALS" \
        "Username|Password|Role" \
        "$owner|$owner_pass|owner" \
        "$migration|$migration_pass|migration" \
        "$fullaccess|$fullaccess_pass|fullaccess" \
        "$app|$app_pass|app" \
        "$readonly|$readonly_pass|readonly"
    
    display_connection_example "$app" "$dbname"
    
    log_warning "Save these credentials securely. They will not be shown again!"
}

# =============================================================================
# Database Deletion
# =============================================================================

# Helper: Delete a single database and its users
_delete_one_database() {
    local dbname="$1"
    
    # Terminate existing connections
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Terminating connections to $dbname..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin_quiet \"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$dbname' AND pid <> pg_backend_pid();\""
    else
        echo -n "Terminating connections to $dbname... "
        psql_admin_quiet "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$dbname' AND pid <> pg_backend_pid();"
    fi
    
    # Delete database
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Deleting database $dbname..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin_quiet \"DROP DATABASE IF EXISTS $dbname;\""
    else
        echo -n "Deleting database $dbname... "
        psql_admin_quiet "DROP DATABASE IF EXISTS $dbname;"
    fi
    log_success "Database $dbname deleted"
    
    # Delete users
    local users=("${dbname}_owner" "${dbname}_migration_user" "${dbname}_fullaccess_user" "${dbname}_app_user" "${dbname}_readonly_user")
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

# Delete a database and its users (supports multiselect and preselected list)
delete_database() {
    log_header "Delete Database"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    local selected_dbs=""
    
    # Determine mode: preselected list via args, or interactive multiselect
    if [[ $# -ge 1 && -n "$1" ]]; then
        # Preselected list mode: use all arguments as database names
        selected_dbs=$(printf '%s\n' "$@")
    else
        # Interactive multiselect mode
        local databases
        databases=$(list_with_loading "databases" "list_databases_query")
        
        if [[ -z "$databases" ]]; then
            log_error "No databases found"
            return 1
        fi
        
        # Use multiselect for interactive mode
        selected_dbs=$(prompt_select_multiple "Select database(s) to delete:" $databases)
        
        if [[ -z "$selected_dbs" ]]; then
            log_error "No databases selected"
            return 1
        fi
    fi
    
    # Count selected databases for message
    local db_count=0
    while IFS= read -r db; do
        [[ -n "$db" ]] && ((db_count++))
    done <<< "$selected_dbs"
    
    # Build confirmation message
    log_warning "This will permanently delete:"
    echo ""
    
    while IFS= read -r db; do
        [[ -z "$db" ]] && continue
        
        if ! database_exists "$db"; then
            continue
        fi
        
        echo "  Database: $db"
        echo "  Users:"
        local users=("${db}_owner" "${db}_migration_user" "${db}_fullaccess_user" "${db}_app_user" "${db}_readonly_user")
        for user in "${users[@]}"; do
            if user_exists "$user"; then
                echo "    - $user"
            fi
        done
        echo ""
    done <<< "$selected_dbs"
    
    # Confirm deletion (use plural message if multiple)
    local confirm_msg="Are you sure you want to delete this database?"
    if [[ $db_count -gt 1 ]]; then
        confirm_msg="Are you sure you want to delete these $db_count databases?"
    fi
    
    if ! prompt_confirm "$confirm_msg"; then
        log_info "Deletion cancelled"
        return 0
    fi
    
    # Delete each selected database
    while IFS= read -r db; do
        [[ -z "$db" ]] && continue
        
        if ! database_exists "$db"; then
            log_warning "Database '$db' does not exist, skipping"
            continue
        fi
        
        echo ""
        log_info "Deleting database: $db"
        _delete_one_database "$db"
    done <<< "$selected_dbs"
    
    echo ""
    if [[ $db_count -gt 1 ]]; then
        log_success "Selected databases and associated users deleted successfully"
    else
        log_success "Database and all associated users deleted successfully"
    fi
}

# =============================================================================
# Database Listing
# =============================================================================

# List all databases
list_databases() {
    log_header "Available Databases"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    local sql="SELECT d.datname AS database,
               pg_catalog.pg_get_userbyid(d.datdba) AS owner,
               pg_catalog.pg_encoding_to_char(d.encoding) AS encoding
               FROM pg_catalog.pg_database d
               WHERE d.datistemplate = false
               AND d.datname != 'postgres'
               ORDER BY d.datname;"
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        local result
        result=$(psql_admin "$sql" 2>/dev/null)
        echo "$result" | gum table
    else
        psql_admin "$sql"
    fi
}

# =============================================================================
# Command Wrappers for CLI
# =============================================================================

cmd_create_db() {
    create_database "$@"
}

cmd_delete_db() {
    delete_database "$@"
}

cmd_list_databases() {
    list_databases "$@"
}

# =============================================================================
# Database Details
# =============================================================================

# Get detailed information about a database
get_database_details() {
    local dbname="$1"
    
    if [[ -z "$dbname" ]]; then
        log_error "Database name required"
        return 1
    fi
    
    if ! database_exists "$dbname"; then
        log_error "Database '$dbname' does not exist"
        return 1
    fi
    
    log_info "Database: $dbname"
    echo ""
    
    local sql="SELECT 
        d.datname AS \"Database\",
        pg_catalog.pg_get_userbyid(d.datdba) AS \"Owner\",
        pg_catalog.pg_encoding_to_char(d.encoding) AS \"Encoding\",
        pg_size_pretty(pg_database_size(d.datname)) AS \"Size\",
        (SELECT COUNT(*) FROM pg_stat_activity WHERE datname = d.datname) AS \"Connections\"
    FROM pg_catalog.pg_database d
    WHERE d.datname = '$dbname';"
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        local result
        result=$(psql_admin "$sql" 2>/dev/null)
        echo "$result" | gum table
    else
        psql_admin "$sql"
    fi
    echo ""
}

# =============================================================================
# List Databases Menu (Interactive RUD)
# =============================================================================

# Interactive list databases with View/Delete actions
cmd_list_databases_menu() {
    log_header "List Databases"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    # Show the list first
    list_databases
    
    echo ""
    
    # Get database names for selection
    local db_names
    db_names=$(list_databases_query)
    
    if [[ -z "$db_names" ]]; then
        log_info "No databases to manage"
        return 0
    fi
    
    # Use shared RUD prompts helper
    _list_rud_prompts "$db_names" "Select database(s) for action:" "View details" "Delete" "Back"
    local rud_result=$?
    
    # Return code: 0 = action selected, 1 = empty, 2 = Back
    if [[ $rud_result -ne 0 ]]; then
        return 0
    fi
    
    # Dispatch based on action
    case "$RUD_ACTION" in
        "View details")
            while IFS= read -r db; do
                [[ -z "$db" ]] && continue
                echo ""
                get_database_details "$db"
            done <<< "$RUD_SELECTED"
            ;;
        "Delete")
            # Convert newline-separated to args
            local -a dbs=()
            while IFS= read -r db; do
                [[ -n "$db" ]] && dbs+=("$db")
            done <<< "$RUD_SELECTED"
            
            if [[ ${#dbs[@]} -gt 0 ]]; then
                delete_database "${dbs[@]}"
            fi
            ;;
    esac
}

# =============================================================================
# Register Commands
# =============================================================================

register_command "Create Database" "DATABASE MANAGEMENT" "cmd_create_db" \
    "Create a new database with 5 standard users"

register_command "Delete Database" "DATABASE MANAGEMENT" "cmd_delete_db" \
    "Delete a database and all associated users"

register_command "List Databases" "DATABASE MANAGEMENT" "cmd_list_databases_menu" \
    "List all available databases"
