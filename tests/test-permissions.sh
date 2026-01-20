#!/bin/bash

# =============================================================================
# Permission Tests for pgctl
# =============================================================================
# Tests for permission granting, revoking, and verification
# =============================================================================

# This file is sourced by test-runner.sh

# Source dependencies
source "${LIB_DIR}/permissions.sh"

# =============================================================================
# Setup Test Objects
# =============================================================================

setup_test_objects() {
    log_info "Creating test objects..."
    
    # Create test table
    psql_admin_quiet "CREATE TABLE IF NOT EXISTS test_table (id SERIAL PRIMARY KEY, name TEXT);" "$TEST_DATABASE"
    
    # Create test sequence
    psql_admin_quiet "CREATE SEQUENCE IF NOT EXISTS test_sequence;" "$TEST_DATABASE"
    
    # Create test function
    psql_admin_quiet "CREATE OR REPLACE FUNCTION test_function() RETURNS TEXT AS \$\$ SELECT 'test'; \$\$ LANGUAGE SQL;" "$TEST_DATABASE"
    
    # Grant ownership to database owner
    psql_admin_quiet "ALTER TABLE test_table OWNER TO ${TEST_DATABASE}_owner;" "$TEST_DATABASE"
    psql_admin_quiet "ALTER SEQUENCE test_sequence OWNER TO ${TEST_DATABASE}_owner;" "$TEST_DATABASE"
}

# =============================================================================
# Permission Tests
# =============================================================================

test_migration_user_ddl() {
    log_info "Testing migration user DDL permissions..."
    
    local migration="${TEST_DATABASE}_migration_user"
    
    # Check CREATE privilege on schema
    local has_create
    has_create=$(psql_admin "SELECT has_schema_privilege('$migration', 'public', 'CREATE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_create" == "t" ]]; then
        test_pass "Migration user has CREATE on schema"
    else
        test_fail "Migration user has CREATE on schema"
    fi
}

test_migration_user_can_create_table() {
    log_info "Testing migration user can CREATE TABLE..."
    
    if run_psql_as_user "$TEST_DATABASE" "${TEST_DATABASE}_migration_user" "${DB_MIGRATION_PASSWORD}" "CREATE TABLE _pt_migration_created(id int);"; then
        test_pass "Migration user can CREATE TABLE"
    else
        test_fail "Migration user can CREATE TABLE"
        return
    fi
    if run_psql_as_user "$TEST_DATABASE" "${TEST_DATABASE}_migration_user" "${DB_MIGRATION_PASSWORD}" "DROP TABLE _pt_migration_created;"; then
        test_pass "Migration user can DROP TABLE"
    else
        test_fail "Migration user can DROP TABLE"
    fi
}

test_owner_can_create_table() {
    log_info "Testing owner can CREATE TABLE..."
    
    if run_psql_as_user "$TEST_DATABASE" "${TEST_DATABASE}_owner" "${DB_OWNER_PASSWORD}" "CREATE TABLE _pt_owner_created(id int);"; then
        test_pass "Owner can CREATE TABLE"
    else
        test_fail "Owner can CREATE TABLE"
        return
    fi
    if run_psql_as_user "$TEST_DATABASE" "${TEST_DATABASE}_owner" "${DB_OWNER_PASSWORD}" "DROP TABLE _pt_owner_created;"; then
        test_pass "Owner can DROP TABLE"
    else
        test_fail "Owner can DROP TABLE"
    fi
}

test_fullaccess_user_cannot_create_table() {
    log_info "Testing fullaccess user cannot CREATE TABLE..."
    
    if ! run_psql_as_user "$TEST_DATABASE" "${TEST_DATABASE}_fullaccess_user" "${DB_FULLACCESS_PASSWORD}" "CREATE TABLE _pt_fullaccess_created(id int);"; then
        test_pass "Fullaccess user cannot CREATE TABLE"
    else
        test_fail "Fullaccess user cannot CREATE TABLE" "Expected CREATE to fail"
    fi
}

test_app_user_cannot_create_table() {
    log_info "Testing app user cannot CREATE TABLE..."
    
    if ! run_psql_as_user "$TEST_DATABASE" "${TEST_DATABASE}_app_user" "${DB_APP_PASSWORD}" "CREATE TABLE _pt_app_created(id int);"; then
        test_pass "App user cannot CREATE TABLE"
    else
        test_fail "App user cannot CREATE TABLE" "Expected CREATE to fail"
    fi
}

