#!/bin/bash

# =============================================================================
# GUM Interface Tests for pgctl
# =============================================================================
# Tests for GUM-enabled functionality to ensure interactive UI components work
# These tests verify that GUM code paths execute without errors
# =============================================================================

# This file is sourced by test-runner.sh

# Source dependencies
source "${LIB_DIR}/database.sh"
source "${LIB_DIR}/schema.sh"
source "${LIB_DIR}/users.sh"

# =============================================================================
# GUM Availability Tests
# =============================================================================

test_gum_detection() {
    log_info "Testing GUM detection..."
    
    # Test that GUM_AVAILABLE is set
    if [[ -n "${GUM_AVAILABLE}" ]]; then
        test_pass "GUM_AVAILABLE variable is set"
    else
        test_fail "GUM_AVAILABLE variable is set"
    fi
    
    # Test that it matches actual gum availability
    if command -v gum &> /dev/null; then
        if [[ "$GUM_AVAILABLE" == "true" ]]; then
            test_pass "GUM_AVAILABLE correctly set to true when gum exists"
        else
            test_fail "GUM_AVAILABLE should be true when gum is installed"
        fi
    else
        if [[ "$GUM_AVAILABLE" == "false" ]]; then
            test_pass "GUM_AVAILABLE correctly set to false when gum missing"
        else
            test_fail "GUM_AVAILABLE should be false when gum is not installed"
        fi
    fi
}

# =============================================================================
# Query Function Tests (with GUM enabled)
# =============================================================================

test_list_databases_query() {
    log_info "Testing list_databases_query function..."
    
    local result
    # This should work whether GUM is available or not
    result=$(list_databases_query 2>&1)
    local exit_code=$?
    
    # Check it executed without "command not found" error
    if [[ "$result" != *"command not found"* ]]; then
        test_pass "list_databases_query executes without 'command not found' error"
    else
        test_fail "list_databases_query executes without 'command not found' error" "Got: $result"
    fi
    
    # Check it returned some results (should at least have postgres database)
    if [[ -n "$result" ]] && [[ $exit_code -eq 0 ]]; then
        test_pass "list_databases_query returns results"
    else
        test_fail "list_databases_query returns results"
    fi
}

test_list_users_query() {
    log_info "Testing list_users_query function..."
    
    local result
    result=$(list_users_query 2>&1)
    local exit_code=$?
    
    # Check it executed without "command not found" error
    if [[ "$result" != *"command not found"* ]]; then
        test_pass "list_users_query executes without 'command not found' error"
    else
        test_fail "list_users_query executes without 'command not found' error" "Got: $result"
    fi
    
    # Check it returned some results
    if [[ -n "$result" ]] && [[ $exit_code -eq 0 ]]; then
        test_pass "list_users_query returns results"
    else
        test_fail "list_users_query returns results"
    fi
}

test_list_schemas_query() {
    log_info "Testing list_schemas_query function..."
    
    local result
    result=$(list_schemas_query "$TEST_DATABASE" 2>&1)
    local exit_code=$?
    
    # Check it executed without "command not found" error
    if [[ "$result" != *"command not found"* ]]; then
        test_pass "list_schemas_query executes without 'command not found' error"
    else
        test_fail "list_schemas_query executes without 'command not found' error" "Got: $result"
    fi
    
    # Note: May not have results if no custom schemas exist, so we don't check for content
    if [[ $exit_code -eq 0 ]]; then
        test_pass "list_schemas_query executes successfully"
    else
        test_fail "list_schemas_query executes successfully"
    fi
}

# =============================================================================
# list_with_loading Wrapper Tests
# =============================================================================

test_list_with_loading_databases() {
    log_info "Testing list_with_loading for databases..."
    
    local result
    result=$(list_with_loading "databases" "list_databases_query" 2>&1)
    local exit_code=$?
    
    # This is the critical test - should not get "command not found" with GUM
    if [[ "$result" != *"command not found"* ]]; then
        test_pass "list_with_loading (databases) executes without 'command not found' error"
    else
        test_fail "list_with_loading (databases) executes without 'command not found' error" "Got: $result"
    fi
    
    if [[ -n "$result" ]] && [[ $exit_code -eq 0 ]]; then
        test_pass "list_with_loading (databases) returns results"
    else
        test_fail "list_with_loading (databases) returns results"
    fi
    
    # Verify test database is in results
    if [[ "$result" == *"$TEST_DATABASE"* ]]; then
        test_pass "list_with_loading (databases) includes test database"
    else
        test_fail "list_with_loading (databases) includes test database"
    fi
}

test_list_with_loading_users() {
    log_info "Testing list_with_loading for users..."
    
    local result
    result=$(list_with_loading "users" "list_users_query" 2>&1)
    local exit_code=$?
    
    # Critical test for the bug fix
    if [[ "$result" != *"command not found"* ]]; then
        test_pass "list_with_loading (users) executes without 'command not found' error"
    else
        test_fail "list_with_loading (users) executes without 'command not found' error" "Got: $result"
    fi
    
    if [[ -n "$result" ]] && [[ $exit_code -eq 0 ]]; then
        test_pass "list_with_loading (users) returns results"
    else
        test_fail "list_with_loading (users) returns results"
    fi
    
    # Verify test database users are in results
    if [[ "$result" == *"${TEST_DATABASE}_owner"* ]]; then
        test_pass "list_with_loading (users) includes test database owner"
    else
        test_fail "list_with_loading (users) includes test database owner"
    fi
}

