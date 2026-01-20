#!/bin/bash

# =============================================================================
# Users Library for pgctl
# =============================================================================
# Functions for user management: create, delete, list, change password
# =============================================================================

# Prevent multiple sourcing
[[ -n "${PGCTL_USERS_LOADED:-}" ]] && return
PGCTL_USERS_LOADED=1

# Source dependencies
_USERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_USERS_DIR}/common.sh"
source "${_USERS_DIR}/permissions.sh"

# =============================================================================
# User Creation Wizard
# =============================================================================

# Interactive user creation wizard
create_user_wizard() {
    log_header "User Creation Wizard"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    # Get username
    local username
    username=$(prompt_input "Username")
    
    if [[ -z "$username" ]]; then
        log_error "Username cannot be empty"
        return 1
    fi
    
    # Validate username
    if ! validate_username "$username"; then
        return 1
    fi
    
    # Check if user already exists
    if user_exists "$username"; then
        log_error "User '$username' already exists"
        return 1
    fi
    
    # Select role type
    local role_types=("readonly_user" "app_user" "fullaccess_user" "migration_user" "owner" "custom")
    local role_type
    role_type=$(prompt_select "Select role type:" "${role_types[@]}")
    
    if [[ -z "$role_type" ]]; then
        log_error "No role type selected"
        return 1
    fi
    
    # Handle custom permissions
    local custom_table_perms=""
    local custom_seq_perms=""
    local custom_func_perms=""
    
    if [[ "$role_type" == "custom" ]]; then
        echo ""
        log_info "Select custom permissions:"
        
        local table_options=("SELECT" "INSERT" "UPDATE" "DELETE" "ALL")
        custom_table_perms=$(prompt_select_multiple "Table permissions:" "${table_options[@]}")
        custom_table_perms=$(echo "$custom_table_perms" | tr '\n' ', ' | sed 's/,$//')
        
        local seq_options=("USAGE" "SELECT" "ALL")
        custom_seq_perms=$(prompt_select_multiple "Sequence permissions:" "${seq_options[@]}")
        custom_seq_perms=$(echo "$custom_seq_perms" | tr '\n' ', ' | sed 's/,$//')
        
        custom_func_perms="EXECUTE"
    fi
    
    # Ask about future objects
    echo ""
    local apply_future=true
    if ! prompt_confirm "Apply permissions to future objects? (Recommended)"; then
        apply_future=false
    fi
    
    # Get target database(s)
    local databases
    databases=$(list_with_loading "databases" "list_databases_query")
    
    if [[ -z "$databases" ]]; then
        log_error "No databases found"
        return 1
    fi
    
    echo ""
    local target_dbs
    target_dbs=$(prompt_select_multiple "Select target database(s):" $databases)
    
    if [[ -z "$target_dbs" ]]; then
        log_error "No databases selected"
        return 1
    fi
    
    # Get password (allow empty for auto-generation)
    echo ""
    local password
    password=$(prompt_password "Password for $username (leave empty to auto-generate)")
    
    # Generate password if empty
    if [[ -z "$password" ]]; then
        password=$(generate_password)
        log_info "Generated secure password for $username"
    fi
    
    # Show summary
    echo ""
    local summary="User: $username
Role type: $role_type
Target database(s): $(echo "$target_dbs" | tr '\n' ', ' | sed 's/,$//')
Future objects: $(if $apply_future; then echo "Yes"; else echo "No"; fi)"
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum style --border rounded --padding "1 2" --border-foreground 12 "Summary" "$summary"
    else
        echo ""
        echo "Summary:"
        echo "$summary"
        echo ""
    fi
    
    # Confirm
    if ! prompt_confirm "Create user with these settings?"; then
        log_info "User creation cancelled"
        return 0
    fi
    
    echo ""
    
    # Create user
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Creating user $username..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin_quiet \"CREATE ROLE $username WITH LOGIN PASSWORD '$password';\""
    else
        echo -n "Creating user $username... "
        psql_admin_quiet "CREATE ROLE $username WITH LOGIN PASSWORD '$password';"
    fi
    log_success "User created"
    
    # Apply permissions to each database
    local db_count=0
    local db_total=$(echo "$target_dbs" | wc -l)
    while IFS= read -r dbname; do
        [[ -z "$dbname" ]] && continue
        ((db_count++))
        log_info "Configuring database $db_count of $db_total: $dbname"
        
        if [[ "$GUM_AVAILABLE" == "true" ]]; then
            gum spin --spinner dot --title "Granting permissions on $dbname..." -- \
                bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'
                         if [[ '$role_type' == 'custom' ]]; then
                             psql_admin_quiet \"GRANT USAGE ON SCHEMA public TO $username;\" '$dbname'
                             psql_admin_quiet \"GRANT $custom_table_perms ON ALL TABLES IN SCHEMA public TO $username;\" '$dbname'
                             psql_admin_quiet \"GRANT $custom_seq_perms ON ALL SEQUENCES IN SCHEMA public TO $username;\" '$dbname'
                             psql_admin_quiet \"GRANT $custom_func_perms ON ALL FUNCTIONS IN SCHEMA public TO $username;\" '$dbname'
                         else
                             grant_all_permissions '$dbname' '$username' '$role_type' 'public'
                         fi"
        else
            echo -n "Granting permissions on $dbname... "
            if [[ "$role_type" == "custom" ]]; then
                psql_admin_quiet "GRANT USAGE ON SCHEMA public TO $username;" "$dbname"
                psql_admin_quiet "GRANT $custom_table_perms ON ALL TABLES IN SCHEMA public TO $username;" "$dbname"
                psql_admin_quiet "GRANT $custom_seq_perms ON ALL SEQUENCES IN SCHEMA public TO $username;" "$dbname"
                psql_admin_quiet "GRANT $custom_func_perms ON ALL FUNCTIONS IN SCHEMA public TO $username;" "$dbname"
            else
                grant_all_permissions "$dbname" "$username" "$role_type" "public"
            fi
        fi
        log_success "Permissions granted on $dbname"
        
        # Set default privileges for future objects
        if $apply_future; then
            if [[ "$GUM_AVAILABLE" == "true" ]]; then
                gum spin --spinner dot --title "Setting default privileges on $dbname..." -- \
                    bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'
                             # Set default privileges for objects created by the db owner
                             local db_owner=\"${dbname}_owner\"
                             if user_exists \"\$db_owner\"; then
                                 set_default_privileges '$dbname' \"\$db_owner\" '$username' '$role_type' 'public'
                             fi"
            else
                echo -n "Setting default privileges on $dbname... "
                local db_owner="${dbname}_owner"
                if user_exists "$db_owner"; then
                    set_default_privileges "$dbname" "$db_owner" "$username" "$role_type" "public"
                fi
            fi
            log_success "Default privileges set on $dbname"
        fi
    done <<< "$target_dbs"
    
    echo ""
    log_success "User $username created successfully"
    
    # Display credentials
    local db_list
    db_list=$(echo "$target_dbs" | tr '\n' ';' | sed 's/;$//' | sed 's/;/; /g')
    local first_db
    first_db=$(echo "$target_dbs" | head -n 1)
    
    display_credentials "CREDENTIALS" \
        "Username|Password|Role|Databases" \
        "$username|$password|$role_type|$db_list"
    
    display_connection_example "$username" "$first_db"
    
    log_warning "Save these credentials securely. They will not be shown again!"
}

