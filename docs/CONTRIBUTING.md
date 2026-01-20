# Contributing to pgctl

Thank you for your interest in contributing to pgctl! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Features](#suggesting-features)

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive environment for all contributors, regardless of experience level, background, or identity.

### Expected Behavior

- Be respectful and considerate
- Accept constructive criticism gracefully
- Focus on what's best for the project
- Show empathy towards other contributors

### Unacceptable Behavior

- Harassment, discrimination, or personal attacks
- Trolling or inflammatory comments
- Publishing others' private information
- Other conduct that could reasonably be considered inappropriate

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- Bash 4.0+ installed
- PostgreSQL client (psql) installed
- gum installed (recommended)
- Git for version control
- Access to a PostgreSQL server for testing

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/gushwork/pgctl.git
   cd gw-scripts/postgres
   ```
3. Add the upstream remote:
   ```bash
   git remote add upstream https://github.com/gushwork/pgctl.git
   ```

## Development Setup

1. **Run the setup script:**
   ```bash
   ./setup.sh
   ```

2. **Create configuration:**
   ```bash
   cp config.env.example config.env
   # Edit config.env with test database credentials
   ```

3. **Set up test environment:**
   ```bash
   export PGPASSWORD=your_test_admin_password
   export PGHOST=localhost
   export PGPORT=5432
   ```

4. **Run tests to verify setup:**
   ```bash
   ./pgctl test
   ```

## How to Contribute

### Types of Contributions

- **Bug fixes:** Fix issues in existing functionality
- **New features:** Add new commands or capabilities
- **Documentation:** Improve README, guides, or code comments
- **Tests:** Add or improve test coverage
- **Performance:** Optimize existing code
- **Refactoring:** Improve code structure without changing behavior

### Contribution Workflow

1. **Create a branch:**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/bug-description
   ```

2. **Make your changes:**
   - Write clean, readable code
   - Follow the coding standards below
   - Add tests for new features
   - Update documentation as needed

3. **Test your changes:**
   ```bash
   # Run the full test suite
   ./pgctl test
   
   # Test specific functionality manually
   ./pgctl your-new-command
   ```

4. **Commit your changes:**
   ```bash
   git add .
   git commit -m "feat: add new feature description"
   # or
   git commit -m "fix: resolve bug description"
   ```

5. **Push to your fork:**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Open a Pull Request**

## Coding Standards

### Bash Script Standards

#### File Structure

```bash
#!/bin/bash

# =============================================================================
# File Description
# =============================================================================
# Detailed description of what this file does
# =============================================================================

set -e  # Exit on error

# Constants (UPPERCASE)
readonly CONSTANT_NAME="value"

# Functions (lowercase with underscores)
function_name() {
    local param1="$1"
    local param2="$2"
    
    # Function implementation
}
```

#### Naming Conventions

- **Functions:** `lowercase_with_underscores`
- **Variables:** `lowercase_with_underscores`
- **Constants:** `UPPERCASE_WITH_UNDERSCORES`
- **Private functions:** Prefix with underscore `_private_function`
- **Command functions:** Prefix with `cmd_` for CLI commands

#### Best Practices

1. **Always quote variables:**
   ```bash
   # Good
   echo "$variable"
   local path="$1"
   
   # Bad
   echo $variable
   local path=$1
   ```

2. **Use local variables in functions:**
   ```bash
   # Good
   my_function() {
       local param="$1"
       local result="something"
   }
   
   # Bad
   my_function() {
       param="$1"
       result="something"
   }
   ```

3. **Check command existence:**
   ```bash
   if command -v psql &> /dev/null; then
       # Command exists
   fi
   ```

4. **Use meaningful error messages:**
   ```bash
   # Good
   log_error "Failed to connect to database at $PGHOST:$PGPORT"
   
   # Bad
   echo "Error"
   ```

5. **Add comments for complex logic:**
   ```bash
   # Calculate the default privileges for schema-specific users
   # This ensures new tables inherit the correct permissions
   local privileges="SELECT, INSERT, UPDATE"
   ```

### SQL Standards

1. **Use uppercase for SQL keywords:**
   ```sql
   SELECT * FROM users WHERE id = 1;
   ```

2. **Use parameterized queries when possible:**
   ```bash
   psql -c "SELECT * FROM users WHERE username = '$username';"
   ```

3. **Format multi-line SQL for readability:**
   ```sql
   SELECT u.username, r.role_name
   FROM users u
   JOIN roles r ON u.role_id = r.id
   WHERE u.active = true
   ORDER BY u.username;
   ```

### Logging Standards

Use the provided logging functions:

```bash
log_info "Informational message"
log_success "Success message"
log_warning "Warning message"
log_error "Error message"
log_header "Section Header"
```

### Gum Wrapper Usage

Always use the wrapper functions from `lib/common.sh`:

```bash
# Input
local username=$(gum_input "Enter username")

# Password
local password=$(gum_spin "Processing..." -- long_running_command)

# Confirmation
if gum_confirm "Delete this database?"; then
    # User confirmed
fi

# Selection
local choice=$(gum_choose "Option 1" "Option 2" "Option 3")
```

This ensures fallback behavior when gum is not available.

## Testing

### Running Tests

```bash
# Run full test suite
./pgctl test --host localhost --port 5432 --user postgres

# Run with custom test database
./pgctl test --database my_test_db

# Run specific test file (for development)
bash tests/test-database.sh
```

### Writing Tests

1. **Test file structure:**
   ```bash
   #!/bin/bash
   # tests/test-newfeature.sh
   
   test_feature_name() {
       # Arrange
       local test_db="test_db"
       
       # Act
       result=$(./pgctl some-command "$test_db")
       
       # Assert
       if [[ "$result" == "expected" ]]; then
           return 0
       else
           echo "Test failed: expected 'expected', got '$result'"
           return 1
       fi
   }
   ```

2. **Add tests for:**
   - New commands and features
   - Bug fixes (regression tests)
   - Edge cases and error conditions
   - Permission scenarios

3. **Test naming:**
   - Prefix with `test_`
   - Use descriptive names: `test_create_schema_with_special_characters`

4. **Cleanup:**
   - Always clean up test resources
   - Use unique test database names
   - Drop test databases after testing

### Test Guidelines

- Tests should be idempotent (can run multiple times)
- Tests should not depend on each other
- Tests should clean up after themselves
- Tests should have clear failure messages

## Pull Request Process

### Before Submitting

- [ ] Code follows the style guidelines
- [ ] All tests pass
- [ ] Documentation is updated
- [ ] Commit messages are clear and descriptive
- [ ] Branch is up to date with main/master

### PR Description Template

```markdown
## Description
Brief description of the changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Refactoring

## Testing
- [ ] Existing tests pass
- [ ] New tests added (if applicable)
- [ ] Manually tested

## Screenshots (if applicable)
Add screenshots for UI changes

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No breaking changes (or documented)
```

### Review Process

1. A maintainer will review your PR
2. Address any requested changes
3. Once approved, your PR will be merged
4. Your contribution will be acknowledged in release notes

### Commit Message Format

Use conventional commits format:

```
<type>: <description>

[optional body]

[optional footer]
```

**Types:**
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `test:` Adding or updating tests
- `refactor:` Code refactoring
- `perf:` Performance improvements
- `chore:` Maintenance tasks

**Examples:**
```
feat: add audit command for permission reporting

fix: resolve password prompt issue on Linux

docs: update installation instructions for Alpine

test: add schema deletion tests
```

## Reporting Bugs

### Before Reporting

1. Check if the bug has already been reported
2. Verify you're using the latest version
3. Test with a clean environment

### Bug Report Template

```markdown
## Bug Description
A clear description of the bug

## Steps to Reproduce
1. Run command '...'
2. Enter input '...'
3. See error

## Expected Behavior
What should have happened

## Actual Behavior
What actually happened

## Environment
- OS: [e.g., macOS 14.0, Ubuntu 22.04]
- Shell: [e.g., bash 5.1, zsh 5.8]
- PostgreSQL version: [e.g., 14.5]
- pgctl version/commit: [e.g., abc123]
- gum installed: [yes/no]

## Additional Context
Any other relevant information
```

## Suggesting Features

### Feature Request Template

```markdown
## Feature Description
Clear description of the proposed feature

## Use Case
Why is this feature needed? What problem does it solve?

## Proposed Solution
How should this feature work?

## Alternatives Considered
Other ways to achieve the same goal

## Additional Context
Any other relevant information
```

### Feature Discussion

- Open an issue to discuss the feature first
- Get feedback from maintainers before implementing
- Consider backward compatibility
- Think about edge cases and error handling

## Adding New Commands

### Command Template

```bash
# In appropriate lib/*.sh file

cmd_your_command() {
    local arg1="${1:-}"
    
    # Validate arguments
    if [[ -z "$arg1" ]]; then
        arg1=$(prompt_input "Enter value")
    fi
    
    log_header "Your Command"
    
    # Implementation
    log_info "Processing..."
    
    # Success
    log_success "Command completed successfully"
}

# Register for menu (at end of file)
register_command "Your Command" "CATEGORY" "cmd_your_command" \
    "Description of what this command does"
```

### Adding to pgctl Router

```bash
# In pgctl main file

case "$command" in
    your-command)
        cmd_your_command $remaining_args
        ;;
esac
```

## Documentation

### Documentation Standards

- Keep README.md updated with new features
- Add examples for new commands
- Update SETUP_GUIDE.md if setup changes
- Comment complex logic in code
- Use clear, concise language

### Documentation Checklist

- [ ] Command added to README
- [ ] Usage examples provided
- [ ] Edge cases documented
- [ ] Error messages explained
- [ ] Security implications noted (if any)

## Questions?

If you have questions about contributing:

1. Check existing documentation
2. Search closed issues for similar questions
3. Open a new issue with the "question" label
4. Be specific and provide context

## Recognition

Contributors are recognized in:
- Release notes
- CONTRIBUTORS.md file (if created)
- Git history

Thank you for contributing to pgctl! 🎉
