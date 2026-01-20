# pgctl - PostgreSQL Management Tool

A CLI tool for managing PostgreSQL databases, schemas, users, and permissions. Built with [Charm Bracelet's gum](https://github.com/charmbracelet/gum) for interactive, glamorous shell scripts.

## Features

- **Database Management**: Create databases with standardized user roles
- **Schema Management**: Create schemas with schema-specific users for multi-tenant applications
- **User Management**: Interactive user creation wizard, password management, permission viewing
- **Fine-Grained Access Control**: 5 predefined role types with appropriate permissions
- **Default Privileges**: Automatic permission inheritance for future objects
- **Interactive Menu**: Dynamic menu system that auto-discovers available commands
- **Beautiful Output**: Styled output using gum (with fallback for basic terminals)

## Prerequisites

- **PostgreSQL client** (`psql`) installed and in your PATH
- **Bash 4.0+** (for associative arrays)
- **gum** (optional but recommended for enhanced UX)

### Installing gum

Run the included helper script:

```bash
./postgres/install-gum.sh
```

Or install manually:

```bash
# macOS
brew install gum

# Debian/Ubuntu
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
sudo apt update && sudo apt install gum

# Fedora/RHEL
echo '[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key' | sudo tee /etc/yum.repos.d/charm.repo
sudo yum install gum
```

## Quick Start

```bash
# First-time setup
cp postgres/config.env.example postgres/config.env
# Edit config.env with your PostgreSQL host/port

# Set admin password
export PGPASSWORD=your_admin_password

# Launch interactive menu
./postgres/pgctl

# Or use direct commands
./postgres/pgctl create-db myapp_production
./postgres/pgctl list-users myapp_production
```

## User Roles

pgctl creates 5 standardized users per database:

| Role                   | Permissions                          | Use Case                |
| ---------------------- | ------------------------------------ | ----------------------- |
| `{db}_owner`           | CREATEDB, CREATEROLE, ALL privileges | Database administration |
| `{db}_migration_user`  | CREATE, ALTER, DROP on objects       | Running migrations      |
| `{db}_fullaccess_user` | SELECT, INSERT, UPDATE, DELETE       | Full CRUD operations    |
| `{db}_app_user`        | SELECT, INSERT, UPDATE               | Application (no DELETE) |
| `{db}_readonly_user`   | SELECT only                          | Reporting, analytics    |

### Schema-Specific Users

For multi-tenant applications, pgctl creates schema-specific users:

```
{database}_{schema}_{role}

Example: myapp_production_tenant_acme_app_user
```

Schema users have **full isolation** - they can only access their specific schema.

## Commands

### Database Management

```bash
# Create database with all standard users
pgctl create-db [database_name]

# Delete database and associated users
pgctl delete-db [database_name]

# List all databases
pgctl list-databases
```

### Schema Management

```bash
# Create schema with schema-specific users
pgctl create-schema [database_name]

# Delete schema and associated users
pgctl delete-schema [database_name] [schema_name]

# List schemas in database
pgctl list-schemas [database_name]

# Grant existing user access to a schema
pgctl grant-schema-access
```

### User Management

```bash
# Interactive user creation wizard
pgctl create-user

# Change user password
pgctl change-password [username]

# Delete user
pgctl delete-user [username]

# List users
pgctl list-users [database_name]

# View/manage user permissions
pgctl view-user <username> [database_name]
```

### Permission Management

```bash
# Apply permissions to existing objects
pgctl grant-existing <database_name>

# Generate permission audit report
pgctl audit <database_name>
```

### Testing

pgctl includes a comprehensive test suite to verify functionality.

#### Basic Testing

```bash
# Run standard test suite (non-interactive, GUM disabled)
./test.sh

# Run with specific connection settings
./test.sh --host localhost --port 5432 --user postgres -P mypassword

# Keep test data for inspection
./test.sh --no-cleanup

# Show detailed output
./test.sh --verbose
```

#### GUM Interface Testing

The test suite includes special tests for the GUM (interactive UI) interface:

```bash
# Test with GUM interface enabled (requires gum installed)
./test.sh --test-gum

# Run all tests in both modes (GUM enabled and disabled)
./test.sh --test-all

# Interactive test runner with GUM
./tests/test-runner.sh --test-gum
```

**Why test GUM separately?**
- GUM runs commands in subshells that need special handling
- Default tests disable GUM to avoid interactive prompts
- `--test-gum` verifies no "command not found" errors occur
- Ensures parity between GUM and non-GUM code paths
- A prior bug (query functions not available in GUM's subshell, causing "command not found") was fixed by sourcing `common.sh` before running queries in `gum spin`

#### Test Options

```bash
# Connection options:
#   --host, -h      PostgreSQL host (default: localhost)
#   --port, -p      PostgreSQL port (default: 5432)
#   --user, -u      Admin username (default: postgres)
#   --password, -P  Admin password (default: from config.env)
#   --database, -d  Test database name (default: pgctl_test)

# Test behavior:
#   --no-cleanup    Keep test database after tests
#   --verbose, -v   Show detailed output
#   --test-gum      Enable GUM interface testing
#   --test-all      Run tests with both GUM modes
```

#### Using pgctl test Command

```bash
# Via pgctl (uses tests/test-runner.sh)
pgctl test --host localhost --port 5432 --user postgres
```

## Configuration

### Environment Variables

Set these before running pgctl commands:

```bash
# Required for commands that modify the database
export PGPASSWORD=admin_password

# Optional: Pre-set passwords for database creation
export DB_OWNER_PASSWORD=owner_pass
export DB_MIGRATION_PASSWORD=migration_pass
export DB_FULLACCESS_PASSWORD=fullaccess_pass
export DB_APP_PASSWORD=app_pass
export DB_READONLY_PASSWORD=readonly_pass

# Optional: Pre-set passwords for schema creation
export SCHEMA_OWNER_PASSWORD=schema_owner_pass
export SCHEMA_MIGRATION_PASSWORD=schema_migration_pass
# ... etc
```

### config.env

```bash
# Host and port configuration
PGHOST=localhost
PGPORT=5432
PGADMIN=postgres
```

## Interactive Mode

Running `pgctl` without arguments launches an interactive menu:

```
╔════════════════════════════════════╗
║    PostgreSQL Management (pgctl)   ║
╚════════════════════════════════════╝

Select an operation:

  DATABASE MANAGEMENT
  → Create Database
    Delete Database
    List Databases

  SCHEMA MANAGEMENT
    Create Schema
    Delete Schema
    List Schemas
    Grant Schema Access

  USER MANAGEMENT
    Create User
    Change Password
    Delete User
    List Users
    View User Permissions

  PERMISSION MANAGEMENT
    Grant Existing Objects
    Audit Permissions

  TESTING & UTILITIES
    Run Test Suite
    Help
    Exit
```

## Use Cases

### New Application Setup

```bash
# Create database with all users
./pgctl create-db myapp_production

# Use the generated credentials in your application:
# - myapp_production_migration_user for migrations
# - myapp_production_app_user for the application
# - myapp_production_readonly_user for read replicas
```

### Multi-Tenant Architecture

```bash
# Create database
./pgctl create-db saas_platform

# Create schema per tenant
./pgctl create-schema saas_platform  # Enter: tenant_acme
./pgctl create-schema saas_platform  # Enter: tenant_globex

# Each tenant gets isolated users:
# saas_platform_tenant_acme_app_user
# saas_platform_tenant_globex_app_user
```

### Microservices (Schema per Service)

```bash
# Create shared database
./pgctl create-db microservices

# Create schema per service
./pgctl create-schema microservices  # Enter: auth_service
./pgctl create-schema microservices  # Enter: billing_service
./pgctl create-schema microservices  # Enter: inventory_service

# Each service uses its own isolated users
```

### Custom User with Specific Permissions

```bash
# Launch user creation wizard
./pgctl create-user

# Follow prompts:
# 1. Enter username
# 2. Select role type or "custom"
# 3. For custom: select specific permissions
# 4. Choose to apply to future objects (recommended)
# 5. Select target database(s)
# 6. Enter password
```

### Permission Auditing

```bash
# Generate audit report
./pgctl audit myapp_production

# Output shows:
# - Users and their permission levels
# - Table counts per user
# - Object ownership summary
```

## Default Privileges

By default, all standard users are configured with `ALTER DEFAULT PRIVILEGES` so that:

1. New tables automatically inherit correct permissions
2. New sequences automatically inherit correct permissions
3. New functions automatically inherit correct permissions

This ensures your application continues working after schema migrations without manual permission grants.

For custom users, the wizard asks:

- **Existing objects only**: Grant on current objects
- **Future objects only**: Set up default privileges
- **Both** (default): Grant on current AND set default privileges

## Troubleshooting

### Connection Issues

```bash
# Test connection
PGPASSWORD=your_password psql -h localhost -p 5432 -U postgres -c "SELECT 1;"

# Common issues:
# - Wrong password: Check PGPASSWORD environment variable
# - Connection refused: Verify PostgreSQL is running
# - Host not found: Check PGHOST in config.env
```

### Permission Errors

```bash
# If you get "permission denied" errors:
# 1. Verify you're using the correct user
# 2. Check if user has required permissions:
./pgctl view-user username database_name

# 3. Apply permissions to existing objects:
./pgctl grant-existing database_name
```

### Name Too Long

PostgreSQL limits identifier names to 63 characters. If you see a warning:

```bash
# Use shorter database/schema names
# Long: my_really_long_application_name_production
# Short: myapp_prod
```

### gum Not Installed

pgctl works without gum, but with reduced interactivity:

```bash
# Check if gum is available
command -v gum

# Install gum for better experience
./install-gum.sh
```

## Security Best Practices

1. **Never store passwords in config files**

   - Use environment variables: `export PGPASSWORD=...`
   - Or let pgctl prompt you securely

2. **Use least-privilege principle**

   - Applications should use `app_user` (no DELETE)
   - Migrations use `migration_user`
   - Direct database access uses `readonly_user`

3. **Rotate passwords regularly**

   ```bash
   ./pgctl change-password myapp_production_app_user
   ```

4. **Audit permissions periodically**

   ```bash
   ./pgctl audit myapp_production
   ```

5. **Use schema isolation for multi-tenancy**
   - Schema users cannot access other schemas
   - Prevents cross-tenant data access

## Project Structure

```
postgres/
├── pgctl                     # Main CLI entry point
├── test.sh                   # Non-interactive test runner
├── lib/
│   ├── common.sh            # Shared functions, gum wrappers
│   ├── database.sh          # Database operations
│   ├── schema.sh            # Schema operations
│   ├── users.sh             # User management
│   ├── permissions.sh       # Permission management
│   └── menu.sh              # Dynamic menu generation
├── tests/
│   ├── test-runner.sh       # Interactive test runner
│   ├── test-database.sh     # Database tests
│   ├── test-schema.sh       # Schema tests
│   ├── test-users.sh        # User tests
│   ├── test-permissions.sh  # Permission tests
│   ├── test-gum-interface.sh # GUM interface tests
│   └── test-multiselect.sh  # Multiselect tests
├── config.env.example       # Example configuration
├── install-gum.sh           # Gum installation helper
└── README.md                # This file
```

## Extending pgctl

### Adding a New Command

1. Create your function in the appropriate library file:

```bash
# In lib/myfeature.sh
my_new_command() {
    log_header "My New Command"
    # ... implementation
}
```

2. Register the command for the menu:

```bash
register_command "My New Command" "CATEGORY NAME" "my_new_command" \
    "Description of what this command does"
```

3. Add CLI routing in `pgctl`:

```bash
my-command)
    my_new_command $remaining_args
    ;;
```

4. The command automatically appears in the interactive menu!

### Customizing gum Styling

Edit the wrapper functions in `lib/common.sh`:

```bash
log_success() {
    local message="$1"
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        # Customize colors, borders, etc.
        gum style --foreground 10 --bold "✓ $message"
    else
        echo -e "${GREEN}✓${NC} $message"
    fi
}
```

## License

MIT License - See LICENSE file for details.