# =============================================================================
# View/Manage User Permissions
# =============================================================================

# View and manage user permissions interactively
view_user_permissions() {
    local username="${1:-}"
    local dbname="${2:-}"
    
    log_header "User Permission Management"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    # Get username if not provided
    if [[ -z "$username" ]]; then
        local users
        users=$(list_with_loading "users" "list_users_query")
        
        if [[ -z "$users" ]]; then
            log_error "No users found"
            return 1
        fi
        
        username=$(prompt_select "Select user:" $users)
        
        if [[ -z "$username" ]]; then
            log_error "No user selected"
            return 1
        fi
    fi
    
    # Get database if not provided
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
    
    while true; do
        echo ""
        log_info "User: $username | Database: $dbname"
        echo ""
        
        # Show schema permissions
        echo "Schema Permissions:"
        get_user_schema_permissions "$dbname" "$username"
        
        echo ""
        
        # Show table permissions summary
        echo "Table Permissions:"
        local table_perms
        table_perms=$(psql_admin "SELECT privilege_type, COUNT(*) as count 
                                   FROM information_schema.role_table_grants 
                                   WHERE grantee = '$username' AND table_schema = 'public'
                                   GROUP BY privilege_type
                                   ORDER BY privilege_type;" "$dbname" 2>/dev/null)
        echo "$table_perms"
        
        echo ""
        
        # Menu options
        local options=("Extend Permissions" "Revoke Permissions" "View Object Details" "Back to Main Menu")
        local action
        action=$(prompt_select "Select action:" "${options[@]}")
        
        case "$action" in
            "Extend Permissions")
                extend_user_permissions "$dbname" "$username"
                ;;
            "Revoke Permissions")
                revoke_user_permissions "$dbname" "$username"
                ;;
            "View Object Details")
                view_object_details "$dbname" "$username"
                ;;
            "Back to Main Menu"|"")
                return 0
                ;;
        esac
    done
}

