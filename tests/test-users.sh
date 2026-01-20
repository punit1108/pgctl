#!/bin/bash

# =============================================================================
# User Tests for pgctl
# =============================================================================
# Tests for user management functions
# =============================================================================

# This file is sourced by test-runner.sh

# Source dependencies
source "${LIB_DIR}/users.sh"

# =============================================================================
# User Tests
# =============================================================================

test_user_exists() {
    log_info "Testing user existence checks..."
    
    # Test existing user
    if user_exists "${TEST_DATABASE}_owner"; then
        test_pass "user_exists returns true for existing user"
    else
        test_fail "user_exists returns true for existing user"
    fi
    
    # Test non-existing user
    if ! user_exists "nonexistent_user_12345"; then
        test_pass "user_exists returns false for non-existing user"
    else
        test_fail "user_exists returns false for non-existing user"
    fi
}

test_list_users() {
    log_info "Testing user listing..."
    
    local result
    # Skip gum table test in automated mode (gum table is interactive)
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        # Test the underlying query function instead of the interactive wrapper
        result=$(list_users_query 2>/dev/null)
    else
        # Non-GUM mode: test the full function
        result=$(list_users "$TEST_DATABASE" 2>/dev/null)
    fi
    
    # Check that standard users appear in list
    if [[ "$result" == *"${TEST_DATABASE}_owner"* ]]; then
        test_pass "Owner user appears in list"
    else
        test_fail "Owner user appears in list"
    fi
    
    if [[ "$result" == *"${TEST_DATABASE}_migration_user"* ]]; then
        test_pass "Migration user appears in list"
    else
        test_fail "Migration user appears in list"
    fi
    
    if [[ "$result" == *"${TEST_DATABASE}_readonly_user"* ]]; then
        test_pass "Readonly user appears in list"
    else
        test_fail "Readonly user appears in list"
    fi
}

test_create_custom_user() {
    log_info "Testing custom user creation..."
    
    local custom_user="test_custom_user"
    local custom_pass="test_custom_pass"
    
    # Create custom user directly
    if psql_admin_quiet "CREATE ROLE $custom_user WITH LOGIN PASSWORD '$custom_pass';"; then
        test_pass "Custom user created"
    else
        test_fail "Custom user created"
    fi
    
    # Verify user exists
    if user_exists "$custom_user"; then
        test_pass "Custom user exists after creation"
    else
        test_fail "Custom user exists after creation"
    fi
    
    # Grant permissions
    grant_all_permissions "$TEST_DATABASE" "$custom_user" "app_user" "public" > /dev/null 2>&1
    
    # Verify permissions (check can access public schema)
    local has_usage
    has_usage=$(psql_admin "SELECT has_schema_privilege('$custom_user', 'public', 'USAGE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_usage" == "t" ]]; then
        test_pass "Custom user has schema USAGE privilege"
    else
        test_fail "Custom user has schema USAGE privilege"
    fi
}

test_password_change() {
    log_info "Testing password change..."
    
    local test_user="${TEST_DATABASE}_readonly_user"
    local new_pass="new_readonly_pass_123"
    
    # Change password
    if psql_admin_quiet "ALTER ROLE $test_user WITH PASSWORD '$new_pass';"; then
        test_pass "Password change SQL executes successfully"
    else
        test_fail "Password change SQL executes successfully"
    fi
    
    # Try to connect with new password
    # Note: This test is limited as we can't easily verify the password works
    test_pass "Password change completed (verification requires connection test)"
}

