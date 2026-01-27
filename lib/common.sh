#!/bin/bash

# =============================================================================
# Common Library for pgctl
# =============================================================================
# Shared functions: logging, validation, gum wrappers, database connection
# Compatible with bash 3.x (macOS default)
# =============================================================================

# Prevent multiple sourcing
[[ -n "${PGCTL_COMMON_LOADED:-}" ]] && return
PGCTL_COMMON_LOADED=1

# =============================================================================
# Configuration
# =============================================================================

# Get pgctl root directory (only set once)
if [[ -z "${PGCTL_ROOT:-}" ]]; then
    PGCTL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    export PGCTL_ROOT
fi

# Get lib directory
PGCTL_LIB_DIR="${PGCTL_ROOT}/lib"

# Load configuration
load_config() {
    local config_file="${PGCTL_ROOT}/config.env"
    if [[ -f "$config_file" ]]; then
        # shellcheck source=/dev/null
        source "$config_file"
    fi
    
    # Set defaults
    PGHOST="${PGHOST:-localhost}"
    PGPORT="${PGPORT:-5432}"
    PGADMIN="${PGADMIN:-postgres}"
    PGDATABASE="${PGDATABASE:-postgres}"
    PG_MAX_IDENTIFIER_LENGTH="${PG_MAX_IDENTIFIER_LENGTH:-63}"
    PG_TEST_DATABASE="${PG_TEST_DATABASE:-pgctl_test}"
    
    # Initialize SSL environment variables (used by execute_psql function)
    PGSSLMODE="${PGSSLMODE:-}"
    PGSSLROOTCERT="${PGSSLROOTCERT:-}"
    PGSSLCERT="${PGSSLCERT:-}"
    PGSSLKEY="${PGSSLKEY:-}"
    PGSSLCRL="${PGSSLCRL:-}"
}

# Initialize configuration
load_config

# =============================================================================
# Gum Detection and Fallback
# =============================================================================

# Check if gum is available
GUM_AVAILABLE=false
if command -v gum &> /dev/null; then
    GUM_AVAILABLE=true
fi

# =============================================================================
# Color Definitions (fallback when gum not available)
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# =============================================================================
# Logging Functions
# =============================================================================

log_info() {
    local message="$1"
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum style --foreground 12 "ℹ $message"
    else
        echo -e "${BLUE}ℹ${NC} $message"
    fi
}

log_success() {
    local message="$1"
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum style --foreground 10 "✓ $message"
    else
        echo -e "${GREEN}✓${NC} $message"
    fi
}

log_warning() {
    local message="$1"
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum style --foreground 11 "⚠ $message"
    else
        echo -e "${YELLOW}⚠${NC} $message"
    fi
}

log_error() {
    local message="$1"
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum style --foreground 9 "✗ $message"
    else
        echo -e "${RED}✗${NC} $message"
    fi
}

log_header() {
    local title="$1"
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum style --border double --padding "1 2" --border-foreground 12 "$title"
    else
        local width=${#title}
        local border=$(printf '═%.0s' $(seq 1 $((width + 4))))
        echo ""
        echo "╔${border}╗"
        echo "║  $title  ║"
        echo "╚${border}╝"
        echo ""
    fi
}

log_box() {
    local message="$1"
    local border_color="${2:-10}" # Default green
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum style --border rounded --padding "1 2" --border-foreground "$border_color" "$message"
    else
        echo ""
        echo "╭────────────────────────────────────────╮"
        echo "│ $message"
        echo "╰────────────────────────────────────────╯"
        echo ""
    fi
}

# =============================================================================
# Interactive Prompt Functions
# =============================================================================

prompt_input() {
    local prompt="$1"
    local default="${2:-}"
    local result
    local gum_exit_code
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        if [[ -n "$default" ]]; then
            result=$(gum input --placeholder "$prompt" --value "$default") && gum_exit_code=0 || gum_exit_code=$?
        else
            result=$(gum input --placeholder "$prompt") && gum_exit_code=0 || gum_exit_code=$?
        fi
        # Exit on Ctrl+C
        if [[ $gum_exit_code -eq 130 ]]; then
            echo ""
            exit 130
        fi
    else
        if [[ -n "$default" ]]; then
            read -rp "$prompt [$default]: " result
            result="${result:-$default}"
        else
            read -rp "$prompt: " result
        fi
    fi
    
    echo "$result"
}

prompt_password() {
    local prompt="$1"
    local result
    local gum_exit_code
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        result=$(gum input --password --placeholder "$prompt") && gum_exit_code=0 || gum_exit_code=$?
        # Exit on Ctrl+C
        if [[ $gum_exit_code -eq 130 ]]; then
            echo ""
            exit 130
        fi
    else
        read -rsp "$prompt: " result
        echo "" >&2  # New line after password input
    fi
    
    echo "$result"
}

prompt_confirm() {
    local prompt="$1"
    local default="${2:-n}"  # Default to 'n' (no)
    local gum_exit_code
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum confirm "$prompt" && gum_exit_code=0 || gum_exit_code=$?
        # Exit on Ctrl+C (exit code 130 = 128 + SIGINT)
        if [[ $gum_exit_code -eq 130 ]]; then
            echo ""
            exit 130
        fi
        # Return based on gum's exit code (0 = yes, 1 = no)
        return $gum_exit_code
    else
        local yn_prompt
        if [[ "$default" == "y" ]]; then
            yn_prompt="(Y/n)"
        else
            yn_prompt="(y/N)"
        fi
        
        read -rp "$prompt $yn_prompt: " -n 1 response
        echo ""
        
        case "$response" in
            [yY]) return 0 ;;
            [nN]) return 1 ;;
            "") 
                if [[ "$default" == "y" ]]; then
                    return 0
                else
                    return 1
                fi
                ;;
            *) return 1 ;;
        esac
    fi
}