# Extend user permissions
extend_user_permissions() {
    local dbname="$1"
    local username="$2"
    
    log_info "Extend Permissions for $username"
    echo ""
    
    local perm_options=("SELECT on all tables" "INSERT on all tables" "UPDATE on all tables" "DELETE on all tables" "USAGE on all sequences" "EXECUTE on all functions" "CREATE on schema")
    
    local selected
    selected=$(prompt_select_multiple "Select permissions to add:" "${perm_options[@]}")
    
    if [[ -z "$selected" ]]; then
        log_info "No permissions selected"
        return 0
    fi
    
    if ! prompt_confirm "Apply these permissions?"; then
        return 0
    fi
    
    echo ""
    
    while IFS= read -r perm; do
        [[ -z "$perm" ]] && continue
        
        case "$perm" in
            "SELECT on all tables")
                psql_admin_quiet "GRANT SELECT ON ALL TABLES IN SCHEMA public TO $username;" "$dbname"
                ;;
            "INSERT on all tables")
                psql_admin_quiet "GRANT INSERT ON ALL TABLES IN SCHEMA public TO $username;" "$dbname"
                ;;
            "UPDATE on all tables")
                psql_admin_quiet "GRANT UPDATE ON ALL TABLES IN SCHEMA public TO $username;" "$dbname"
                ;;
            "DELETE on all tables")
                psql_admin_quiet "GRANT DELETE ON ALL TABLES IN SCHEMA public TO $username;" "$dbname"
                ;;
            "USAGE on all sequences")
                psql_admin_quiet "GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO $username;" "$dbname"
                ;;
            "EXECUTE on all functions")
                psql_admin_quiet "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO $username;" "$dbname"
                ;;
            "CREATE on schema")
                psql_admin_quiet "GRANT CREATE ON SCHEMA public TO $username;" "$dbname"
                ;;
        esac
        log_success "Granted: $perm"
    done <<< "$selected"
    
    echo ""
    log_success "Permissions extended successfully"
}

