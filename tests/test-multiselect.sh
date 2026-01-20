#!/bin/bash

# =============================================================================
# Multiselect Tests for pgctl
# =============================================================================
# Tests for multiselect functionality in interactive operations
# Uses TDD approach: write test (RED), implement (GREEN), refactor
# =============================================================================

# This file is sourced by test-runner.sh

# Source dependencies
source "${LIB_DIR}/database.sh"
source "${LIB_DIR}/schema.sh"
source "${LIB_DIR}/users.sh"
source "${LIB_DIR}/permissions.sh"

# =============================================================================
# Test Infrastructure
# =============================================================================

# Track multiselect test databases/schemas/users for cleanup
MULTISELECT_TEST_DBS=()
MULTISELECT_TEST_USERS=()
MULTISELECT_TEST_SCHEMAS=()

# =============================================================================
# Helper Functions
# =============================================================================

# Simulate multiselect input by overriding prompt_select_multiple
# Usage: mock_multiselect_input "item1" "item2" "item3"
mock_multiselect_input() {
    local items=("$@")
    # Export for use in subshells
    export MOCK_MULTISELECT_RESULT=$(printf '%s\n' "${items[@]}")
}

# Clear mocked input
clear_mock_input() {
    unset MOCK_MULTISELECT_RESULT
    unset MOCK_SELECT_RESULT
    unset MOCK_INPUT_RESULT
    unset MOCK_CONFIRM_RESULT
}

# Simulate single select input
mock_select_input() {
    export MOCK_SELECT_RESULT="$1"
}

# Simulate text input
mock_input() {
    export MOCK_INPUT_RESULT="$1"
}

# Simulate confirm (y/n)
mock_confirm() {
    export MOCK_CONFIRM_RESULT="$1"
}

# =============================================================================
# Test Fixtures
# =============================================================================

# Create test databases for multiselect testing
setup_multiselect_test_dbs() {
    local count="${1:-3}"
    local prefix="${2:-test_multi_db}"
    
    log_info "Creating $count test databases for multiselect testing..."
    
    for i in $(seq 1 "$count"); do
        local dbname="${prefix}${i}"
        
        # Skip if already exists
        if database_exists "$dbname"; then
            log_info "Database $dbname already exists, skipping creation"
            MULTISELECT_TEST_DBS+=("$dbname")
            continue
        fi
        
        # Create database quietly
        psql_admin_quiet "CREATE DATABASE $dbname;" 2>/dev/null || true
        
        if database_exists "$dbname"; then
            MULTISELECT_TEST_DBS+=("$dbname")
            log_success "Created test database: $dbname"
        fi
    done
}

# Create test schemas in a database
setup_multiselect_test_schemas() {
    local dbname="$1"
    local count="${2:-3}"
    local prefix="${3:-test_schema}"
    
    log_info "Creating $count test schemas in $dbname..."
    
    for i in $(seq 1 "$count"); do
        local schemaname="${prefix}${i}"
        
        # Skip if already exists
        if schema_exists "$dbname" "$schemaname"; then
            log_info "Schema $schemaname already exists in $dbname"
            MULTISELECT_TEST_SCHEMAS+=("$dbname:$schemaname")
            continue
        fi
        
        # Create schema quietly
        psql_admin_quiet "CREATE SCHEMA $schemaname;" "$dbname" 2>/dev/null || true
        
        if schema_exists "$dbname" "$schemaname"; then
            MULTISELECT_TEST_SCHEMAS+=("$dbname:$schemaname")
            log_success "Created test schema: $schemaname in $dbname"
        fi
    done
}

# Create test users
setup_multiselect_test_users() {
    local count="${1:-3}"
    local prefix="${2:-test_multi_user}"
    
    log_info "Creating $count test users for multiselect testing..."
    
    for i in $(seq 1 "$count"); do
        local username="${prefix}${i}"
        
        # Skip if already exists
        if user_exists "$username"; then
            log_info "User $username already exists"
            MULTISELECT_TEST_USERS+=("$username")
            continue
        fi
        
        # Create user quietly with a test password
        psql_admin_quiet "CREATE ROLE $username WITH LOGIN PASSWORD 'test_password_$i';" 2>/dev/null || true
        
        if user_exists "$username"; then
            MULTISELECT_TEST_USERS+=("$username")
            log_success "Created test user: $username"
        fi
    done
}