test_list_with_loading_schemas() {
    log_info "Testing list_with_loading for schemas..."
    
    local result
    result=$(list_with_loading "schemas" "list_schemas_query '$TEST_DATABASE'" 2>&1)
    local exit_code=$?
    
    if [[ "$result" != *"command not found"* ]]; then
        test_pass "list_with_loading (schemas) executes without 'command not found' error"
    else
        test_fail "list_with_loading (schemas) executes without 'command not found' error" "Got: $result"
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        test_pass "list_with_loading (schemas) executes successfully"
    else
        test_fail "list_with_loading (schemas) executes successfully"
    fi
}

# =============================================================================
# GUM Logging Function Tests
# =============================================================================

test_log_functions() {
    log_info "Testing GUM logging functions..."
    
    # Test that log functions work without errors
    local result
    
    # Capture output and check for errors
    result=$(log_info "Test info message" 2>&1)
    if [[ $? -eq 0 ]]; then
        test_pass "log_info executes without error"
    else
        test_fail "log_info executes without error"
    fi
    
    result=$(log_success "Test success message" 2>&1)
    if [[ $? -eq 0 ]]; then
        test_pass "log_success executes without error"
    else
        test_fail "log_success executes without error"
    fi
    
    result=$(log_warning "Test warning message" 2>&1)
    if [[ $? -eq 0 ]]; then
        test_pass "log_warning executes without error"
    else
        test_fail "log_warning executes without error"
    fi
    
    result=$(log_error "Test error message" 2>&1)
    if [[ $? -eq 0 ]]; then
        test_pass "log_error executes without error"
    else
        test_fail "log_error executes without error"
    fi
}

test_log_header() {
    log_info "Testing log_header function..."
    
    local result
    result=$(log_header "Test Header" 2>&1)
    
    if [[ $? -eq 0 ]]; then
        test_pass "log_header executes without error"
    else
        test_fail "log_header executes without error"
    fi
}

test_display_credentials() {
    log_info "Testing display functions..."
    
    # Test that display_credentials function exists and works
    local result
    result=$(type display_credentials 2>&1)
    
    if [[ $result == *"is a function"* ]]; then
        test_pass "display_credentials function is available"
    else
        test_fail "display_credentials function is available"
    fi
}

# =============================================================================
# Integration Tests - Real Use Cases
# =============================================================================

test_database_listing_integration() {
    log_info "Testing database listing (as used in actual operations)..."
    
    # This simulates the actual usage in lib/database.sh:278
    local databases
    databases=$(list_with_loading "databases" "list_databases_query" 2>&1)
    local exit_code=$?
    
    if [[ "$databases" != *"command not found"* ]] && [[ $exit_code -eq 0 ]]; then
        test_pass "Database listing integration works correctly"
    else
        test_fail "Database listing integration works correctly" "Output: $databases, Exit: $exit_code"
    fi
}

test_user_listing_integration() {
    log_info "Testing user listing (as used in actual operations)..."
    
    # This simulates the actual usage in lib/users.sh:241
    local users
    users=$(list_with_loading "users" "list_users_query" 2>&1)
    local exit_code=$?
    
    if [[ "$users" != *"command not found"* ]] && [[ $exit_code -eq 0 ]]; then
        test_pass "User listing integration works correctly"
    else
        test_fail "User listing integration works correctly" "Output: $users, Exit: $exit_code"
    fi
}

test_schema_listing_integration() {
    log_info "Testing schema listing (as used in actual operations)..."
    
    # This simulates the actual usage in lib/schema.sh:775
    local schemas
    schemas=$(list_with_loading "schemas" "list_schemas_query '$TEST_DATABASE'" 2>&1)
    local exit_code=$?
    
    if [[ "$schemas" != *"command not found"* ]] && [[ $exit_code -eq 0 ]]; then
        test_pass "Schema listing integration works correctly"
    else
        test_fail "Schema listing integration works correctly" "Output: $schemas, Exit: $exit_code"
    fi
}

# =============================================================================
# GUM vs Non-GUM Parity Tests
# =============================================================================

test_parity_databases() {
    log_info "Testing parity between GUM and non-GUM database queries..."
    
    # Save current GUM state
    local original_gum="$GUM_AVAILABLE"
    
    # Get results with current state
    local result_current
    result_current=$(list_with_loading "databases" "list_databases_query" 2>/dev/null)
    
    # Temporarily toggle GUM state
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        GUM_AVAILABLE="false"
    else
        GUM_AVAILABLE="true"
    fi
    
    # Get results with toggled state
    local result_toggled
    result_toggled=$(list_with_loading "databases" "list_databases_query" 2>/dev/null)
    
    # Restore original state
    GUM_AVAILABLE="$original_gum"
    
    # Compare results (both should include test database)
    if [[ "$result_current" == *"$TEST_DATABASE"* ]] && [[ "$result_toggled" == *"$TEST_DATABASE"* ]]; then
        test_pass "GUM and non-GUM modes produce consistent database results"
    else
        test_fail "GUM and non-GUM modes produce consistent database results"
    fi
}

# =============================================================================
# Run Tests
# =============================================================================

# Basic GUM tests
test_gum_detection

# Query function tests
test_list_databases_query
test_list_users_query
test_list_schemas_query

# Wrapper tests (critical for bug fix)
test_list_with_loading_databases
test_list_with_loading_users
test_list_with_loading_schemas

# Logging tests
test_log_functions
test_log_header
test_display_credentials

# Integration tests
test_database_listing_integration
test_user_listing_integration
test_schema_listing_integration

# Parity tests
test_parity_databases