# Revoke user permissions
revoke_user_permissions() {
    local dbname="$1"
    local username="$2"
    
    log_info "Revoke Permissions from $username"
    log_warning "Revoking permissions may break application functionality"
    echo ""
    
    local perm_options=("SELECT on all tables" "INSERT on all tables" "UPDATE on all tables" "DELETE on all tables" "USAGE on all sequences" "EXECUTE on all functions" "CREATE on schema" "ALL on all tables")
    
    local selected
    selected=$(prompt_select_multiple "Select permissions to revoke:" "${perm_options[@]}")
    
    if [[ -z "$selected" ]]; then
        log_info "No permissions selected"
        return 0
    fi
    
    if ! prompt_confirm "Are you sure you want to revoke these permissions?"; then
        return 0
    fi
    
    echo ""
    
    while IFS= read -r perm; do
        [[ -z "$perm" ]] && continue
        
        case "$perm" in
            "SELECT on all tables")
                psql_admin_quiet "REVOKE SELECT ON ALL TABLES IN SCHEMA public FROM $username;" "$dbname"
                ;;
            "INSERT on all tables")
                psql_admin_quiet "REVOKE INSERT ON ALL TABLES IN SCHEMA public FROM $username;" "$dbname"
                ;;
            "UPDATE on all tables")
                psql_admin_quiet "REVOKE UPDATE ON ALL TABLES IN SCHEMA public FROM $username;" "$dbname"
                ;;
            "DELETE on all tables")
                psql_admin_quiet "REVOKE DELETE ON ALL TABLES IN SCHEMA public FROM $username;" "$dbname"
                ;;
            "USAGE on all sequences")
                psql_admin_quiet "REVOKE USAGE ON ALL SEQUENCES IN SCHEMA public FROM $username;" "$dbname"
                ;;
            "EXECUTE on all functions")
                psql_admin_quiet "REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM $username;" "$dbname"
                ;;
            "CREATE on schema")
                psql_admin_quiet "REVOKE CREATE ON SCHEMA public FROM $username;" "$dbname"
                ;;
            "ALL on all tables")
                psql_admin_quiet "REVOKE ALL ON ALL TABLES IN SCHEMA public FROM $username;" "$dbname"
                ;;
        esac
        log_success "Revoked: $perm"
    done <<< "$selected"
    
    echo ""
    log_success "Permissions revoked successfully"
}

# View object details
view_object_details() {
    local dbname="$1"
    local username="$2"
    
    log_info "Object Details for $username in $dbname"
    echo ""
    
    local sql="SELECT table_name, STRING_AGG(privilege_type, ', ' ORDER BY privilege_type) as privileges
               FROM information_schema.role_table_grants
               WHERE grantee = '$username' AND table_schema = 'public'
               GROUP BY table_name
               ORDER BY table_name;"
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        local result
        result=$(psql_admin "$sql" "$dbname" 2>/dev/null)
        echo "$result" | gum table
    else
        psql_admin "$sql" "$dbname"
    fi
}

# =============================================================================
# User Management Functions
# =============================================================================

# Change user password
change_user_password() {
    local username="${1:-}"
    
    log_header "Change User Password"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    # Get username if not provided
    if [[ -z "$username" ]]; then
        local users
        users=$(list_with_loading "users" "list_users_query")
        
        if [[ -z "$users" ]]; then
            log_error "No users found"
            return 1
        fi
        
        username=$(prompt_select "Select user:" $users)
        
        if [[ -z "$username" ]]; then
            log_error "No user selected"
            return 1
        fi
    fi
    
    # Verify user exists
    if ! user_exists "$username"; then
        log_error "User '$username' does not exist"
        return 1
    fi
    
    # Get new password
    echo ""
    local password
    password=$(prompt_password "New password for $username")
    
    if [[ -z "$password" ]]; then
        log_error "Password cannot be empty"
        return 1
    fi
    
    # Confirm password
    local password_confirm
    password_confirm=$(prompt_password "Confirm password")
    
    if [[ "$password" != "$password_confirm" ]]; then
        log_error "Passwords do not match"
        return 1
    fi
    
    # Change password
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Changing password..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin_quiet \"ALTER ROLE $username WITH PASSWORD '$password';\""
    else
        echo -n "Changing password... "
        psql_admin_quiet "ALTER ROLE $username WITH PASSWORD '$password';"
    fi
    
    echo ""
    log_success "Password changed successfully for $username"
    
    # Display new credentials
    display_credentials "NEW PASSWORD" \
        "Username|Password" \
        "$username|$password"
    
    log_warning "Save this password securely. It will not be shown again!"
}

# Helper function to get all databases for user cleanup
_get_all_databases_for_cleanup() {
    # Get all databases except templates and postgres
    # Use sed to remove last 2 lines (cross-platform compatible)
    psql_admin "SELECT datname FROM pg_database 
                WHERE datistemplate = false 
                AND datname != 'postgres' 
                ORDER BY datname;" 2>/dev/null | tail -n +3 | sed '$d' | sed '$d' | tr -d ' '
}