test_readonly_user_cannot_create_table() {
    log_info "Testing readonly user cannot CREATE TABLE..."
    
    if ! run_psql_as_user "$TEST_DATABASE" "${TEST_DATABASE}_readonly_user" "${DB_READONLY_PASSWORD}" "CREATE TABLE _pt_readonly_created(id int);"; then
        test_pass "Readonly user cannot CREATE TABLE"
    else
        test_fail "Readonly user cannot CREATE TABLE" "Expected CREATE to fail"
    fi
}

test_fullaccess_user_crud() {
    log_info "Testing fullaccess user CRUD permissions..."
    
    local fullaccess="${TEST_DATABASE}_fullaccess_user"
    
    # Grant permissions
    grant_all_permissions "$TEST_DATABASE" "$fullaccess" "fullaccess_user" "public" > /dev/null 2>&1
    
    # Check SELECT
    local has_select
    has_select=$(psql_admin "SELECT has_table_privilege('$fullaccess', 'test_table', 'SELECT');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_select" == "t" ]]; then
        test_pass "Fullaccess user has SELECT"
    else
        test_fail "Fullaccess user has SELECT"
    fi
    
    # Check INSERT
    local has_insert
    has_insert=$(psql_admin "SELECT has_table_privilege('$fullaccess', 'test_table', 'INSERT');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_insert" == "t" ]]; then
        test_pass "Fullaccess user has INSERT"
    else
        test_fail "Fullaccess user has INSERT"
    fi
    
    # Check UPDATE
    local has_update
    has_update=$(psql_admin "SELECT has_table_privilege('$fullaccess', 'test_table', 'UPDATE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_update" == "t" ]]; then
        test_pass "Fullaccess user has UPDATE"
    else
        test_fail "Fullaccess user has UPDATE"
    fi
    
    # Check DELETE
    local has_delete
    has_delete=$(psql_admin "SELECT has_table_privilege('$fullaccess', 'test_table', 'DELETE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_delete" == "t" ]]; then
        test_pass "Fullaccess user has DELETE"
    else
        test_fail "Fullaccess user has DELETE"
    fi
}

test_app_user_cru_only() {
    log_info "Testing app user CRU (no DELETE) permissions..."
    
    local app="${TEST_DATABASE}_app_user"
    
    # Grant permissions
    grant_all_permissions "$TEST_DATABASE" "$app" "app_user" "public" > /dev/null 2>&1
    
    # Check SELECT
    local has_select
    has_select=$(psql_admin "SELECT has_table_privilege('$app', 'test_table', 'SELECT');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_select" == "t" ]]; then
        test_pass "App user has SELECT"
    else
        test_fail "App user has SELECT"
    fi
    
    # Check INSERT
    local has_insert
    has_insert=$(psql_admin "SELECT has_table_privilege('$app', 'test_table', 'INSERT');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_insert" == "t" ]]; then
        test_pass "App user has INSERT"
    else
        test_fail "App user has INSERT"
    fi
    
    # Check UPDATE
    local has_update
    has_update=$(psql_admin "SELECT has_table_privilege('$app', 'test_table', 'UPDATE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_update" == "t" ]]; then
        test_pass "App user has UPDATE"
    else
        test_fail "App user has UPDATE"
    fi
    
    # Check DELETE (should NOT have)
    local has_delete
    has_delete=$(psql_admin "SELECT has_table_privilege('$app', 'test_table', 'DELETE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_delete" == "f" ]]; then
        test_pass "App user does NOT have DELETE"
    else
        test_fail "App user does NOT have DELETE" "App user has DELETE which is not expected"
    fi
}

test_readonly_user_select_only() {
    log_info "Testing readonly user SELECT only permissions..."
    
    local readonly="${TEST_DATABASE}_readonly_user"
    
    # Grant permissions
    grant_all_permissions "$TEST_DATABASE" "$readonly" "readonly_user" "public" > /dev/null 2>&1
    
    # Check SELECT
    local has_select
    has_select=$(psql_admin "SELECT has_table_privilege('$readonly', 'test_table', 'SELECT');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_select" == "t" ]]; then
        test_pass "Readonly user has SELECT"
    else
        test_fail "Readonly user has SELECT"
    fi
    
    # Check INSERT (should NOT have)
    local has_insert
    has_insert=$(psql_admin "SELECT has_table_privilege('$readonly', 'test_table', 'INSERT');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_insert" == "f" ]]; then
        test_pass "Readonly user does NOT have INSERT"
    else
        test_fail "Readonly user does NOT have INSERT"
    fi
    
    # Check UPDATE (should NOT have)
    local has_update
    has_update=$(psql_admin "SELECT has_table_privilege('$readonly', 'test_table', 'UPDATE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_update" == "f" ]]; then
        test_pass "Readonly user does NOT have UPDATE"
    else
        test_fail "Readonly user does NOT have UPDATE"
    fi
    
    # Check DELETE (should NOT have)
    local has_delete
    has_delete=$(psql_admin "SELECT has_table_privilege('$readonly', 'test_table', 'DELETE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_delete" == "f" ]]; then
        test_pass "Readonly user does NOT have DELETE"
    else
        test_fail "Readonly user does NOT have DELETE"
    fi
}