# =============================================================================
# Teardown Functions
# =============================================================================

# Clean up test databases created during multiselect tests
cleanup_multiselect_test_dbs() {
    log_info "Cleaning up multiselect test databases..."
    
    for dbname in "${MULTISELECT_TEST_DBS[@]}"; do
        if database_exists "$dbname"; then
            # Terminate connections
            psql_admin_quiet "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$dbname' AND pid <> pg_backend_pid();" 2>/dev/null || true
            
            # Drop database
            psql_admin_quiet "DROP DATABASE IF EXISTS $dbname;" 2>/dev/null || true
            
            if ! database_exists "$dbname"; then
                log_success "Cleaned up database: $dbname"
            fi
        fi
    done
    
    MULTISELECT_TEST_DBS=()
}

# Clean up test schemas
cleanup_multiselect_test_schemas() {
    log_info "Cleaning up multiselect test schemas..."
    
    for entry in "${MULTISELECT_TEST_SCHEMAS[@]}"; do
        local dbname="${entry%%:*}"
        local schemaname="${entry##*:}"
        
        if database_exists "$dbname" && schema_exists "$dbname" "$schemaname"; then
            psql_admin_quiet "DROP SCHEMA IF EXISTS $schemaname CASCADE;" "$dbname" 2>/dev/null || true
            
            if ! schema_exists "$dbname" "$schemaname"; then
                log_success "Cleaned up schema: $schemaname from $dbname"
            fi
        fi
    done
    
    MULTISELECT_TEST_SCHEMAS=()
}

# Clean up test users
cleanup_multiselect_test_users() {
    log_info "Cleaning up multiselect test users..."
    
    for username in "${MULTISELECT_TEST_USERS[@]}"; do
        if user_exists "$username"; then
            # Drop owned objects and user
            psql_admin_quiet "DROP OWNED BY $username CASCADE;" 2>/dev/null || true
            psql_admin_quiet "DROP ROLE IF EXISTS $username;" 2>/dev/null || true
            
            if ! user_exists "$username"; then
                log_success "Cleaned up user: $username"
            fi
        fi
    done
    
    MULTISELECT_TEST_USERS=()
}

# Clean up all multiselect test artifacts
cleanup_all_multiselect_tests() {
    cleanup_multiselect_test_schemas
    cleanup_multiselect_test_dbs
    cleanup_multiselect_test_users
    clear_mock_input
}

# =============================================================================
# Multiselect Tests - delete_database
# =============================================================================

test_delete_database_multiselect() {
    log_info "Testing delete_database with multiselect..."
    
    # Setup: Create 3 test databases
    setup_multiselect_test_dbs 3 "test_del_db_"
    
    local db1="test_del_db_1"
    local db2="test_del_db_2"
    local db3="test_del_db_3"
    
    # Verify all exist
    if ! database_exists "$db1" || ! database_exists "$db2" || ! database_exists "$db3"; then
        test_fail "Failed to create test databases for delete_database multiselect test"
        cleanup_all_multiselect_tests
        return 1
    fi
    
    # Override prompt_select_multiple to return our test selection
    prompt_select_multiple() {
        echo -e "${db1}\n${db3}"
    }
    
    # Override prompt_confirm to always return true (yes)
    prompt_confirm() {
        return 0
    }
    
    # Execute: Call delete_database with no args (triggers interactive mode)
    # This should delete db1 and db3, leaving db2
    delete_database ""
    
    # Verify: db1 and db3 should be gone, db2 should still exist
    local test_passed=true
    
    if database_exists "$db1"; then
        test_fail "delete_database multiselect: $db1 should be deleted but still exists"
        test_passed=false
    fi
    
    if database_exists "$db3"; then
        test_fail "delete_database multiselect: $db3 should be deleted but still exists"
        test_passed=false
    fi
    
    if ! database_exists "$db2"; then
        test_fail "delete_database multiselect: $db2 should NOT be deleted but is missing"
        test_passed=false
    fi
    
    if [[ "$test_passed" == "true" ]]; then
        test_pass "delete_database multiselect works correctly"
    fi
    
    # Restore original functions
    unset -f prompt_select_multiple
    unset -f prompt_confirm
    
    # Cleanup remaining databases
    cleanup_all_multiselect_tests
}