# Helper function to clean user privileges from all databases
_clean_user_from_all_databases() {
    local username="$1"
    
    # Get all databases
    local all_dbs
    all_dbs=$(_get_all_databases_for_cleanup)
    
    # Clean privileges from each database
    while IFS= read -r dbname; do
        [[ -z "$dbname" ]] && continue
        
        # Skip if database doesn't exist
        if ! database_exists "$dbname"; then
            continue
        fi
        
        # Revoke database-level privileges
        psql_admin_quiet "REVOKE ALL PRIVILEGES ON DATABASE $dbname FROM $username;" 2>/dev/null || true
        
        # Revoke schema-level privileges
        psql_admin_quiet "REVOKE ALL ON SCHEMA public FROM $username;" "$dbname" 2>/dev/null || true
        
        # Revoke all table/sequence/function privileges
        psql_admin_quiet "REVOKE ALL ON ALL TABLES IN SCHEMA public FROM $username;" "$dbname" 2>/dev/null || true
        psql_admin_quiet "REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM $username;" "$dbname" 2>/dev/null || true
        psql_admin_quiet "REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM $username;" "$dbname" 2>/dev/null || true
        
        # Reassign owned objects and drop privileges
        psql_admin_quiet "REASSIGN OWNED BY $username TO $PGADMIN;" "$dbname" 2>/dev/null || true
        psql_admin_quiet "DROP OWNED BY $username;" "$dbname" 2>/dev/null || true
    done <<< "$all_dbs"
    
    # Also clean from the postgres database
    psql_admin_quiet "REVOKE ALL PRIVILEGES ON DATABASE postgres FROM $username;" 2>/dev/null || true
    psql_admin_quiet "REVOKE ALL ON SCHEMA public FROM $username;" "postgres" 2>/dev/null || true
    psql_admin_quiet "REVOKE ALL ON ALL TABLES IN SCHEMA public FROM $username;" "postgres" 2>/dev/null || true
    psql_admin_quiet "REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM $username;" "postgres" 2>/dev/null || true
    psql_admin_quiet "REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM $username;" "postgres" 2>/dev/null || true
    psql_admin_quiet "REASSIGN OWNED BY $username TO $PGADMIN;" "postgres" 2>/dev/null || true
    psql_admin_quiet "DROP OWNED BY $username;" "postgres" 2>/dev/null || true
    
    # Revoke all role memberships
    local member_of
    member_of=$(psql_admin "SELECT string_agg(roleid::regrole::text, ',') FROM pg_auth_members WHERE member = (SELECT oid FROM pg_roles WHERE rolname = '$username');" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ -n "$member_of" && "$member_of" != "" ]]; then
        IFS=',' read -ra roles <<< "$member_of"
        for role in "${roles[@]}"; do
            [[ -z "$role" ]] && continue
            psql_admin_quiet "REVOKE $role FROM $username;" 2>/dev/null || true
        done
    fi
}

