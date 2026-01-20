#!/bin/bash

# =============================================================================
# Schema Tests for pgctl
# =============================================================================
# Tests for schema creation, deletion, and schema-specific users
# =============================================================================

# This file is sourced by test-runner.sh

# Source dependencies
source "${LIB_DIR}/schema.sh"

# =============================================================================
# Schema Tests
# =============================================================================

test_create_schema() {
    log_info "Testing schema creation..."
    
    local test_schema="test_schema"
    
    # Set test passwords
    export SCHEMA_OWNER_PASSWORD="test_schema_owner_pass"
    export SCHEMA_MIGRATION_PASSWORD="test_schema_migration_pass"
    export SCHEMA_FULLACCESS_PASSWORD="test_schema_fullaccess_pass"
    export SCHEMA_APP_PASSWORD="test_schema_app_pass"
    export SCHEMA_READONLY_PASSWORD="test_schema_readonly_pass"
    
    # Create schema  
    # Note: Not redirecting output to avoid hanging issues with table formatters
    create_schema "$TEST_DATABASE" "$test_schema" &> /tmp/test_schema_output.txt
    local result=$?
    
    if [[ $result -eq 0 ]]; then
        test_pass "create_schema returns success"
    else
        test_fail "create_schema returns success" "Exit code: $result"
    fi
    
    # Verify schema exists
    if schema_exists "$TEST_DATABASE" "$test_schema"; then
        test_pass "Schema exists after creation"
    else
        test_fail "Schema exists after creation"
    fi
    
    # Verify schema-specific users exist
    local prefix="${TEST_DATABASE}_${test_schema}"
    
    if user_exists "${prefix}_owner"; then
        test_pass "Schema owner created"
    else
        test_fail "Schema owner created"
    fi
    
    if user_exists "${prefix}_migration_user"; then
        test_pass "Schema migration user created"
    else
        test_fail "Schema migration user created"
    fi
    
    if user_exists "${prefix}_fullaccess_user"; then
        test_pass "Schema fullaccess user created"
    else
        test_fail "Schema fullaccess user created"
    fi
    
    if user_exists "${prefix}_app_user"; then
        test_pass "Schema app user created"
    else
        test_fail "Schema app user created"
    fi
    
    if user_exists "${prefix}_readonly_user"; then
        test_pass "Schema readonly user created"
    else
        test_fail "Schema readonly user created"
    fi
}

test_schema_ownership() {
    log_info "Testing schema ownership..."
    
    local test_schema="test_schema"
    local prefix="${TEST_DATABASE}_${test_schema}"
    local expected_owner="${prefix}_owner"
    
    local owner
    owner=$(psql_admin "SELECT nspowner::regrole FROM pg_namespace WHERE nspname = '$test_schema';" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$owner" == "$expected_owner" ]]; then
        test_pass "Schema owned by ${expected_owner}"
    else
        test_fail "Schema owned by ${expected_owner}" "Actual owner: $owner"
    fi
}

test_schema_isolation() {
    log_info "Testing schema isolation..."
    
    local test_schema="test_schema"
    local prefix="${TEST_DATABASE}_${test_schema}"
    local schema_user="${prefix}_readonly_user"
    
    # Check that schema user has USAGE on their schema
    local has_usage
    has_usage=$(psql_admin "SELECT has_schema_privilege('$schema_user', '$test_schema', 'USAGE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_usage" == "t" ]]; then
        test_pass "Schema user has USAGE on their schema"
    else
        test_fail "Schema user has USAGE on their schema"
    fi
}

test_schema_naming_convention() {
    log_info "Testing schema naming convention..."
    
    local test_schema="test_schema"
    local prefix="${TEST_DATABASE}_${test_schema}"
    
    # Verify naming convention is correct
    local migration_user="${prefix}_migration_user"
    
    if user_exists "$migration_user"; then
        test_pass "Schema users follow naming convention {db}_{schema}_{role}"
    else
        test_fail "Schema users follow naming convention {db}_{schema}_{role}"
    fi
}

test_list_schemas() {
    log_info "Testing schema listing..."
    
    local result
    # Skip gum table test in automated mode (gum table is interactive)
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        # Test the underlying query function instead of the interactive wrapper
        result=$(list_schemas_query "$TEST_DATABASE" 2>/dev/null)
    else
        # Non-GUM mode: test the full function
        result=$(list_schemas "$TEST_DATABASE" 2>/dev/null)
    fi
    
    if [[ "$result" == *"test_schema"* ]]; then
        test_pass "Test schema appears in list"
    else
        test_fail "Test schema appears in list"
    fi
    
    if [[ "$result" == *"public"* ]]; then
        test_pass "Public schema appears in list"
    else
        test_fail "Public schema appears in list"
    fi
}

# =============================================================================
# Add Schema Users Tests - Credential Display
# =============================================================================