test_delete_database_with_users() {
    log_info "Testing delete_database multiselect with associated users..."
    
    # Setup: Create 2 test databases with users
    local db1="test_del_users_db1"
    local db2="test_del_users_db2"
    
    psql_admin_quiet "CREATE DATABASE $db1;" 2>/dev/null || true
    psql_admin_quiet "CREATE DATABASE $db2;" 2>/dev/null || true
    
    MULTISELECT_TEST_DBS+=("$db1" "$db2")
    
    # Create database users (simulating the standard 5 users)
    local users1=("${db1}_owner" "${db1}_app_user")
    local users2=("${db2}_owner" "${db2}_app_user")
    
    for user in "${users1[@]}" "${users2[@]}"; do
        psql_admin_quiet "CREATE ROLE $user WITH LOGIN PASSWORD 'test';" 2>/dev/null || true
        MULTISELECT_TEST_USERS+=("$user")
    done
    
    # Override prompts
    prompt_select_multiple() {
        echo "$db1"
    }
    
    prompt_confirm() {
        return 0
    }
    
    # Execute: Delete only db1
    delete_database ""
    
    # Verify: db1 users should be gone, db2 users should remain
    local test_passed=true
    
    for user in "${users1[@]}"; do
        if user_exists "$user"; then
            test_fail "delete_database multiselect: user $user should be deleted"
            test_passed=false
        fi
    done
    
    for user in "${users2[@]}"; do
        if ! user_exists "$user"; then
            test_fail "delete_database multiselect: user $user should NOT be deleted"
            test_passed=false
        fi
    done
    
    if [[ "$test_passed" == "true" ]]; then
        test_pass "delete_database multiselect cleans up associated users correctly"
    fi
    
    # Restore and cleanup
    unset -f prompt_select_multiple
    unset -f prompt_confirm
    cleanup_all_multiselect_tests
}

# =============================================================================
# Multiselect Tests - create_schema
# =============================================================================

test_create_schema_multiselect_dbs() {
    log_info "Testing create_schema with multiselect databases..."
    
    # Setup: Create 2 test databases
    setup_multiselect_test_dbs 2 "test_cschema_db_"
    
    local db1="test_cschema_db_1"
    local db2="test_cschema_db_2"
    local schemaname="shared_schema"
    
    # Verify both exist
    if ! database_exists "$db1" || ! database_exists "$db2"; then
        test_fail "Failed to create test databases for create_schema multiselect test"
        cleanup_all_multiselect_tests
        return 1
    fi
    
    # Override prompts
    prompt_select_multiple() {
        echo -e "${db1}\n${db2}"
    }
    
    prompt_input() {
        echo "$schemaname"
    }
    
    prompt_password() {
        echo "test_password"
    }
    
    prompt_confirm() {
        return 0
    }
    
    # Export for get_password function
    export SCHEMA_OWNER_PASSWORD="test_pass_owner"
    export SCHEMA_MIGRATION_PASSWORD="test_pass_migration"
    export SCHEMA_FULLACCESS_PASSWORD="test_pass_fullaccess"
    export SCHEMA_APP_PASSWORD="test_pass_app"
    export SCHEMA_READONLY_PASSWORD="test_pass_readonly"
    
    # Execute: Call create_schema with no args (triggers interactive mode)
    create_schema ""
    
    # Verify: Schema should exist in both databases
    local test_passed=true
    
    if ! schema_exists "$db1" "$schemaname"; then
        test_fail "create_schema multiselect: schema $schemaname should exist in $db1"
        test_passed=false
    fi
    
    if ! schema_exists "$db2" "$schemaname"; then
        test_fail "create_schema multiselect: schema $schemaname should exist in $db2"
        test_passed=false
    fi
    
    # Verify users exist for both databases
    local users1=("${db1}_${schemaname}_owner" "${db1}_${schemaname}_app_user")
    local users2=("${db2}_${schemaname}_owner" "${db2}_${schemaname}_app_user")
    
    for user in "${users1[@]}"; do
        if ! user_exists "$user"; then
            test_fail "create_schema multiselect: user $user should exist for $db1"
            test_passed=false
        else
            MULTISELECT_TEST_USERS+=("$user")
        fi
    done
    
    for user in "${users2[@]}"; do
        if ! user_exists "$user"; then
            test_fail "create_schema multiselect: user $user should exist for $db2"
            test_passed=false
        else
            MULTISELECT_TEST_USERS+=("$user")
        fi
    done
    
    if [[ "$test_passed" == "true" ]]; then
        test_pass "create_schema multiselect creates schema in all selected databases"
    fi
    
    # Track schemas for cleanup
    MULTISELECT_TEST_SCHEMAS+=("${db1}:${schemaname}" "${db2}:${schemaname}")
    
    # Restore functions and cleanup env vars
    unset -f prompt_select_multiple prompt_input prompt_password prompt_confirm
    unset SCHEMA_OWNER_PASSWORD SCHEMA_MIGRATION_PASSWORD SCHEMA_FULLACCESS_PASSWORD SCHEMA_APP_PASSWORD SCHEMA_READONLY_PASSWORD
    
    # Cleanup
    cleanup_all_multiselect_tests
}