# Delete user (supports multiselect)
delete_user() {
    local username="${1:-}"
    
    log_header "Delete User"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    # Get username(s) if not provided
    if [[ -z "$username" ]]; then
        local users
        users=$(list_with_loading "users" "list_users_query")
        
        if [[ -z "$users" ]]; then
            log_error "No users found"
            return 1
        fi
        
        # Use multiselect for interactive mode
        local selected_users
        selected_users=$(prompt_select_multiple "Select user(s) to delete:" $users)
        
        if [[ -z "$selected_users" ]]; then
            log_error "No users selected"
            return 1
        fi
        
        # Check which users own objects
        local -a users_need_reassign=()
        local -a users_clean=()
        
        while IFS= read -r user; do
            [[ -z "$user" ]] && continue
            
            if ! user_exists "$user"; then
                continue
            fi
            
            local owned_objects
            owned_objects=$(psql_admin "SELECT COUNT(*) FROM pg_class WHERE relowner = (SELECT oid FROM pg_roles WHERE rolname = '$user');" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
            
            if [[ "${owned_objects:-0}" -gt 0 ]]; then
                users_need_reassign+=("$user (owns $owned_objects objects)")
            else
                users_clean+=("$user")
            fi
        done <<< "$selected_users"
        
        # Build confirmation message
        log_warning "This will permanently delete:"
        echo ""
        
        if [[ ${#users_need_reassign[@]} -gt 0 ]]; then
            echo "  Users with owned objects (will be reassigned to $PGADMIN):"
            for user_info in "${users_need_reassign[@]}"; do
                echo "    - $user_info"
            done
            echo ""
        fi
        
        if [[ ${#users_clean[@]} -gt 0 ]]; then
            echo "  Users without owned objects:"
            for user in "${users_clean[@]}"; do
                echo "    - $user"
            done
            echo ""
        fi
        
        # Confirm deletion
        if ! prompt_confirm "Are you sure you want to delete these user(s)?"; then
            log_info "Deletion cancelled"
            return 0
        fi
        
        # Delete each selected user
        local deletion_errors=0
        while IFS= read -r user; do
            [[ -z "$user" ]] && continue
            
            if ! user_exists "$user"; then
                log_warning "User '$user' does not exist, skipping"
                continue
            fi
            
            echo ""
            log_info "Deleting user: $user"
            
            # Clean privileges from all databases
            if [[ "$GUM_AVAILABLE" == "true" ]]; then
                gum spin --spinner dot --title "Cleaning privileges from all databases..." -- \
                    bash -c "source '${PGCTL_LIB_DIR}/users.sh' && _clean_user_from_all_databases '$user'"
            else
                echo -n "Cleaning privileges from all databases... "
                _clean_user_from_all_databases "$user"
                echo "done"
            fi
            
            # Now drop the user role
            local drop_output
            local drop_result
            
            if [[ "$GUM_AVAILABLE" == "true" ]]; then
                drop_output=$(gum spin --spinner dot --title "Deleting user $user..." -- \
                    bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin \"DROP ROLE $user;\"")
                drop_result=$?
            else
                echo -n "Deleting user $user... "
                drop_output=$(psql_admin "DROP ROLE $user;")
                drop_result=$?
            fi
            
            if [[ $drop_result -eq 0 ]]; then
                log_success "User '$user' deleted"
            else
                log_error "Failed to delete user '$user'"
                # Show the actual error message
                if [[ -n "$drop_output" ]]; then
                    echo "  Error details: $drop_output" | grep -i "error" || echo "  $drop_output"
                fi
                ((deletion_errors++))
            fi
        done <<< "$selected_users"
        
        echo ""
        if [[ $deletion_errors -eq 0 ]]; then
            log_success "All selected users deleted successfully"
        else
            log_warning "Completed with $deletion_errors error(s)"
            return 1
        fi
        
    else
        # Single user mode (CLI argument provided)
        # Verify user exists
        if ! user_exists "$username"; then
            log_error "User '$username' does not exist"
            return 1
        fi
        
        # Check for owned objects
        local owned_objects
        owned_objects=$(psql_admin "SELECT COUNT(*) FROM pg_class WHERE relowner = (SELECT oid FROM pg_roles WHERE rolname = '$username');" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
        
        if [[ "${owned_objects:-0}" -gt 0 ]]; then
            log_warning "User '$username' owns $owned_objects objects"
            log_warning "These objects will be reassigned to $PGADMIN before deletion"
        fi
        
        log_warning "This will permanently delete user '$username' and revoke all privileges across all databases"
        
        if ! prompt_confirm "Are you sure you want to delete this user?"; then
            log_info "Deletion cancelled"
            return 0
        fi
        
        echo ""
        
        # Clean privileges from all databases
        if [[ "$GUM_AVAILABLE" == "true" ]]; then
            gum spin --spinner dot --title "Cleaning privileges from all databases..." -- \
                bash -c "source '${PGCTL_LIB_DIR}/users.sh' && _clean_user_from_all_databases '$username'"
        else
            echo -n "Cleaning privileges from all databases... "
            _clean_user_from_all_databases "$username"
            echo "done"
        fi
        
        # Now drop the user role
        local drop_output
        local drop_result
        
        if [[ "$GUM_AVAILABLE" == "true" ]]; then
            drop_output=$(gum spin --spinner dot --title "Deleting user $username..." -- \
                bash -c "source '${PGCTL_LIB_DIR}/common.sh'; psql_admin \"DROP ROLE $username;\"")
            drop_result=$?
        else
            echo -n "Deleting user $username... "
            drop_output=$(psql_admin "DROP ROLE $username;")
            drop_result=$?
        fi
        
        if [[ $drop_result -eq 0 ]]; then
            echo ""
            log_success "User '$username' deleted successfully"
        else
            echo ""
            log_error "Failed to delete user '$username'"
            # Show the actual error message
            if [[ -n "$drop_output" ]]; then
                echo "  Error details: $drop_output" | grep -i "error" || echo "  $drop_output"
            fi
            return 1
        fi
    fi
}

# List users
list_users() {
    local dbname="${1:-}"
    
    log_header "Database Users"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    local sql
    
    if [[ -n "$dbname" ]]; then
        log_info "Database: $dbname"
        echo ""
        
        # List users with access to this database
        sql="SELECT r.rolname AS username,
             CASE 
                 WHEN r.rolname LIKE '%_owner' THEN 'owner'
                 WHEN r.rolname LIKE '%_migration_user' THEN 'migration'
                 WHEN r.rolname LIKE '%_fullaccess_user' THEN 'fullaccess'
                 WHEN r.rolname LIKE '%_app_user' THEN 'app'
                 WHEN r.rolname LIKE '%_readonly_user' THEN 'readonly'
                 ELSE 'custom'
             END AS role_type,
             CASE WHEN r.rolcanlogin THEN 'Yes' ELSE 'No' END AS can_login,
             CASE WHEN r.rolcreatedb THEN 'Yes' ELSE 'No' END AS can_createdb,
             CASE WHEN r.rolcreaterole THEN 'Yes' ELSE 'No' END AS can_createrole
             FROM pg_roles r
             WHERE r.rolcanlogin = true
             AND (r.rolname LIKE '${dbname}_%' OR r.rolname = 'postgres')
             ORDER BY r.rolname;"
    else
        # List all users
        sql="SELECT r.rolname AS username,
             CASE 
                 WHEN r.rolname LIKE '%_owner' THEN 'owner'
                 WHEN r.rolname LIKE '%_migration_user' THEN 'migration'
                 WHEN r.rolname LIKE '%_fullaccess_user' THEN 'fullaccess'
                 WHEN r.rolname LIKE '%_app_user' THEN 'app'
                 WHEN r.rolname LIKE '%_readonly_user' THEN 'readonly'
                 ELSE 'custom'
             END AS role_type,
             CASE WHEN r.rolcanlogin THEN 'Yes' ELSE 'No' END AS can_login
             FROM pg_roles r
             WHERE r.rolcanlogin = true
             AND r.rolname NOT LIKE 'pg_%'
             ORDER BY r.rolname;"
    fi
    
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

cmd_create_user() {
    create_user_wizard "$@"
}

cmd_change_password() {
    change_user_password "$@"
}

cmd_delete_user() {
    delete_user "$@"
}

cmd_list_users() {
    list_users "$@"
}

cmd_view_user() {
    view_user_permissions "$@"
}

# =============================================================================
# Register Commands
# =============================================================================

register_command "Create User" "USER MANAGEMENT" "cmd_create_user" \
    "Interactive user creation wizard"

register_command "Change Password" "USER MANAGEMENT" "cmd_change_password" \
    "Change user password"

register_command "Delete User" "USER MANAGEMENT" "cmd_delete_user" \
    "Delete a user"

register_command "List Users" "USER MANAGEMENT" "cmd_list_users" \
    "List all database users"

register_command "View User Permissions" "USER MANAGEMENT" "cmd_view_user" \
    "View and manage user permissions"