prompt_select() {
    local prompt="$1"
    shift
    local options=("$@")
    local result
    local gum_exit_code
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        # Output options to gum, capture exit code for Ctrl+C handling
        result=$(printf '%s\n' "${options[@]}" | gum choose --header "$prompt") && gum_exit_code=0 || gum_exit_code=$?
        # Exit on Ctrl+C (exit code 130 = 128 + SIGINT)
        if [[ $gum_exit_code -eq 130 ]]; then
            echo ""
            exit 130
        fi
    else
        echo "$prompt:"
        local i=1
        for opt in "${options[@]}"; do
            echo "  $i) $opt"
            ((i++))
        done
        
        local selection
        read -rp "Enter selection (1-${#options[@]}): " selection
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#options[@]} )); then
            result="${options[$((selection-1))]}"
        else
            result=""
        fi
    fi
    
    echo "$result"
}

prompt_select_multiple() {
    local prompt="$1"
    shift
    local options=("$@")
    local result
    local gum_exit_code
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        # Output options to gum, capture exit code for Ctrl+C handling
        result=$(printf '%s\n' "${options[@]}" | gum choose --no-limit --header "$prompt") && gum_exit_code=0 || gum_exit_code=$?
        # Exit on Ctrl+C (exit code 130 = 128 + SIGINT)
        if [[ $gum_exit_code -eq 130 ]]; then
            echo ""
            exit 130
        fi
        
        # If empty, remind and retry once
        if [[ -z "$result" ]]; then
            log_warning "Please select at least one option."
            result=$(printf '%s\n' "${options[@]}" | gum choose --no-limit --header "$prompt") && gum_exit_code=0 || gum_exit_code=$?
            if [[ $gum_exit_code -eq 130 ]]; then
                echo ""
                exit 130
            fi
        fi
    else
        echo "$prompt (enter numbers separated by spaces, or 'all'):"
        local i=1
        for opt in "${options[@]}"; do
            echo "  $i) $opt"
            ((i++))
        done
        
        local selection
        read -rp "Enter selections: " selection
        
        if [[ "$selection" == "all" ]]; then
            result=$(printf '%s\n' "${options[@]}")
        else
            result=""
            for sel in $selection; do
                if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#options[@]} )); then
                    result+="${options[$((sel-1))]}"$'\n'
                fi
            done
        fi
        
        # If empty in non-GUM mode, remind and retry once
        if [[ -z "$result" ]]; then
            log_warning "Please select at least one option."
            read -rp "Enter selections: " selection
            
            if [[ "$selection" == "all" ]]; then
                result=$(printf '%s\n' "${options[@]}")
            else
                result=""
                for sel in $selection; do
                    if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#options[@]} )); then
                        result+="${options[$((sel-1))]}"$'\n'
                    fi
                done
            fi
        fi
    fi
    
    echo "$result"
}

# =============================================================================
# List RUD (Read/Update/Delete) Prompts Helper
# =============================================================================