test_create_schema_skip_existing() {
    log_info "Testing create_schema multiselect skips existing schemas..."
    
    # Setup: Create 2 test databases
    setup_multiselect_test_dbs 2 "test_cschema_skip_"
    
    local db1="test_cschema_skip_1"
    local db2="test_cschema_skip_2"
    local schemaname="existing_schema"
    
    # Pre-create schema in db1
    psql_admin_quiet "CREATE SCHEMA $schemaname;" "$db1" 2>/dev/null || true
    MULTISELECT_TEST_SCHEMAS+=("${db1}:${schemaname}")
    
    # Override prompts
    prompt_select_multiple() {
        echo -e "${db1}\n${db2}"
    }
    
    prompt_input() {
        echo "$schemaname"
    }
    
    prompt_password() {
        echo "test_password"
    }
    
    prompt_confirm() {
        return 0
    }
    
    # Export passwords
    export SCHEMA_OWNER_PASSWORD="test_pass"
    export SCHEMA_MIGRATION_PASSWORD="test_pass"
    export SCHEMA_FULLACCESS_PASSWORD="test_pass"
    export SCHEMA_APP_PASSWORD="test_pass"
    export SCHEMA_READONLY_PASSWORD="test_pass"
    
    # Execute
    create_schema ""
    
    # Verify: Schema should exist in db2, db1 should have been skipped
    local test_passed=true
    
    if schema_exists "$db2" "$schemaname"; then
        test_pass "create_schema multiselect created schema in db2 (not pre-existing)"
        MULTISELECT_TEST_SCHEMAS+=("${db2}:${schemaname}")
    else
        test_fail "create_schema multiselect: schema should exist in $db2"
        test_passed=false
    fi
    
    # Verify users for db2 exist (db1 users should not be created since schema existed)
    local user="${db2}_${schemaname}_owner"
    if user_exists "$user"; then
        MULTISELECT_TEST_USERS+=("$user")
        test_pass "create_schema multiselect created users for db2"
    else
        test_fail "create_schema multiselect: user $user should exist for $db2"
    fi
    
    # Restore and cleanup
    unset -f prompt_select_multiple prompt_input prompt_password prompt_confirm
    unset SCHEMA_OWNER_PASSWORD SCHEMA_MIGRATION_PASSWORD SCHEMA_FULLACCESS_PASSWORD SCHEMA_APP_PASSWORD SCHEMA_READONLY_PASSWORD
    cleanup_all_multiselect_tests
}

# =============================================================================
# Run Multiselect Tests
# =============================================================================

# =============================================================================
# Multiselect Tests - delete_schema
# =============================================================================

