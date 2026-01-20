# pgctl Test Suite

This directory contains the test suite for pgctl, including comprehensive tests for all functionality.

## Test Files

### Core Test Files
- **test-database.sh** - Database creation, deletion, and listing tests
- **test-users.sh** - User management and permission tests
- **test-schema.sh** - Schema operations and isolation tests
- **test-permissions.sh** - Permission granting and verification tests
- **test-multiselect.sh** - Multi-selection functionality tests
- **test-gum-interface.sh** - GUM interface and UI component tests

### Test Runners
- **test-runner.sh** - Interactive test runner (supports GUM)
- **../test.sh** - Non-interactive test runner (automated CI/CD)

## Running Tests

### Quick Start

```bash
# From project root - run all tests (non-interactive)
./test.sh

# Run interactive tests
./tests/test-runner.sh
```

### GUM Interface Testing

The GUM interface tests verify that the interactive UI components work correctly:

```bash
# Test with GUM enabled (requires gum installed)
./test.sh --test-gum

# Test both GUM modes
./test.sh --test-all

# Interactive testing with GUM
./tests/test-runner.sh --test-gum

# Interactive testing without GUM
./tests/test-runner.sh --no-gum
```

### Test Options

#### Connection Options
```bash
--host, -h        PostgreSQL host (default: localhost)
--port, -p        PostgreSQL port (default: 5432)
--user, -u        Admin username (default: postgres)
--password, -P    Admin password (prompted if not set)
--database, -d    Test database name (default: pgctl_test)
```

#### Test Behavior Options
```bash
--no-cleanup      Keep test database after tests (for inspection)
--verbose, -v     Show detailed output (test.sh only)
--test-gum        Enable GUM interface testing
--test-all        Run tests in both GUM modes (test.sh only)
--no-gum          Disable GUM interface (test-runner.sh only)
```

## Test Coverage

### What's Tested

#### Database Operations
- ✓ Database creation with all role types
- ✓ Database deletion and cleanup
- ✓ Database listing and existence checks
- ✓ Connection validation

#### User Management
- ✓ User creation with various permission levels
- ✓ User listing and filtering
- ✓ Password changes
- ✓ User deletion and reassignment
- ✓ User privilege verification

#### Schema Operations
- ✓ Schema creation with isolation
- ✓ Schema deletion and cleanup
- ✓ Schema listing per database
- ✓ Schema user management
- ✓ Multi-tenant isolation

#### Permission Management
- ✓ Permission granting (all role types)
- ✓ Default privilege configuration
- ✓ Schema isolation enforcement
- ✓ Cross-schema access prevention
- ✓ Permission auditing

#### GUM Interface (when --test-gum enabled)
- ✓ Query function execution in subshells
- ✓ Loading indicators and spinners
- ✓ Styled logging output
- ✓ Integration with actual operations
- ✓ Parity between GUM/non-GUM modes

### Role Types Tested
Each test verifies functionality for all role types:
- **owner** - Full database/schema control
- **migration_user** - DDL operations (CREATE, ALTER, DROP)
- **fullaccess_user** - DML operations (SELECT, INSERT, UPDATE, DELETE)
- **app_user** - Read/write access (SELECT, INSERT, UPDATE)
- **readonly_user** - Read-only access (SELECT)

## GUM Testing Details

### Why Separate GUM Tests?

The GUM interface uses `gum spin` to run commands in subshells, which requires:
1. Functions must be available in the subshell (via sourcing)
2. Environment variables must be exported
3. No interactive prompts (incompatible with automated testing)

### What GUM Tests Verify

1. **No "command not found" errors** - Critical for user experience
2. **Query functions work in subshells** - list_users_query, list_databases_query, etc.
3. **Styled output renders correctly** - No broken formatting or errors
4. **Parity with non-GUM mode** - Same results regardless of UI mode

### GUM Test Execution Flow

```
1. Check if gum is installed
2. Set GUM_AVAILABLE=true
3. Run query functions directly
4. Run via list_with_loading wrapper
5. Verify output has no errors
6. Compare results with non-GUM mode
```

## Test Database

Tests use a dedicated database: `pgctl_test` (configurable via `--database`)

### Created Resources
- Database: `pgctl_test`
- Users: `pgctl_test_owner`, `pgctl_test_migration_user`, etc.
- Schema: `test_schema` (for schema-specific tests)
- Custom users: `test_custom_user` (cleaned up after tests)

### Cleanup
By default, all test resources are cleaned up after tests complete.
Use `--no-cleanup` to inspect the test database after a run.

## Writing New Tests

### Test Structure

```bash
#!/bin/bash
# Source dependencies
source "${LIB_DIR}/your-module.sh"

# Test function
test_your_feature() {
    log_info "Testing your feature..."
    
    # Test logic
    if your_function; then
        test_pass "Description of what passed"
    else
        test_fail "Description of what failed" "Optional reason"
    fi
}

# Run tests
test_your_feature
```

### Test Utilities

```bash
# Record test results
test_pass "test description"
test_fail "test description" "optional failure reason"

# Logging (works with and without GUM)
log_info "Information message"
log_success "Success message"
log_warning "Warning message"
log_error "Error message"

# Database utilities
psql_admin "SQL query" "database"          # Run as admin
psql_admin_quiet "SQL query"               # Suppress output
check_connection                            # Verify DB connection
user_exists "username"                      # Check if user exists
database_exists "dbname"                    # Check if database exists
```

## Continuous Integration

For CI/CD pipelines:

```bash
# Run non-interactive tests
./test.sh --host "$DB_HOST" --port "$DB_PORT" --user postgres --password "$DB_PASSWORD"

# Exit code: 0 = all passed, 1 = some failed
```

### Environment Setup for CI

```yaml
# Example GitHub Actions
env:
  PGHOST: localhost
  PGPORT: 5432
  PGADMIN: postgres
  PGPASSWORD: ${{ secrets.DB_PASSWORD }}
  
steps:
  - name: Run Tests
    run: ./test.sh --verbose
```

## Troubleshooting Tests

### Tests Hang or Timeout
- Ensure database is running: `psql -h localhost -U postgres -c '\l'`
- Check firewall rules allow connections
- Verify credentials in config.env

### "Permission Denied" Errors
- Ensure test user has CREATEDB and CREATEROLE privileges
- Run as PostgreSQL superuser (default: postgres)

### GUM Tests Fail
- Install gum: `brew install gum` or see docs/INSTALLATION.md
- Ensure gum is in PATH: `command -v gum`
- Try without GUM: `./test.sh` (default)

### "Database Already Exists" Errors
- Previous test run didn't cleanup
- Manually cleanup: `./pgctl delete-db pgctl_test`
- Or use different test DB: `./test.sh --database pgctl_test2`

## Test Development Tips

1. **Use descriptive test names** - Makes failures easier to diagnose
2. **Test both success and failure cases** - Verify error handling
3. **Clean up after yourself** - Don't leave test artifacts
4. **Use test_pass/test_fail consistently** - Enables accurate reporting
5. **Test with GUM disabled by default** - More reliable for automation
6. **Add GUM-specific tests when needed** - For UI component verification

## See Also

- [../README.md](../README.md) - Main project documentation
- [../docs/INSTALLATION.md](../docs/INSTALLATION.md) - Installation guide