# Global variables set by _list_rud_prompts
RUD_SELECTED=""
RUD_ACTION=""

# Shared helper for list+action flows
# Usage: _list_rud_prompts "names_newline" "select_prompt" action1 action2 ...
# Sets RUD_SELECTED (newline-separated) and RUD_ACTION
# Returns: 0 = action selected, 1 = empty selection, 2 = Back selected
_list_rud_prompts() {
    local names_newline="$1"
    local select_prompt="$2"
    shift 2
    local actions=("$@")
    
    # Reset globals
    RUD_SELECTED=""
    RUD_ACTION=""
    
    # Convert newline-separated names to array
    local names=()
    while IFS= read -r name; do
        [[ -n "$name" ]] && names+=("$name")
    done <<< "$names_newline"
    
    if [[ ${#names[@]} -eq 0 ]]; then
        return 1
    fi
    
    # Prompt for selection
    local selected
    selected=$(prompt_select_multiple "$select_prompt" "${names[@]}")
    
    if [[ -z "$selected" ]]; then
        return 1
    fi
    
    RUD_SELECTED="$selected"
    
    # Prompt for action
    local action
    action=$(prompt_select "Choose action:" "${actions[@]}")
    
    if [[ -z "$action" ]]; then
        return 1
    fi
    
    if [[ "$action" == "Back" ]]; then
        return 2
    fi
    
    RUD_ACTION="$action"
    return 0
}

# =============================================================================
# Progress Indicators
# =============================================================================

spin() {
    local title="$1"
    shift
    local command=("$@")
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "$title" -- "${command[@]}"
    else
        echo -n "$title... "
        if "${command[@]}" > /dev/null 2>&1; then
            echo "done"
            return 0
        else
            echo "failed"
            return 1
        fi
    fi
}

# =============================================================================
# Validation Functions
# =============================================================================

validate_identifier_length() {
    local name="$1"
    local max_length="${PG_MAX_IDENTIFIER_LENGTH:-63}"
    local name_length=${#name}
    
    if (( name_length > max_length )); then
        log_warning "Name '$name' exceeds PostgreSQL limit ($name_length > $max_length chars)"
        return 1
    fi
    return 0
}

validate_database_name() {
    local name="$1"
    
    # Check if empty
    if [[ -z "$name" ]]; then
        log_error "Database name cannot be empty"
        return 1
    fi
    
    # Check for valid characters (alphanumeric and underscore, must start with letter or underscore)
    if ! [[ "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        log_error "Invalid database name. Must start with letter/underscore and contain only alphanumeric/underscore"
        return 1
    fi
    
    # Check length
    validate_identifier_length "$name" || return 1
    
    return 0
}

validate_schema_name() {
    local name="$1"
    
    # Same rules as database name
    validate_database_name "$name"
}

validate_username() {
    local name="$1"
    
    # Same rules as database name
    validate_database_name "$name"
}

# Check if user name with all suffixes will be valid
validate_user_names_length() {
    local prefix="$1"  # e.g., "myapp_production" or "myapp_production_tenant_acme"
    
    # fullaccess_user is the longest at 15 chars, plus underscore = 16
    local full_name="${prefix}_fullaccess_user"
    local full_length=${#full_name}
    
    if (( full_length > PG_MAX_IDENTIFIER_LENGTH )); then
        log_warning "User names will exceed 63-char limit. Longest: '$full_name' ($full_length chars)"
        log_info "Please use a shorter database/schema name"
        return 1
    fi
    
    log_info "Name validation: ${full_name} = ${full_length} chars (OK)"
    return 0
}

# =============================================================================
# Password Management
# =============================================================================

# Generate a secure 16-character alphanumeric password
generate_password() {
    LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16
}

get_password() {
    local env_var="$1"
    local prompt="$2"
    local password
    
    # Check environment variable first
    password="${!env_var:-}"
    
    if [[ -z "$password" ]]; then
        # Prompt for password (allow empty for auto-generation)
        password=$(prompt_password "$prompt (leave empty to auto-generate)")
    fi
    
    # If still empty, generate a secure password
    if [[ -z "$password" ]]; then
        password=$(generate_password)
    fi
    
    echo "$password"
}

# =============================================================================
# Database Connection Functions
# =============================================================================

# Unified psql execution function that handles all connection parameters
# This function centralizes all PostgreSQL connection logic including SSL settings
execute_psql() {
    local sql="$1"
    local database="${2:-$PGDATABASE}"
    local mode="${3:-normal}"
    
    # Set environment variables for this execution
    local psql_env=(
        PGPASSWORD="${PGPASSWORD:-}"
    )
    
    # Add SSL environment variables if they are set
    [[ -n "${PGSSLMODE:-}" ]] && psql_env+=("PGSSLMODE=$PGSSLMODE")
    [[ -n "${PGSSLROOTCERT:-}" ]] && psql_env+=("PGSSLROOTCERT=$PGSSLROOTCERT")
    [[ -n "${PGSSLCERT:-}" ]] && psql_env+=("PGSSLCERT=$PGSSLCERT")
    [[ -n "${PGSSLKEY:-}" ]] && psql_env+=("PGSSLKEY=$PGSSLKEY")
    [[ -n "${PGSSLCRL:-}" ]] && psql_env+=("PGSSLCRL=$PGSSLCRL")
    
    # Execute based on mode - using env to pass variables avoids eval issues
    case "$mode" in
        quiet)
            env "${psql_env[@]}" psql -h "$PGHOST" -p "$PGPORT" -U "$PGADMIN" -d "$database" -c "$sql" > /dev/null 2>&1
            ;;
        file)
            env "${psql_env[@]}" psql -h "$PGHOST" -p "$PGPORT" -U "$PGADMIN" -d "$database" -f "$sql" 2>&1
            ;;
        *)
            # Normal mode - return output
            env "${psql_env[@]}" psql -h "$PGHOST" -p "$PGPORT" -U "$PGADMIN" -d "$database" -c "$sql" 2>&1
            ;;
    esac
}

# Execute SQL as admin
psql_admin() {
    local sql="$1"
    local database="${2:-$PGDATABASE}"
    
    execute_psql "$sql" "$database" "normal"
}

# Execute SQL as admin, return exit code only
psql_admin_quiet() {
    local sql="$1"
    local database="${2:-$PGDATABASE}"
    
    execute_psql "$sql" "$database" "quiet"
}

# Execute SQL file as admin
psql_admin_file() {
    local file="$1"
    local database="${2:-$PGDATABASE}"
    
    execute_psql "$file" "$database" "file"
}

# Check database connection
check_connection() {
    if psql_admin_quiet "SELECT 1;"; then
        return 0
    else
        log_error "Cannot connect to PostgreSQL at $PGHOST:$PGPORT"
        return 1
    fi
}

# Check if database exists
database_exists() {
    local dbname="$1"
    local result
    
    result=$(psql_admin "SELECT 1 FROM pg_database WHERE datname = '$dbname';" 2>/dev/null | grep -c "1 row")
    [[ "$result" == "1" ]]
}

# Check if schema exists
schema_exists() {
    local dbname="$1"
    local schema="$2"
    local result
    
    result=$(psql_admin "SELECT 1 FROM information_schema.schemata WHERE schema_name = '$schema';" "$dbname" 2>/dev/null | grep -c "1 row")
    [[ "$result" == "1" ]]
}

# Check if user/role exists
user_exists() {
    local username="$1"
    local result
    
    result=$(psql_admin "SELECT 1 FROM pg_roles WHERE rolname = '$username';" 2>/dev/null | grep -c "1 row")
    [[ "$result" == "1" ]]
}

# Get list of databases
list_databases_query() {
    psql_admin "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres' ORDER BY datname;" 2>/dev/null | \
        tail -n +3 | sed '$d' | sed '$d' | sed 's/^[ ]*//' | grep -v "^$"
}

# Get list of schemas in database
list_schemas_query() {
    local dbname="$1"
    psql_admin "SELECT nspname FROM pg_namespace WHERE nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast') AND nspname NOT LIKE 'pg_%' ORDER BY nspname;" "$dbname" 2>/dev/null | \
        tail -n +3 | sed '$d' | sed '$d' | sed 's/^[ ]*//' | grep -v "^$"
}

# Get list of users
list_users_query() {
    psql_admin "SELECT rolname FROM pg_roles WHERE rolcanlogin = true ORDER BY rolname;" 2>/dev/null | \
        tail -n +3 | sed '$d' | sed '$d' | sed 's/^[ ]*//' | grep -v "^$"
}

# Execute a list query with loading indicator
list_with_loading() {
    local query_type="$1"  # "databases", "schemas", "users"
    shift
    local query_func="$*"
    local result
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        # Source common.sh to make query functions available in subshell
        result=$(gum spin --spinner dot --title "Loading ${query_type}..." -- bash -c "source '${PGCTL_LIB_DIR}/common.sh'; $query_func")
    else
        echo -n "Loading ${query_type}... "
        result=$($query_func)
        echo "done"
    fi
    
    echo "$result"
}

# =============================================================================
# Credentials Display Functions
# =============================================================================

# Display credentials summary in a formatted table
# Usage: display_credentials "title" "header1|header2|..." "row1col1|row1col2|..." "row2col1|row2col2|..." ...
# Note: Uses pipe (|) as separator to avoid conflicts with commas in data values
display_credentials() {
    local title="$1"
    shift
    local header="$1"
    shift
    local rows=("$@")
    
    echo ""
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum style --border double --padding "1 2" --border-foreground 11 "⚠ $title - SAVE THESE SECURELY ⚠"
    else
        echo "============================================"
        echo "⚠ $title - SAVE THESE SECURELY ⚠"
        echo "============================================"
    fi
    echo ""
    
    # Always use plain text table for credentials (more reliable and readable)
    # Header
    IFS='|' read -ra header_cols <<< "$header"
    local col_widths=()
    
    # Calculate max width for each column
    for i in "${!header_cols[@]}"; do
        col_widths[$i]=${#header_cols[$i]}
    done
    
    for row in "${rows[@]}"; do
        IFS='|' read -ra row_cols <<< "$row"
        for i in "${!row_cols[@]}"; do
            local len=${#row_cols[$i]}
            if [[ $len -gt ${col_widths[$i]:-0} ]]; then
                col_widths[$i]=$len
            fi
        done
    done
    
    # Print header
    local separator_line=""
    for i in "${!header_cols[@]}"; do
        local width=${col_widths[$i]}
        printf "%-${width}s  " "${header_cols[$i]}"
        separator_line+=$(printf '%*s' "$width" "" | tr ' ' '-')
        separator_line+="  "
    done
    echo ""
    echo "$separator_line"
    
    # Print rows
    for row in "${rows[@]}"; do
        IFS='|' read -ra row_cols <<< "$row"
        for i in "${!row_cols[@]}"; do
            local width=${col_widths[$i]}
            printf "%-${width}s  " "${row_cols[$i]}"
        done
        echo ""
    done
    echo ""
}

# Display connection example
display_connection_example() {
    local host="${PGHOST:-localhost}"
    local port="${PGPORT:-5432}"
    local username="$1"
    local database="$2"
    
    echo "Connection Example:"
    echo "  psql -h $host -p $port -U $username -d $database"
    echo ""
}

# =============================================================================
# Command Registration System (bash 3.x compatible)
# =============================================================================

# Arrays to store registered commands
PGCTL_CMD_NAMES=()
PGCTL_CMD_FUNCS=()
PGCTL_CMD_CATS=()
PGCTL_CMD_DESCS=()

# Register a command for the dynamic menu
register_command() {
    local display_name="$1"
    local category="$2"
    local function_name="$3"
    local description="${4:-}"
    
    PGCTL_CMD_NAMES+=("$display_name")
    PGCTL_CMD_FUNCS+=("$function_name")
    PGCTL_CMD_CATS+=("$category")
    PGCTL_CMD_DESCS+=("$description")
}

# Get command function by display name
get_command_function() {
    local display_name="$1"
    local i
    
    for i in "${!PGCTL_CMD_NAMES[@]}"; do
        if [[ "${PGCTL_CMD_NAMES[$i]}" == "$display_name" ]]; then
            echo "${PGCTL_CMD_FUNCS[$i]}"
            return 0
        fi
    done
    echo ""
}

# Get command category by display name
get_command_category() {
    local display_name="$1"
    local i
    
    for i in "${!PGCTL_CMD_NAMES[@]}"; do
        if [[ "${PGCTL_CMD_NAMES[$i]}" == "$display_name" ]]; then
            echo "${PGCTL_CMD_CATS[$i]}"
            return 0
        fi
    done
    echo ""
}

# =============================================================================
# Utility Functions
# =============================================================================

# Get pgctl version
get_version() {
    echo "pgctl version 1.0.0"
}

# Display version
show_version() {
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum style --foreground 12 "$(get_version)"
    else
        echo "$(get_version)"
    fi
}