test_sequence_permissions() {
    log_info "Testing sequence permissions..."
    
    local fullaccess="${TEST_DATABASE}_fullaccess_user"
    local readonly="${TEST_DATABASE}_readonly_user"
    
    # Fullaccess should have USAGE
    local has_usage
    has_usage=$(psql_admin "SELECT has_sequence_privilege('$fullaccess', 'test_sequence', 'USAGE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_usage" == "t" ]]; then
        test_pass "Fullaccess user has USAGE on sequence"
    else
        test_fail "Fullaccess user has USAGE on sequence"
    fi
    
    # Readonly should have SELECT on sequence
    local has_select
    has_select=$(psql_admin "SELECT has_sequence_privilege('$readonly', 'test_sequence', 'SELECT');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_select" == "t" ]]; then
        test_pass "Readonly user has SELECT on sequence"
    else
        test_fail "Readonly user has SELECT on sequence"
    fi
}

test_function_permissions() {
    log_info "Testing function permissions..."
    
    local app="${TEST_DATABASE}_app_user"
    
    # App user should have EXECUTE
    local has_execute
    has_execute=$(psql_admin "SELECT has_function_privilege('$app', 'test_function()', 'EXECUTE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_execute" == "t" ]]; then
        test_pass "App user has EXECUTE on function"
    else
        test_fail "App user has EXECUTE on function"
    fi
}