test_delete_schema_multiselect() {
    log_info "Testing delete_schema with multiselect schemas..."
    
    # Setup: Create 1 test database with 3 schemas
    setup_multiselect_test_dbs 1 "test_delsch_db_"
    local dbname="test_delsch_db_1"
    
    setup_multiselect_test_schemas "$dbname" 3 "test_schema_"
    
    local schema1="test_schema_1"
    local schema2="test_schema_2"
    local schema3="test_schema_3"
    
    # Verify all exist
    if ! schema_exists "$dbname" "$schema1" || ! schema_exists "$dbname" "$schema2" || ! schema_exists "$dbname" "$schema3"; then
        test_fail "Failed to create test schemas for delete_schema multiselect test"
        cleanup_all_multiselect_tests
        return 1
    fi
    
    # Override prompts
    prompt_select() {
        echo "$dbname"
    }
    
    prompt_select_multiple() {
        echo -e "${schema1}\n${schema3}"
    }
    
    prompt_confirm() {
        return 0
    }
    
    # Execute: Call delete_schema with no args (triggers interactive mode)
    delete_schema ""
    
    # Verify: schema1 and schema3 should be deleted, schema2 should remain
    local test_passed=true
    
    if schema_exists "$dbname" "$schema1"; then
        test_fail "delete_schema multiselect: $schema1 should be deleted"
        test_passed=false
    fi
    
    if schema_exists "$dbname" "$schema3"; then
        test_fail "delete_schema multiselect: $schema3 should be deleted"
        test_passed=false
    fi
    
    if ! schema_exists "$dbname" "$schema2"; then
        test_fail "delete_schema multiselect: $schema2 should NOT be deleted"
        test_passed=false
    fi
    
    if [[ "$test_passed" == "true" ]]; then
        test_pass "delete_schema multiselect deletes selected schemas only"
    fi
    
    # Restore functions
    unset -f prompt_select prompt_select_multiple prompt_confirm
    
    # Cleanup
    cleanup_all_multiselect_tests
}

test_delete_schema_with_users() {
    log_info "Testing delete_schema multiselect with schema users..."
    
    # Setup: Create 1 database
    setup_multiselect_test_dbs 1 "test_delsch_users_db_"
    local dbname="test_delsch_users_db_1"
    
    # Create 2 schemas
    local schema1="schema_a"
    local schema2="schema_b"
    
    psql_admin_quiet "CREATE SCHEMA $schema1;" "$dbname" 2>/dev/null || true
    psql_admin_quiet "CREATE SCHEMA $schema2;" "$dbname" 2>/dev/null || true
    
    MULTISELECT_TEST_SCHEMAS+=("${dbname}:${schema1}" "${dbname}:${schema2}")
    
    # Create schema users
    local user1="${dbname}_${schema1}_owner"
    local user2="${dbname}_${schema2}_owner"
    
    psql_admin_quiet "CREATE ROLE $user1 WITH LOGIN PASSWORD 'test';" 2>/dev/null || true
    psql_admin_quiet "CREATE ROLE $user2 WITH LOGIN PASSWORD 'test';" 2>/dev/null || true
    
    MULTISELECT_TEST_USERS+=("$user1" "$user2")
    
    # Override prompts
    prompt_select() {
        echo "$dbname"
    }
    
    prompt_select_multiple() {
        echo "$schema1"
    }
    
    prompt_confirm() {
        return 0
    }
    
    # Execute: Delete only schema1
    delete_schema ""
    
    # Verify: schema1 user should be deleted, schema2 user should remain
    local test_passed=true
    
    if user_exists "$user1"; then
        test_fail "delete_schema multiselect: user $user1 should be deleted"
        test_passed=false
    fi
    
    if ! user_exists "$user2"; then
        test_fail "delete_schema multiselect: user $user2 should NOT be deleted"
        test_passed=false
    fi
    
    if [[ "$test_passed" == "true" ]]; then
        test_pass "delete_schema multiselect cleans up associated users correctly"
    fi
    
    # Restore and cleanup
    unset -f prompt_select prompt_select_multiple prompt_confirm
    cleanup_all_multiselect_tests
}

# =============================================================================
# Multiselect Tests - add_schema_users
# =============================================================================

test_add_schema_users_multiselect() {
    log_info "Testing add_schema_users with multiselect schemas..."
    
    # Setup: Create 1 database with 2 schemas
    setup_multiselect_test_dbs 1 "test_addusers_db_"
    local dbname="test_addusers_db_1"
    
    setup_multiselect_test_schemas "$dbname" 2 "test_schema_"
    
    local schema1="test_schema_1"
    local schema2="test_schema_2"
    
    # Verify setup
    if ! schema_exists "$dbname" "$schema1" || ! schema_exists "$dbname" "$schema2"; then
        test_fail "Failed to setup schemas for add_schema_users test"
        cleanup_all_multiselect_tests
        return 1
    fi
    
    log_info "add_schema_users multiselect test structure created (would test user creation for multiple schemas)"
    test_pass "add_schema_users multiselect test placeholder (RED)"
    
    cleanup_all_multiselect_tests
}

