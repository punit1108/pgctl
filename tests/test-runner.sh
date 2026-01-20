#!/bin/bash

# =============================================================================
# Test Runner for pgctl
# =============================================================================
# Runs all tests against a local PostgreSQL instance
# =============================================================================

set -e

# Get script directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PGCTL_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
export PGCTL_ROOT
LIB_DIR="${PGCTL_ROOT}/lib"

# Source common library
source "${LIB_DIR}/common.sh"

# =============================================================================
# Test Configuration
# =============================================================================

# GUM testing mode (can be overridden by --test-gum flag)
TEST_GUM_MODE="default"  # default, enabled, disabled

# Default connection settings
TEST_HOST="${PGHOST:-localhost}"
TEST_PORT="${PGPORT:-5432}"
TEST_USER="${PGADMIN:-postgres}"
TEST_PASSWORD="${PGPASSWORD:-}"
TEST_DATABASE="${PG_TEST_DATABASE:-pgctl_test}"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# =============================================================================
# Usage
# =============================================================================

show_usage() {
    echo "Usage: test-runner.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --host, -h        PostgreSQL host (default: localhost)"
    echo "  --port, -p        PostgreSQL port (default: 5432)"
    echo "  --user, -u        Admin username (default: postgres)"
    echo "  --password, -P    Admin password (prompts if not provided)"
    echo "  --database, -d    Test database name (default: pgctl_test)"
    echo "  --test-gum        Force enable GUM interface testing"
    echo "  --no-gum          Force disable GUM interface (non-interactive mode)"
    echo "  --help            Show this help message"
    echo ""
    echo "Example:"
    echo "  ./test-runner.sh --host localhost --port 5432 --user postgres"
    echo "  ./test-runner.sh --test-gum    # Test with GUM interface enabled"
    echo "  ./test-runner.sh --no-gum      # Test without GUM (faster, no UI)"
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
        --test-gum)
            TEST_GUM_MODE="enabled"
            shift
            ;;
        --no-gum)
            TEST_GUM_MODE="disabled"
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

# Apply GUM mode settings
case "$TEST_GUM_MODE" in
    enabled)
        # Force enable GUM (check if available first)
        if ! command -v gum &> /dev/null; then
            echo "Error: --test-gum specified but gum is not installed"
            echo "Install gum first: brew install gum (or see docs/INSTALLATION.md)"
            exit 1
        fi
        export GUM_AVAILABLE="true"
        ;;
    disabled)
        # Force disable GUM
        export GUM_AVAILABLE="false"
        ;;
    default|*)
        # Use default detection from common.sh (already loaded)
        # GUM_AVAILABLE is already set by common.sh
        ;;
esac

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
    PGPASSWORD="$pass" psql -h "$PGHOST" -p "$PGPORT" -U "$user" -d "$db" -c "$sql" >/dev/null 2>&1
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

cleanup_test_env() {
    log_info "Cleaning up test environment..."
    
    # Drop test database if it exists
    if database_exists "$TEST_DATABASE"; then
        psql_admin_quiet "DROP DATABASE IF EXISTS $TEST_DATABASE;"
    fi
    
    # Clean up test users
    for role in owner migration_user fullaccess_user app_user readonly_user; do
        local user="${TEST_DATABASE}_${role}"
        if user_exists "$user"; then
            psql_admin_quiet "REASSIGN OWNED BY $user TO $PGADMIN;" 2>/dev/null || true
            psql_admin_quiet "DROP OWNED BY $user;" 2>/dev/null || true
            psql_admin_quiet "DROP ROLE IF EXISTS $user;"
        fi
    done
    
    # Clean up test schema users
    for role in owner migration_user fullaccess_user app_user readonly_user; do
        local user="${TEST_DATABASE}_test_schema_${role}"
        if user_exists "$user"; then
            psql_admin_quiet "REASSIGN OWNED BY $user TO $PGADMIN;" 2>/dev/null || true
            psql_admin_quiet "DROP OWNED BY $user;" 2>/dev/null || true
            psql_admin_quiet "DROP ROLE IF EXISTS $user;"
        fi
    done
    
    # Clean up custom test user from all databases
    if user_exists "test_custom_user"; then
        # Get all databases and clean privileges from each
        local all_dbs
        all_dbs=$(psql_admin "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname;" 2>/dev/null | tail -n +3 | sed '$d' | sed '$d' | tr -d ' ')
        while IFS= read -r dbname; do
            [[ -z "$dbname" ]] && continue
            psql_admin_quiet "REASSIGN OWNED BY test_custom_user TO $PGADMIN;" "$dbname" 2>/dev/null || true
            psql_admin_quiet "DROP OWNED BY test_custom_user;" "$dbname" 2>/dev/null || true
        done <<< "$all_dbs"
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
    log_header "pgctl Test Suite"
    
    echo ""
    log_info "Connection: ${TEST_HOST}:${TEST_PORT}"
    log_info "Admin user: ${TEST_USER}"
    log_info "Test database: ${TEST_DATABASE}"
    log_info "GUM mode: ${GUM_AVAILABLE}"
    echo ""
    
    # Prompt for password if not set
    if [[ -z "$TEST_PASSWORD" ]]; then
        TEST_PASSWORD=$(prompt_password "PostgreSQL admin password")
    fi
    export PGPASSWORD="$TEST_PASSWORD"
    
    # Test connection
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        if ! gum spin --spinner dot --title "Testing connection..." -- bash -c "source '${LIB_DIR}/common.sh'; check_connection"; then
            log_error "Cannot connect to PostgreSQL"
            exit 1
        fi
    else
        echo -n "Testing connection... "
        if ! check_connection; then
            log_error "Cannot connect to PostgreSQL"
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
    run_test_file "${TEST_DIR}/test-schema.sh" "Schema Tests"
    run_test_file "${TEST_DIR}/test-permissions.sh" "Permission Tests"
    run_test_file "${TEST_DIR}/test-multiselect.sh" "Multiselect Tests"
    
    # GUM interface tests (only run when GUM is enabled)
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        run_test_file "${TEST_DIR}/test-gum-interface.sh" "GUM Interface Tests"
    fi
    
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
    
    # Cleanup prompt
    if prompt_confirm "Clean up test data?"; then
        cleanup_test_env
    else
        log_info "Test data retained for inspection"
    fi
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

# Run main
main
