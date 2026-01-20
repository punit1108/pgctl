#!/bin/bash

# =============================================================================
# Non-Interactive Test Runner for pgctl
# =============================================================================
# Runs all tests without prompts or interruptions
# Usage: ./test.sh [OPTIONS]
# =============================================================================

set -e

# Get script directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/tests" && pwd)"
PGCTL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PGCTL_ROOT
LIB_DIR="${PGCTL_ROOT}/lib"

# Load configuration if available
if [[ -f "${PGCTL_ROOT}/config.env" ]]; then
    source "${PGCTL_ROOT}/config.env"
fi

# Source common library
source "${LIB_DIR}/common.sh"

# GUM testing mode (can be overridden by --test-gum or --test-all flags)
# Default: disable gum for non-interactive testing
TEST_GUM_MODE="disabled"  # disabled, enabled, or all

# =============================================================================
# Test Configuration
# =============================================================================

# Default connection settings
TEST_HOST="${PGHOST:-localhost}"
TEST_PORT="${PGPORT:-5432}"
TEST_USER="${PGADMIN:-postgres}"
TEST_PASSWORD="${PGPASSWORD:-password}"
TEST_DATABASE="${PG_TEST_DATABASE:-pgctl_test}"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Auto-cleanup flag
AUTO_CLEANUP=true
VERBOSE=false

# =============================================================================
# Usage
# =============================================================================

show_usage() {
    echo "Usage: test.sh [OPTIONS]"
    echo ""
    echo "Non-interactive test runner for pgctl"
    echo ""
    echo "Options:"
    echo "  --host, -h        PostgreSQL host (default: localhost)"
    echo "  --port, -p        PostgreSQL port (default: 5432)"
    echo "  --user, -u        Admin username (default: postgres)"
    echo "  --password, -P    Admin password (default: from config.env)"
    echo "  --database, -d    Test database name (default: pgctl_test)"
    echo "  --no-cleanup      Skip cleanup after tests"
    echo "  --verbose, -v     Show detailed output"
    echo "  --test-gum        Enable GUM interface testing (requires gum installed)"
    echo "  --test-all        Run tests with both GUM disabled and enabled"
    echo "  --help            Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  PGHOST, PGPORT, PGADMIN, PGPASSWORD can be set instead of options"
    echo ""
    echo "Example:"
    echo "  ./test.sh"
    echo "  ./test.sh --host localhost --port 5432 --user postgres -P mypassword"
    echo "  ./test.sh --no-cleanup --verbose"
    echo "  ./test.sh --test-gum    # Test with GUM interface enabled"
    echo "  ./test.sh --test-all    # Run all tests twice (with and without GUM)"
}

# =============================================================================
# Argument Parsing
# =============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host|-h)
            TEST_HOST="$2"
            shift 2
            ;;
        --port|-p)
            TEST_PORT="$2"
            shift 2
            ;;
        --user|-u)
            TEST_USER="$2"
            shift 2
            ;;
        --password|-P)
            TEST_PASSWORD="$2"
            shift 2
            ;;
        --database|-d)
            TEST_DATABASE="$2"
            shift 2
            ;;
        --no-cleanup)
            AUTO_CLEANUP=false
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --test-gum)
            TEST_GUM_MODE="enabled"
            shift
            ;;
        --test-all)
            TEST_GUM_MODE="all"
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Set environment variables
export PGHOST="$TEST_HOST"
export PGPORT="$TEST_PORT"
export PGADMIN="$TEST_USER"
export PGPASSWORD="$TEST_PASSWORD"

# Set test passwords to avoid prompts
export DB_OWNER_PASSWORD="test_owner_pass"
export DB_MIGRATION_PASSWORD="test_migration_pass"
export DB_FULLACCESS_PASSWORD="test_fullaccess_pass"
export DB_APP_PASSWORD="test_app_pass"
export DB_READONLY_PASSWORD="test_readonly_pass"