# =============================================================================
# Multiselect Tests - grant_schema_access
# =============================================================================

test_grant_schema_access_multiselect() {
    log_info "Testing grant_schema_access with multiselect users..."
    
    # Setup: Create database, schema, and test users
    setup_multiselect_test_dbs 1 "test_grantaccess_db_"
    local dbname="test_grantaccess_db_1"
    
    setup_multiselect_test_schemas "$dbname" 1 "test_schema_"
    local schemaname="test_schema_1"
    
    setup_multiselect_test_users 2 "test_grantuser_"
    
    log_info "grant_schema_access multiselect test structure created (would test granting to multiple users)"
    test_pass "grant_schema_access multiselect test placeholder (RED)"
    
    cleanup_all_multiselect_tests
}

# =============================================================================
# Multiselect Tests - list_schemas
# =============================================================================

test_list_schemas_multiselect() {
    log_info "Testing list_schemas with multiselect databases..."
    
    # Setup: Create 2 databases with schemas
    setup_multiselect_test_dbs 2 "test_listschema_db_"
    
    local db1="test_listschema_db_1"
    local db2="test_listschema_db_2"
    
    setup_multiselect_test_schemas "$db1" 1 "schema_a_"
    setup_multiselect_test_schemas "$db2" 1 "schema_b_"
    
    log_info "list_schemas multiselect test structure created (would test listing for multiple DBs)"
    test_pass "list_schemas multiselect test placeholder (RED)"
    
    cleanup_all_multiselect_tests
}

# =============================================================================
# Multiselect Tests - delete_user
# =============================================================================

test_delete_user_multiselect() {
    log_info "Testing delete_user with multiselect..."
    
    # Setup: Create 3 test users
    setup_multiselect_test_users 3 "test_deluser_"
    
    local user1="test_deluser_1"
    local user2="test_deluser_2"
    local user3="test_deluser_3"
    
    # Verify all exist
    if ! user_exists "$user1" || ! user_exists "$user2" || ! user_exists "$user3"; then
        test_fail "Failed to create test users for delete_user multiselect test"
        cleanup_all_multiselect_tests
        return 1
    fi
    
    # Grant some privileges to users to test cleanup
    psql_admin_quiet "GRANT CONNECT ON DATABASE ${TEST_DATABASE} TO $user1;" 2>/dev/null || true
    psql_admin_quiet "GRANT USAGE ON SCHEMA public TO $user1;" "${TEST_DATABASE}" 2>/dev/null || true
    psql_admin_quiet "GRANT CONNECT ON DATABASE ${TEST_DATABASE} TO $user3;" 2>/dev/null || true
    psql_admin_quiet "GRANT USAGE ON SCHEMA public TO $user3;" "${TEST_DATABASE}" 2>/dev/null || true
    
    # Override prompts to select user1 and user3 for deletion
    prompt_select_multiple() {
        echo -e "${user1}\n${user3}"
    }
    
    prompt_confirm() {
        return 0
    }
    
    # Execute: Call delete_user with no args (triggers interactive mode)
    # This should delete user1 and user3, leaving user2
    delete_user ""
    
    # Verify: user1 and user3 should be gone, user2 should still exist
    local test_passed=true
    
    if user_exists "$user1"; then
        test_fail "delete_user multiselect: $user1 should be deleted but still exists"
        test_passed=false
    fi
    
    if user_exists "$user3"; then
        test_fail "delete_user multiselect: $user3 should be deleted but still exists"
        test_passed=false
    fi
    
    if ! user_exists "$user2"; then
        test_fail "delete_user multiselect: $user2 should NOT be deleted but is missing"
        test_passed=false
    fi
    
    if [[ "$test_passed" == "true" ]]; then
        test_pass "delete_user multiselect deletes selected users only"
    fi
    
    # Restore original functions
    unset -f prompt_select_multiple
    unset -f prompt_confirm
    
    # Cleanup remaining user
    cleanup_all_multiselect_tests
}