test_access_on_newly_created_table_by_migration() {
    log_info "Testing access on newly created table by migration_user (default privileges)..."
    
    if ! run_psql_as_user "$TEST_DATABASE" "${TEST_DATABASE}_migration_user" "${DB_MIGRATION_PASSWORD}" "CREATE TABLE _pt_new_by_migration(id int);"; then
        test_fail "Migration user could not create table for access test"
        return
    fi
    
    local fullaccess="${TEST_DATABASE}_fullaccess_user"
    local app="${TEST_DATABASE}_app_user"
    local readonly="${TEST_DATABASE}_readonly_user"
    
    for priv in SELECT INSERT UPDATE DELETE; do
        local has_priv
        has_priv=$(psql_admin "SELECT has_table_privilege('$fullaccess', '_pt_new_by_migration', '$priv');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
        if [[ "$has_priv" == "t" ]]; then
            test_pass "Fullaccess has $priv on newly created table (by migration)"
        else
            test_fail "Fullaccess has $priv on newly created table (by migration)"
        fi
    done
    
    for priv in SELECT INSERT UPDATE; do
        local has_priv
        has_priv=$(psql_admin "SELECT has_table_privilege('$app', '_pt_new_by_migration', '$priv');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
        if [[ "$has_priv" == "t" ]]; then
            test_pass "App has $priv on newly created table (by migration)"
        else
            test_fail "App has $priv on newly created table (by migration)"
        fi
    done
    local has_del
    has_del=$(psql_admin "SELECT has_table_privilege('$app', '_pt_new_by_migration', 'DELETE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    if [[ "$has_del" == "f" ]]; then
        test_pass "App does NOT have DELETE on newly created table (by migration)"
    else
        test_fail "App does NOT have DELETE on newly created table (by migration)"
    fi
    
    local has_sel
    has_sel=$(psql_admin "SELECT has_table_privilege('$readonly', '_pt_new_by_migration', 'SELECT');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    if [[ "$has_sel" == "t" ]]; then
        test_pass "Readonly has SELECT on newly created table (by migration)"
    else
        test_fail "Readonly has SELECT on newly created table (by migration)"
    fi
    for priv in INSERT UPDATE DELETE; do
        local has_priv
        has_priv=$(psql_admin "SELECT has_table_privilege('$readonly', '_pt_new_by_migration', '$priv');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
        if [[ "$has_priv" == "f" ]]; then
            test_pass "Readonly does NOT have $priv on newly created table (by migration)"
        else
            test_fail "Readonly does NOT have $priv on newly created table (by migration)"
        fi
    done
    
    psql_admin_quiet "DROP TABLE _pt_new_by_migration;" "$TEST_DATABASE"
}

test_access_on_newly_created_table_by_owner() {
    log_info "Testing access on newly created table by owner (default privileges)..."
    
    if ! run_psql_as_user "$TEST_DATABASE" "${TEST_DATABASE}_owner" "${DB_OWNER_PASSWORD}" "CREATE TABLE _pt_new_by_owner(id int);"; then
        test_fail "Owner could not create table for access test"
        return
    fi
    
    local fullaccess="${TEST_DATABASE}_fullaccess_user"
    local app="${TEST_DATABASE}_app_user"
    local readonly="${TEST_DATABASE}_readonly_user"
    
    for priv in SELECT INSERT UPDATE DELETE; do
        local has_priv
        has_priv=$(psql_admin "SELECT has_table_privilege('$fullaccess', '_pt_new_by_owner', '$priv');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
        if [[ "$has_priv" == "t" ]]; then
            test_pass "Fullaccess has $priv on newly created table (by owner)"
        else
            test_fail "Fullaccess has $priv on newly created table (by owner)"
        fi
    done
    
    for priv in SELECT INSERT UPDATE; do
        local has_priv
        has_priv=$(psql_admin "SELECT has_table_privilege('$app', '_pt_new_by_owner', '$priv');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
        if [[ "$has_priv" == "t" ]]; then
            test_pass "App has $priv on newly created table (by owner)"
        else
            test_fail "App has $priv on newly created table (by owner)"
        fi
    done
    local has_del
    has_del=$(psql_admin "SELECT has_table_privilege('$app', '_pt_new_by_owner', 'DELETE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    if [[ "$has_del" == "f" ]]; then
        test_pass "App does NOT have DELETE on newly created table (by owner)"
    else
        test_fail "App does NOT have DELETE on newly created table (by owner)"
    fi
    
    local has_sel
    has_sel=$(psql_admin "SELECT has_table_privilege('$readonly', '_pt_new_by_owner', 'SELECT');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    if [[ "$has_sel" == "t" ]]; then
        test_pass "Readonly has SELECT on newly created table (by owner)"
    else
        test_fail "Readonly has SELECT on newly created table (by owner)"
    fi
    for priv in INSERT UPDATE DELETE; do
        local has_priv
        has_priv=$(psql_admin "SELECT has_table_privilege('$readonly', '_pt_new_by_owner', '$priv');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
        if [[ "$has_priv" == "f" ]]; then
            test_pass "Readonly does NOT have $priv on newly created table (by owner)"
        else
            test_fail "Readonly does NOT have $priv on newly created table (by owner)"
        fi
    done
    
    psql_admin_quiet "DROP TABLE _pt_new_by_owner;" "$TEST_DATABASE"
}

test_schema_migration_user_can_create_table() {
    log_info "Testing schema migration user can CREATE TABLE in test_schema..."
    
    if run_psql_as_user "$TEST_DATABASE" "${TEST_DATABASE}_test_schema_migration_user" "${SCHEMA_MIGRATION_PASSWORD}" "CREATE TABLE test_schema._pt_schema_migration_created(id int);"; then
        test_pass "Schema migration user can CREATE TABLE in test_schema"
    else
        test_fail "Schema migration user can CREATE TABLE in test_schema"
        return
    fi
    if run_psql_as_user "$TEST_DATABASE" "${TEST_DATABASE}_test_schema_migration_user" "${SCHEMA_MIGRATION_PASSWORD}" "DROP TABLE test_schema._pt_schema_migration_created;"; then
        test_pass "Schema migration user can DROP TABLE in test_schema"
    else
        test_fail "Schema migration user can DROP TABLE in test_schema"
    fi
}

test_schema_fullaccess_user_cannot_create_table() {
    log_info "Testing schema fullaccess user cannot CREATE TABLE in test_schema..."
    
    if ! run_psql_as_user "$TEST_DATABASE" "${TEST_DATABASE}_test_schema_fullaccess_user" "${SCHEMA_FULLACCESS_PASSWORD}" "CREATE TABLE test_schema._pt_schema_fullaccess_created(id int);"; then
        test_pass "Schema fullaccess user cannot CREATE TABLE in test_schema"
    else
        test_fail "Schema fullaccess user cannot CREATE TABLE in test_schema" "Expected CREATE to fail"
    fi
}

test_schema_table_access_levels() {
    log_info "Testing access on newly created table in test_schema (default privileges)..."
    
    if ! run_psql_as_user "$TEST_DATABASE" "${TEST_DATABASE}_test_schema_migration_user" "${SCHEMA_MIGRATION_PASSWORD}" "CREATE TABLE test_schema.schema_perm_test(id int);"; then
        test_fail "Schema migration user could not create table for access test"
        return
    fi
    
    local fullaccess="${TEST_DATABASE}_test_schema_fullaccess_user"
    local app="${TEST_DATABASE}_test_schema_app_user"
    local readonly="${TEST_DATABASE}_test_schema_readonly_user"
    local tbl="test_schema.schema_perm_test"
    
    for priv in SELECT INSERT UPDATE DELETE; do
        local has_priv
        has_priv=$(psql_admin "SELECT has_table_privilege('$fullaccess', '$tbl', '$priv');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
        if [[ "$has_priv" == "t" ]]; then
            test_pass "Schema fullaccess has $priv on newly created table"
        else
            test_fail "Schema fullaccess has $priv on newly created table"
        fi
    done
    
    for priv in SELECT INSERT UPDATE; do
        local has_priv
        has_priv=$(psql_admin "SELECT has_table_privilege('$app', '$tbl', '$priv');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
        if [[ "$has_priv" == "t" ]]; then
            test_pass "Schema app has $priv on newly created table"
        else
            test_fail "Schema app has $priv on newly created table"
        fi
    done
    local has_del
    has_del=$(psql_admin "SELECT has_table_privilege('$app', '$tbl', 'DELETE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    if [[ "$has_del" == "f" ]]; then
        test_pass "Schema app does NOT have DELETE on newly created table"
    else
        test_fail "Schema app does NOT have DELETE on newly created table"
    fi
    
    local has_sel
    has_sel=$(psql_admin "SELECT has_table_privilege('$readonly', '$tbl', 'SELECT');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    if [[ "$has_sel" == "t" ]]; then
        test_pass "Schema readonly has SELECT on newly created table"
    else
        test_fail "Schema readonly has SELECT on newly created table"
    fi
    for priv in INSERT UPDATE DELETE; do
        local has_priv
        has_priv=$(psql_admin "SELECT has_table_privilege('$readonly', '$tbl', '$priv');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
        if [[ "$has_priv" == "f" ]]; then
            test_pass "Schema readonly does NOT have $priv on newly created table"
        else
            test_fail "Schema readonly does NOT have $priv on newly created table"
        fi
    done
    
    psql_admin_quiet "DROP TABLE test_schema.schema_perm_test;" "$TEST_DATABASE"
}

test_revoke_permissions() {
    log_info "Testing permission revocation..."
    
    local test_user="test_custom_user"
    
    # First grant SELECT
    psql_admin_quiet "GRANT SELECT ON test_table TO $test_user;" "$TEST_DATABASE"
    
    # Verify grant worked
    local has_select
    has_select=$(psql_admin "SELECT has_table_privilege('$test_user', 'test_table', 'SELECT');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_select" == "t" ]]; then
        test_pass "SELECT granted to custom user"
    else
        test_fail "SELECT granted to custom user"
    fi
    
    # Now revoke
    psql_admin_quiet "REVOKE SELECT ON test_table FROM $test_user;" "$TEST_DATABASE"
    
    # Verify revoke worked
    has_select=$(psql_admin "SELECT has_table_privilege('$test_user', 'test_table', 'SELECT');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_select" == "f" ]]; then
        test_pass "SELECT revoked from custom user"
    else
        test_fail "SELECT revoked from custom user"
    fi
}

# =============================================================================
# Run Tests
# =============================================================================

setup_test_objects
test_migration_user_ddl
test_migration_user_can_create_table
test_owner_can_create_table
test_fullaccess_user_cannot_create_table
test_app_user_cannot_create_table
test_readonly_user_cannot_create_table
test_fullaccess_user_crud
test_app_user_cru_only
test_readonly_user_select_only
test_sequence_permissions
test_function_permissions
test_access_on_newly_created_table_by_migration
test_access_on_newly_created_table_by_owner
test_schema_migration_user_can_create_table
test_schema_fullaccess_user_cannot_create_table
test_schema_table_access_levels
test_revoke_permissions