# Set schema passwords to avoid prompts
export SCHEMA_OWNER_PASSWORD="test_schema_owner_pass"
export SCHEMA_MIGRATION_PASSWORD="test_schema_migration_pass"
export SCHEMA_FULLACCESS_PASSWORD="test_schema_fullaccess_pass"
export SCHEMA_APP_PASSWORD="test_schema_app_pass"
export SCHEMA_READONLY_PASSWORD="test_schema_readonly_pass"

# =============================================================================
# Test Utilities
# =============================================================================

# Record test result
test_pass() {
    local name="$1"
    ((TESTS_PASSED++))
    ((TESTS_TOTAL++))
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum style --foreground 10 "  ✓ $name"
    else
        echo -e "  ${GREEN}✓${NC} $name"
    fi
}

test_fail() {
    local name="$1"
    local reason="${2:-}"
    ((TESTS_FAILED++))
    ((TESTS_TOTAL++))
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum style --foreground 9 "  ✗ $name"
        if [[ -n "$reason" ]]; then
            gum style --foreground 9 "    Reason: $reason"
        fi
    else
        echo -e "  ${RED}✗${NC} $name"
        if [[ -n "$reason" ]]; then
            echo -e "    Reason: $reason"
        fi
    fi
}

# Assert functions
assert_true() {
    local condition="$1"
    local name="$2"
    
    if eval "$condition"; then
        test_pass "$name"
        return 0
    else
        test_fail "$name" "Condition failed: $condition"
        return 1
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local name="$3"
    
    if [[ "$expected" == "$actual" ]]; then
        test_pass "$name"
        return 0
    else
        test_fail "$name" "Expected '$expected', got '$actual'"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local name="$3"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        test_pass "$name"
        return 0
    else
        test_fail "$name" "String does not contain '$needle'"
        return 1
    fi
}

# Run SQL as a given user; returns psql exit code (0 = success)
run_psql_as_user() {
    local db="$1" user="$2" pass="$3" sql="$4"
    if [[ "$VERBOSE" == "true" ]]; then
        PGPASSWORD="$pass" psql -h "$PGHOST" -p "$PGPORT" -U "$user" -d "$db" -c "$sql"
    else
        PGPASSWORD="$pass" psql -h "$PGHOST" -p "$PGPORT" -U "$user" -d "$db" -c "$sql" >/dev/null 2>&1
    fi
    return $?
}

# =============================================================================
# Test Setup
# =============================================================================

setup_test_env() {
    log_info "Setting up test environment..."
    
    # Clean up any existing test database
    if database_exists "$TEST_DATABASE"; then
        log_info "Cleaning up existing test database..."
        psql_admin_quiet "DROP DATABASE IF EXISTS $TEST_DATABASE;"
        
        # Clean up test users
        for role in owner migration_user fullaccess_user app_user readonly_user; do
            local user="${TEST_DATABASE}_${role}"
            if user_exists "$user"; then
                psql_admin_quiet "DROP ROLE IF EXISTS $user;"
            fi
        done
    fi
}

# Setup test schema for permission tests
setup_test_schema() {
    log_info "Creating test schema for permission tests..."
    
    # Source schema library
    source "${LIB_DIR}/schema.sh"
    
    # Create test schema non-interactively
    create_schema "$TEST_DATABASE" "test_schema" &> /dev/null || {
        log_warning "Could not create test schema (tests may be skipped)"
    }
    
    log_success "Test schema ready"
}