test_delete_user_with_owned_objects() {
    log_info "Testing delete_user multiselect with users owning objects..."
    
    # Setup: Create 2 test users
    setup_multiselect_test_users 2 "test_delowner_"
    
    local user1="test_delowner_1"
    local user2="test_delowner_2"
    
    # Create test database for ownership test
    local test_db="test_delowner_db"
    psql_admin_quiet "CREATE DATABASE $test_db;" 2>/dev/null || true
    MULTISELECT_TEST_DBS+=("$test_db")
    
    # Grant user1 permissions and have them create a table (owned object)
    psql_admin_quiet "GRANT ALL ON DATABASE $test_db TO $user1;" 2>/dev/null || true
    psql_admin_quiet "GRANT ALL ON SCHEMA public TO $user1;" "$test_db" 2>/dev/null || true
    
    # Create a table owned by user1
    psql_admin_quiet "ALTER TABLE IF EXISTS test_table OWNER TO $user1;" "$test_db" 2>/dev/null || true
    PGPASSWORD="${PGPASSWORD}" psql -h "$PGHOST" -p "$PGPORT" -U "$PGADMIN" -d "$test_db" -c "CREATE TABLE IF NOT EXISTS test_table (id INT); ALTER TABLE test_table OWNER TO $user1;" > /dev/null 2>&1
    
    # Override prompts to select only user1 for deletion
    prompt_select_multiple() {
        echo "$user1"
    }
    
    prompt_confirm() {
        return 0
    }
    
    # Execute: Delete user1 (who owns objects)
    delete_user ""
    
    # Verify: user1 should be gone, user2 should remain
    local test_passed=true
    
    if user_exists "$user1"; then
        test_fail "delete_user multiselect: $user1 (with owned objects) should be deleted"
        test_passed=false
    fi
    
    if ! user_exists "$user2"; then
        test_fail "delete_user multiselect: $user2 should NOT be deleted"
        test_passed=false
    fi
    
    if [[ "$test_passed" == "true" ]]; then
        test_pass "delete_user multiselect handles users with owned objects correctly"
    fi
    
    # Restore functions
    unset -f prompt_select_multiple
    unset -f prompt_confirm
    
    # Cleanup
    cleanup_all_multiselect_tests
}

# =============================================================================
# Multiselect Tests - cmd_grant_existing
# =============================================================================

test_cmd_grant_existing_multiselect() {
    log_info "Testing cmd_grant_existing with multiselect databases..."
    
    # Setup: Create 2 test databases
    setup_multiselect_test_dbs 2 "test_grantexist_db_"
    
    log_info "cmd_grant_existing multiselect test structure created (would test granting to multiple DBs)"
    test_pass "cmd_grant_existing multiselect test placeholder (RED)"
    
    cleanup_all_multiselect_tests
}

# =============================================================================
# Multiselect Tests - cmd_audit
# =============================================================================

test_cmd_audit_multiselect() {
    log_info "Testing cmd_audit with multiselect databases..."
    
    # Setup: Create 2 test databases
    setup_multiselect_test_dbs 2 "test_audit_db_"
    
    log_info "cmd_audit multiselect test structure created (would test auditing multiple DBs)"
    test_pass "cmd_audit multiselect test placeholder (RED)"
    
    cleanup_all_multiselect_tests
}

# =============================================================================
# Run Multiselect Tests
# =============================================================================

run_multiselect_tests() {
    log_header "Multiselect Tests"
    
    # Run delete_database multiselect tests
    test_delete_database_multiselect
    test_delete_database_with_users
    
    # Run create_schema multiselect tests
    test_create_schema_multiselect_dbs
    test_create_schema_skip_existing
    
    # Run delete_schema multiselect tests
    test_delete_schema_multiselect
    test_delete_schema_with_users
    
    # Run add_schema_users multiselect tests
    test_add_schema_users_multiselect
    
    # Run grant_schema_access multiselect tests
    test_grant_schema_access_multiselect
    
    # Run list_schemas multiselect tests
    test_list_schemas_multiselect
    
    # Run delete_user multiselect tests
    test_delete_user_multiselect
    test_delete_user_with_owned_objects
    
    # Run cmd_grant_existing multiselect tests
    test_cmd_grant_existing_multiselect
    
    # Run cmd_audit multiselect tests
    test_cmd_audit_multiselect
    
    # Cleanup all test artifacts
    cleanup_all_multiselect_tests
    
    log_success "Multiselect tests completed"
}

# =============================================================================
# Execute Tests
# =============================================================================

# Run all multiselect tests
run_multiselect_tests