test_add_schema_users_displays_credentials_gum() {
    log_info "Testing add_schema_users displays credentials (gum mode)..."
    
    # Create a schema without users first
    local test_schema="test_add_users_gum"
    
    # Create just the schema, no users
    psql_admin_quiet "CREATE SCHEMA $test_schema;" "$TEST_DATABASE" 2>/dev/null || true
    
    # Delete any existing users to ensure fresh test
    local prefix="${TEST_DATABASE}_${test_schema}"
    psql_admin_quiet "DROP ROLE IF EXISTS ${prefix}_owner;" 2>/dev/null || true
    psql_admin_quiet "DROP ROLE IF EXISTS ${prefix}_migration_user;" 2>/dev/null || true
    psql_admin_quiet "DROP ROLE IF EXISTS ${prefix}_fullaccess_user;" 2>/dev/null || true
    psql_admin_quiet "DROP ROLE IF EXISTS ${prefix}_app_user;" 2>/dev/null || true
    psql_admin_quiet "DROP ROLE IF EXISTS ${prefix}_readonly_user;" 2>/dev/null || true
    
    # Set test passwords
    export SCHEMA_OWNER_PASSWORD="test_add_owner_pass"
    export SCHEMA_MIGRATION_PASSWORD="test_add_migration_pass"
    export SCHEMA_FULLACCESS_PASSWORD="test_add_fullaccess_pass"
    export SCHEMA_APP_PASSWORD="test_add_app_pass"
    export SCHEMA_READONLY_PASSWORD="test_add_readonly_pass"
    
    # Capture output (use CLI mode with database and schema arguments)
    local output
    output=$(add_schema_users "$TEST_DATABASE" "$test_schema" 2>&1)
    local result=$?
    
    # Test 1: Function should succeed
    if [[ $result -eq 0 ]]; then
        test_pass "add_schema_users returns success"
    else
        test_fail "add_schema_users returns success" "Exit code: $result"
    fi
    
    # Test 2: Output should contain credentials header
    if [[ "$output" == *"NEW CREDENTIALS"* ]] || [[ "$output" == *"CREDENTIALS"* ]]; then
        test_pass "Output contains credentials header"
    else
        test_fail "Output contains credentials header" "Output: $output"
    fi
    
    # Test 3: Output should contain username
    if [[ "$output" == *"${prefix}_owner"* ]]; then
        test_pass "Output contains owner username"
    else
        test_fail "Output contains owner username"
    fi
    
    # Test 4: Output should contain password
    if [[ "$output" == *"test_add_owner_pass"* ]]; then
        test_pass "Output contains owner password"
    else
        test_fail "Output contains owner password"
    fi
    
    # Test 5: Output should contain role
    if [[ "$output" == *"owner"* ]]; then
        test_pass "Output contains role identifier"
    else
        test_fail "Output contains role identifier"
    fi
    
    # Cleanup
    psql_admin_quiet "DROP SCHEMA IF EXISTS $test_schema CASCADE;" "$TEST_DATABASE" 2>/dev/null || true
    psql_admin_quiet "DROP ROLE IF EXISTS ${prefix}_owner;" 2>/dev/null || true
    psql_admin_quiet "DROP ROLE IF EXISTS ${prefix}_migration_user;" 2>/dev/null || true
    psql_admin_quiet "DROP ROLE IF EXISTS ${prefix}_fullaccess_user;" 2>/dev/null || true
    psql_admin_quiet "DROP ROLE IF EXISTS ${prefix}_app_user;" 2>/dev/null || true
    psql_admin_quiet "DROP ROLE IF EXISTS ${prefix}_readonly_user;" 2>/dev/null || true
}