cleanup_test_env() {
    log_info "Cleaning up test environment..."
    
    # Drop test database if it exists
    if database_exists "$TEST_DATABASE"; then
        psql_admin_quiet "DROP DATABASE IF EXISTS $TEST_DATABASE;" 2>/dev/null || true
    fi
    
    # Clean up test users
    for role in owner migration_user fullaccess_user app_user readonly_user; do
        local user="${TEST_DATABASE}_${role}"
        if user_exists "$user"; then
            psql_admin_quiet "REASSIGN OWNED BY $user TO $PGADMIN;" 2>/dev/null || true
            psql_admin_quiet "DROP OWNED BY $user;" 2>/dev/null || true
            psql_admin_quiet "DROP ROLE IF EXISTS $user;" 2>/dev/null || true
        fi
    done
    
    # Clean up test schema users
    for role in owner migration_user fullaccess_user app_user readonly_user; do
        local user="${TEST_DATABASE}_test_schema_${role}"
        if user_exists "$user"; then
            psql_admin_quiet "REASSIGN OWNED BY $user TO $PGADMIN;" 2>/dev/null || true
            psql_admin_quiet "DROP OWNED BY $user;" 2>/dev/null || true
            psql_admin_quiet "DROP ROLE IF EXISTS $user;" 2>/dev/null || true
        fi
    done
    
    # Clean up custom test user
    if user_exists "test_custom_user"; then
        psql_admin_quiet "REASSIGN OWNED BY test_custom_user TO $PGADMIN;" 2>/dev/null || true
        psql_admin_quiet "DROP OWNED BY test_custom_user;" 2>/dev/null || true
        psql_admin_quiet "DROP ROLE IF EXISTS test_custom_user;" 2>/dev/null || true
    fi
    
    log_success "Cleanup complete"
}

# =============================================================================
# Run Individual Test Files
# =============================================================================

run_test_file() {
    local test_file="$1"
    local test_name="$2"
    
    echo ""
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum style --foreground 12 --bold "Running: $test_name"
    else
        echo -e "${BOLD}Running: $test_name${NC}"
    fi
    echo ""
    
    if [[ -f "$test_file" ]]; then
        source "$test_file"
    else
        log_warning "Test file not found: $test_file"
    fi
}

# =============================================================================
# Main Test Execution
# =============================================================================

main() {
    # Override prompt_confirm to auto-accept for tests
    # This must be done here, after common.sh is sourced, to override its definition
    prompt_confirm() {
        local prompt="$1"
        local default="${2:-y}"  # Default to 'y' (yes) for tests
        
        # In verbose mode, show what we're auto-confirming
        if [[ "$VERBOSE" == "true" ]]; then
            echo "[TEST] Auto-confirming: $prompt -> yes"
        fi
        
        return 0  # Always return success
    }
    
    log_header "pgctl Test Suite (Non-Interactive)"
    
    echo ""
    log_info "Connection: ${TEST_HOST}:${TEST_PORT}"
    log_info "Admin user: ${TEST_USER}"
    log_info "Test database: ${TEST_DATABASE}"
    log_info "Auto-cleanup: ${AUTO_CLEANUP}"
    log_info "GUM mode: ${GUM_AVAILABLE}"
    echo ""
    
    # Test connection
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        if ! gum spin --spinner dot --title "Testing connection..." -- bash -c "source '${LIB_DIR}/common.sh'; check_connection"; then
            log_error "Cannot connect to PostgreSQL"
            log_error "Please check your credentials in config.env or use --password option"
            exit 1
        fi
    else
        echo -n "Testing connection... "
        if ! check_connection 2>/dev/null; then
            echo ""
            log_error "Cannot connect to PostgreSQL"
            log_error "Please check your credentials in config.env or use --password option"
            exit 1
        fi
        echo "done"
    fi
    log_success "Connection successful"
    
    echo ""
    
    # Setup
    setup_test_env
    
    # Run test files
    run_test_file "${TEST_DIR}/test-database.sh" "Database Tests"
    run_test_file "${TEST_DIR}/test-users.sh" "User Tests"
    
    # Create test schema for permission tests
    echo ""
    setup_test_schema
    echo ""
    
    run_test_file "${TEST_DIR}/test-permissions.sh" "Permission Tests"
    
    # GUM interface tests (only run when GUM is enabled)
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        run_test_file "${TEST_DIR}/test-gum-interface.sh" "GUM Interface Tests"
    fi
    
    # TODO: Schema tests have more comprehensive tests but have interactive components
    # run_test_file "${TEST_DIR}/test-schema.sh" "Schema Tests"
    # TODO: Multiselect tests - delete_user tests implemented, others still placeholders
    # run_test_file "${TEST_DIR}/test-multiselect.sh" "Multiselect Tests"
    
    echo ""
    echo ""
    
    # Results summary
    local summary="TEST RESULTS

Total:  $TESTS_TOTAL
Passed: $TESTS_PASSED
Failed: $TESTS_FAILED"
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        if [[ $TESTS_FAILED -eq 0 ]]; then
            gum style --border rounded --padding "1 2" --border-foreground 10 "$summary"
        else
            gum style --border rounded --padding "1 2" --border-foreground 9 "$summary"
        fi
    else
        echo ""
        echo "═══════════════════════════════"
        echo "$summary"
        echo "═══════════════════════════════"
    fi
    
    echo ""
    
    # Auto-cleanup if enabled
    if [[ "$AUTO_CLEANUP" == "true" ]]; then
        cleanup_test_env
    else
        log_info "Test data retained for inspection (--no-cleanup was specified)"
    fi
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -gt 0 ]]; then
        log_error "Tests failed!"
        exit 1
    fi
    
    log_success "All tests passed!"
    exit 0
}