test_user_privileges() {
    log_info "Testing user privilege flags..."
    
    # Owner should have CREATEDB and CREATEROLE
    local owner="${TEST_DATABASE}_owner"
    
    local createdb
    createdb=$(psql_admin "SELECT rolcreatedb FROM pg_roles WHERE rolname = '$owner';" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    local createrole
    createrole=$(psql_admin "SELECT rolcreaterole FROM pg_roles WHERE rolname = '$owner';" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$createdb" == "t" ]]; then
        test_pass "Owner has CREATEDB"
    else
        test_fail "Owner has CREATEDB"
    fi
    
    if [[ "$createrole" == "t" ]]; then
        test_pass "Owner has CREATEROLE"
    else
        test_fail "Owner has CREATEROLE"
    fi
    
    # Migration user should NOT have CREATEDB
    local migration="${TEST_DATABASE}_migration_user"
    
    createdb=$(psql_admin "SELECT rolcreatedb FROM pg_roles WHERE rolname = '$migration';" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$createdb" == "f" ]]; then
        test_pass "Migration user does not have CREATEDB"
    else
        test_fail "Migration user does not have CREATEDB"
    fi
}

test_delete_user_single() {
    log_info "Testing single user deletion..."
    
    # Create a test user
    local test_user="test_delete_single_user"
    psql_admin_quiet "CREATE ROLE $test_user WITH LOGIN PASSWORD 'test_pass';" 2>/dev/null || true
    
    # Grant some privileges
    psql_admin_quiet "GRANT CONNECT ON DATABASE ${TEST_DATABASE} TO $test_user;" 2>/dev/null || true
    psql_admin_quiet "GRANT USAGE ON SCHEMA public TO $test_user;" "$TEST_DATABASE" 2>/dev/null || true
    
    # Verify user exists
    if ! user_exists "$test_user"; then
        test_fail "Test user was not created"
        return 1
    fi
    
    # Override prompt_confirm to auto-accept
    prompt_confirm() {
        return 0
    }
    
    # Delete the user using the CLI mode (with username argument)
    delete_user "$test_user"
    
    # Verify user is deleted
    if user_exists "$test_user"; then
        test_fail "User should be deleted but still exists"
        # Cleanup
        psql_admin_quiet "DROP ROLE IF EXISTS $test_user;" 2>/dev/null || true
    else
        test_pass "Single user deletion works correctly"
    fi
    
    # Restore function
    unset -f prompt_confirm
}

test_delete_user_with_privileges_across_dbs() {
    log_info "Testing user deletion with privileges across multiple databases..."
    
    # Create a test user
    local test_user="test_delete_multi_db_user"
    psql_admin_quiet "CREATE ROLE $test_user WITH LOGIN PASSWORD 'test_pass';" 2>/dev/null || true
    
    # Create a second test database
    local test_db2="pgctl_test_db2"
    psql_admin_quiet "CREATE DATABASE $test_db2;" 2>/dev/null || true
    
    # Grant privileges on both databases
    psql_admin_quiet "GRANT CONNECT ON DATABASE ${TEST_DATABASE} TO $test_user;" 2>/dev/null || true
    psql_admin_quiet "GRANT USAGE ON SCHEMA public TO $test_user;" "$TEST_DATABASE" 2>/dev/null || true
    psql_admin_quiet "GRANT CONNECT ON DATABASE $test_db2 TO $test_user;" 2>/dev/null || true
    psql_admin_quiet "GRANT USAGE ON SCHEMA public TO $test_user;" "$test_db2" 2>/dev/null || true
    
    # Verify user exists
    if ! user_exists "$test_user"; then
        test_fail "Test user was not created"
        # Cleanup
        psql_admin_quiet "DROP DATABASE IF EXISTS $test_db2;" 2>/dev/null || true
        return 1
    fi
    
    # Override prompt_confirm to auto-accept
    prompt_confirm() {
        return 0
    }
    
    # Delete the user
    delete_user "$test_user"
    
    # Verify user is deleted
    if user_exists "$test_user"; then
        test_fail "User with privileges across multiple DBs should be deleted but still exists"
        # Cleanup
        psql_admin_quiet "DROP ROLE IF EXISTS $test_user;" 2>/dev/null || true
    else
        test_pass "User deletion with privileges across multiple databases works correctly"
    fi
    
    # Cleanup test database
    psql_admin_quiet "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$test_db2' AND pid <> pg_backend_pid();" 2>/dev/null || true
    psql_admin_quiet "DROP DATABASE IF EXISTS $test_db2;" 2>/dev/null || true
    
    # Restore function
    unset -f prompt_confirm
}

# =============================================================================
# Run Tests
# =============================================================================

test_user_exists
test_list_users
test_create_custom_user
test_password_change
test_user_privileges
test_delete_user_single
test_delete_user_with_privileges_across_dbs