test_add_schema_users_displays_credentials_non_gum() {
    log_info "Testing add_schema_users displays credentials (non-gum mode)..."
    
    # Temporarily disable gum for this test
    local original_gum="$GUM_AVAILABLE"
    export GUM_AVAILABLE=false
    
    # Create a schema without users first
    local test_schema="test_add_users_nogum"
    
    # Create just the schema, no users
    psql_admin_quiet "CREATE SCHEMA $test_schema;" "$TEST_DATABASE" 2>/dev/null || true
    
    # Delete any existing users to ensure fresh test
    local prefix="${TEST_DATABASE}_${test_schema}"
    psql_admin_quiet "DROP ROLE IF EXISTS ${prefix}_owner;" 2>/dev/null || true
    psql_admin_quiet "DROP ROLE IF EXISTS ${prefix}_migration_user;" 2>/dev/null || true
    psql_admin_quiet "DROP ROLE IF EXISTS ${prefix}_fullaccess_user;" 2>/dev/null || true
    psql_admin_quiet "DROP ROLE IF EXISTS ${prefix}_app_user;" 2>/dev/null || true
    psql_admin_quiet "DROP ROLE IF EXISTS ${prefix}_readonly_user;" 2>/dev/null || true
    
    # Set test passwords
    export SCHEMA_OWNER_PASSWORD="test_add_owner_pass_ng"
    export SCHEMA_MIGRATION_PASSWORD="test_add_migration_pass_ng"
    export SCHEMA_FULLACCESS_PASSWORD="test_add_fullaccess_pass_ng"
    export SCHEMA_APP_PASSWORD="test_add_app_pass_ng"
    export SCHEMA_READONLY_PASSWORD="test_add_readonly_pass_ng"
    
    # Capture output (use CLI mode with database and schema arguments)
    local output
    output=$(add_schema_users "$TEST_DATABASE" "$test_schema" 2>&1)
    local result=$?
    
    # Test 1: Function should succeed
    if [[ $result -eq 0 ]]; then
        test_pass "add_schema_users returns success (non-gum)"
    else
        test_fail "add_schema_users returns success (non-gum)" "Exit code: $result"
    fi
    
    # Test 2: Output should contain credentials header
    if [[ "$output" == *"NEW CREDENTIALS"* ]] || [[ "$output" == *"CREDENTIALS"* ]]; then
        test_pass "Output contains credentials header (non-gum)"
    else
        test_fail "Output contains credentials header (non-gum)" "Output: $output"
    fi
    
    # Test 3: Output should contain username
    if [[ "$output" == *"${prefix}_owner"* ]]; then
        test_pass "Output contains owner username (non-gum)"
    else
        test_fail "Output contains owner username (non-gum)"
    fi
    
    # Test 4: Output should contain password
    if [[ "$output" == *"test_add_owner_pass_ng"* ]]; then
        test_pass "Output contains owner password (non-gum)"
    else
        test_fail "Output contains owner password (non-gum)"
    fi
    
    # Cleanup
    psql_admin_quiet "DROP SCHEMA IF EXISTS $test_schema CASCADE;" "$TEST_DATABASE" 2>/dev/null || true
    psql_admin_quiet "DROP ROLE IF EXISTS ${prefix}_owner;" 2>/dev/null || true
    psql_admin_quiet "DROP ROLE IF EXISTS ${prefix}_migration_user;" 2>/dev/null || true
    psql_admin_quiet "DROP ROLE IF EXISTS ${prefix}_fullaccess_user;" 2>/dev/null || true
    psql_admin_quiet "DROP ROLE IF EXISTS ${prefix}_app_user;" 2>/dev/null || true
    psql_admin_quiet "DROP ROLE IF EXISTS ${prefix}_readonly_user;" 2>/dev/null || true
    
    # Restore gum setting
    export GUM_AVAILABLE="$original_gum"
}

test_add_schema_users_idempotent_no_credentials() {
    log_info "Testing add_schema_users idempotent (no credentials when users exist)..."
    
    # Use the test_schema that was created earlier with all users
    local test_schema="test_schema"
    local prefix="${TEST_DATABASE}_${test_schema}"
    
    # Verify all users exist (from earlier test)
    if ! user_exists "${prefix}_owner"; then
        test_fail "Prerequisites not met: owner user does not exist"
        return 1
    fi
    
    # Set test passwords (not used since users exist)
    export SCHEMA_OWNER_PASSWORD="unused_pass"
    export SCHEMA_MIGRATION_PASSWORD="unused_pass"
    export SCHEMA_FULLACCESS_PASSWORD="unused_pass"
    export SCHEMA_APP_PASSWORD="unused_pass"
    export SCHEMA_READONLY_PASSWORD="unused_pass"
    
    # Capture output
    local output
    output=$(add_schema_users "$TEST_DATABASE" "$test_schema" 2>&1)
    local result=$?
    
    # Test 1: Function should succeed
    if [[ $result -eq 0 ]]; then
        test_pass "add_schema_users idempotent returns success"
    else
        test_fail "add_schema_users idempotent returns success" "Exit code: $result"
    fi
    
    # Test 2: Output should NOT contain credential table when no users created
    if [[ "$output" == *"No new users created"* ]] || [[ "$output" == *"All 5 standard users already exist"* ]]; then
        test_pass "Output indicates no new users created"
    else
        test_fail "Output indicates no new users created" "Output: $output"
    fi
    
    # Test 3: Output should NOT show credentials for existing users
    if [[ "$output" != *"unused_pass"* ]]; then
        test_pass "Output does not contain test passwords (idempotent)"
    else
        test_fail "Output does not contain test passwords (idempotent)" "Should not show passwords for existing users"
    fi
}

# =============================================================================
# Run Tests
# =============================================================================

test_create_schema
test_schema_ownership
test_schema_isolation
test_schema_naming_convention
test_list_schemas

# Run add_schema_users credential display tests
test_add_schema_users_displays_credentials_gum
test_add_schema_users_displays_credentials_non_gum
test_add_schema_users_idempotent_no_credentials