# =============================================================================
# Test Mode Execution
# =============================================================================

run_tests_with_gum_mode() {
    local gum_enabled="$1"
    local mode_label="$2"
    
    export GUM_AVAILABLE="$gum_enabled"
    
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  Running tests: $mode_label"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    
    # Reset counters for this test run
    TESTS_PASSED=0
    TESTS_FAILED=0
    TESTS_TOTAL=0
    
    # Run main in subshell to isolate each test run
    (yes | main)
    local exit_code=$?
    
    return $exit_code
}

# Execute based on test mode
case "$TEST_GUM_MODE" in
    enabled)
        # Check if gum is available
        if ! command -v gum &> /dev/null; then
            echo "Error: --test-gum specified but gum is not installed"
            echo "Install gum first: brew install gum (or see docs/INSTALLATION.md)"
            exit 1
        fi
        run_tests_with_gum_mode "true" "GUM ENABLED"
        ;;
    
    all)
        # Check if gum is available
        if ! command -v gum &> /dev/null; then
            echo "Warning: gum is not installed, skipping GUM-enabled tests"
            echo "Install gum to run full test suite: brew install gum"
            echo ""
            run_tests_with_gum_mode "false" "GUM DISABLED (only)"
        else
            # Run without GUM first
            echo "Running test suite in both modes..."
            echo ""
            
            run_tests_with_gum_mode "false" "GUM DISABLED"
            no_gum_exit=$?
            
            # Run with GUM second
            run_tests_with_gum_mode "true" "GUM ENABLED"
            with_gum_exit=$?
            
            echo ""
            echo "════════════════════════════════════════════════════════════════"
            echo "  FINAL RESULTS"
            echo "════════════════════════════════════════════════════════════════"
            if [[ $no_gum_exit -eq 0 ]] && [[ $with_gum_exit -eq 0 ]]; then
                echo "✓ All tests passed in both modes!"
                exit 0
            else
                echo "✗ Some tests failed:"
                [[ $no_gum_exit -ne 0 ]] && echo "  - GUM DISABLED mode: FAILED"
                [[ $with_gum_exit -ne 0 ]] && echo "  - GUM ENABLED mode: FAILED"
                exit 1
            fi
        fi
        ;;
    
    disabled|*)
        # Default: disable gum for non-interactive testing
        run_tests_with_gum_mode "false" "GUM DISABLED (default)"
        ;;
esac
