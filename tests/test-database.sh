#!/bin/bash

# =============================================================================
# Database Tests for pgctl
# =============================================================================
# Tests for database creation, deletion, and listing
# =============================================================================

# This file is sourced by test-runner.sh

# Source dependencies
source "${LIB_DIR}/database.sh"

# =============================================================================
# Database Creation Tests
# =============================================================================

test_create_database() {
    log_info "Testing database creation..."
    
    # Set test passwords
    export DB_OWNER_PASSWORD="test_owner_pass"
    export DB_MIGRATION_PASSWORD="test_migration_pass"
    export DB_FULLACCESS_PASSWORD="test_fullaccess_pass"
    export DB_APP_PASSWORD="test_app_pass"
    export DB_READONLY_PASSWORD="test_readonly_pass"
    
    # Create database
    create_database "$TEST_DATABASE" > /dev/null 2>&1
    local result=$?
    
    assert_equals "0" "$result" "create_database returns success"
    
    # Verify database exists
    if database_exists "$TEST_DATABASE"; then
        test_pass "Database exists after creation"
    else
        test_fail "Database exists after creation"
    fi
    
    # Verify owner user exists
    if user_exists "${TEST_DATABASE}_owner"; then
        test_pass "Owner user created"
    else
        test_fail "Owner user created"
    fi
    
    # Verify migration user exists
    if user_exists "${TEST_DATABASE}_migration_user"; then
        test_pass "Migration user created"
    else
        test_fail "Migration user created"
    fi
    
    # Verify fullaccess user exists
    if user_exists "${TEST_DATABASE}_fullaccess_user"; then
        test_pass "Fullaccess user created"
    else
        test_fail "Fullaccess user created"
    fi
    
    # Verify app user exists
    if user_exists "${TEST_DATABASE}_app_user"; then
        test_pass "App user created"
    else
        test_fail "App user created"
    fi
    
    # Verify readonly user exists
    if user_exists "${TEST_DATABASE}_readonly_user"; then
        test_pass "Readonly user created"
    else
        test_fail "Readonly user created"
    fi
    
    # Verify database ownership
    local owner
    owner=$(psql_admin "SELECT pg_catalog.pg_get_userbyid(d.datdba) FROM pg_catalog.pg_database d WHERE d.datname = '$TEST_DATABASE';" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$owner" == "${TEST_DATABASE}_owner" ]]; then
        test_pass "Database owned by ${TEST_DATABASE}_owner"
    else
        test_fail "Database owned by ${TEST_DATABASE}_owner" "Actual owner: $owner"
    fi
    
    # Verify owner has CREATEDB privilege
    local can_createdb
    can_createdb=$(psql_admin "SELECT rolcreatedb FROM pg_roles WHERE rolname = '${TEST_DATABASE}_owner';" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$can_createdb" == "t" ]]; then
        test_pass "Owner has CREATEDB privilege"
    else
        test_fail "Owner has CREATEDB privilege"
    fi
}

test_duplicate_database() {
    log_info "Testing duplicate database creation..."
    
    # Try to create database again (should fail)
    if create_database "$TEST_DATABASE" > /dev/null 2>&1; then
        test_fail "Duplicate database creation should fail"
    else
        test_pass "Duplicate database creation fails correctly"
    fi
}

test_list_databases() {
    log_info "Testing database listing..."
    
    # Skip gum table test in automated mode (gum table is interactive)
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        # Test the underlying query function instead of the interactive wrapper
        local result
        result=$(list_databases_query 2>/dev/null)
        
        if [[ "$result" == *"$TEST_DATABASE"* ]]; then
            test_pass "Test database appears in list (via query)"
        else
            test_fail "Test database appears in list (via query)"
        fi
    else
        # Non-GUM mode: test the full function
        local result
        result=$(list_databases 2>/dev/null)
        
        if [[ "$result" == *"$TEST_DATABASE"* ]]; then
            test_pass "Test database appears in list"
        else
            test_fail "Test database appears in list"
        fi
    fi
}

# =============================================================================
# Run Tests
# =============================================================================

test_create_database
test_duplicate_database
test_list_databases
