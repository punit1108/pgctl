#!/bin/bash

# =============================================================================
# Dynamic Menu Library for pgctl
# =============================================================================
# Functions for generating and displaying interactive menus
# Compatible with bash 3.x (macOS default)
# =============================================================================

# Prevent multiple sourcing
[[ -n "${PGCTL_MENU_LOADED:-}" ]] && return
PGCTL_MENU_LOADED=1

# Source common library
_MENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_MENU_DIR}/common.sh"

# =============================================================================
# Menu Category Order
# =============================================================================

# Define the order of categories in the menu
MENU_CATEGORIES="DATABASE MANAGEMENT
SCHEMA MANAGEMENT
USER MANAGEMENT
PERMISSION MANAGEMENT
TESTING & UTILITIES"

# =============================================================================
# Menu Generation Functions
# =============================================================================

# Get all commands for a category
get_commands_for_category() {
    local target_category="$1"
    local i
    
    for i in "${!PGCTL_CMD_NAMES[@]}"; do
        if [[ "${PGCTL_CMD_CATS[$i]}" == "$target_category" ]]; then
            echo "${PGCTL_CMD_NAMES[$i]}"
        fi
    done | sort
}

# Check if a category has any registered commands
category_has_commands() {
    local target_category="$1"
    local i
    
    for i in "${!PGCTL_CMD_NAMES[@]}"; do
        if [[ "${PGCTL_CMD_CATS[$i]}" == "$target_category" ]]; then
            return 0
        fi
    done
    return 1
}

# Get list of categories that have commands
get_active_categories() {
    local category
    while IFS= read -r category; do
        [[ -z "$category" ]] && continue
        if category_has_commands "$category"; then
            echo "$category"
        fi
    done <<< "$MENU_CATEGORIES"
}

# =============================================================================
# Menu Display Functions
# =============================================================================

# Helper to generate command list for a category
_generate_command_menu() {
    local category="$1"
    get_commands_for_category "$category"
    echo "Back"
}

# Display a category sub-menu (one reusable function for all categories)
display_category_menu() {
    local category="$1"
    
    while true; do
        log_header "$category"
        echo ""
        
        local selection
        local gum_exit_code
        
        if [[ "$GUM_AVAILABLE" == "true" ]]; then
            selection=$(_generate_command_menu "$category" | gum choose --header "Select an operation:") && gum_exit_code=0 || gum_exit_code=$?
            # Exit on Ctrl+C (exit code 130 = 128 + SIGINT)
            if [[ $gum_exit_code -eq 130 ]]; then
                echo ""
                exit 130
            fi
        else
            echo "Select an operation:"
            echo ""
            
            local commands=()
            while IFS= read -r cmd; do
                [[ -n "$cmd" ]] && commands+=("$cmd")
            done < <(_generate_command_menu "$category")
            
            local i=1
            for cmd in "${commands[@]}"; do
                echo "  $i) $cmd"
                ((i++))
            done
            echo ""
            read -rp "Enter selection (1-${#commands[@]}): " sel_num
            
            if [[ "$sel_num" =~ ^[0-9]+$ ]] && (( sel_num >= 1 && sel_num <= ${#commands[@]} )); then
                selection="${commands[$((sel_num-1))]}"
            else
                selection=""
            fi
        fi
        
        echo ""
        
        # Handle empty selection
        if [[ -z "$selection" ]]; then
            continue
        fi
        
        # Handle Back
        if [[ "$selection" == "Back" ]]; then
            return 0
        fi
        
        # Execute the selected command
        execute_command "$selection"
        
        echo ""
        
        # After command execution, prompt to continue or go back
        if [[ "$GUM_AVAILABLE" == "true" ]]; then
            local confirm_exit_code
            gum confirm "Continue in $category?" && confirm_exit_code=0 || confirm_exit_code=$?
            # Exit on Ctrl+C
            if [[ $confirm_exit_code -eq 130 ]]; then
                echo ""
                exit 130
            fi
            # Return to parent menu if user said no
            if [[ $confirm_exit_code -ne 0 ]]; then
                return 0
            fi
        else
            read -rp "Press Enter to continue in $category (or 'b' to go back): " response
            if [[ "$response" == "b" ]]; then
                return 0
            fi
        fi
        
        clear 2>/dev/null || true
    done
}

# Helper to generate category list for menu
_generate_category_menu() {
    get_active_categories
    echo "Exit"
}

# Display the main interactive menu (category picker)
display_menu() {
    while true; do
        log_header "PostgreSQL Management (pgctl)"
        echo ""
        
        local selection
        local gum_exit_code
        
        if [[ "$GUM_AVAILABLE" == "true" ]]; then
            selection=$(_generate_category_menu | gum choose --header "Select a category:") && gum_exit_code=0 || gum_exit_code=$?
            # Exit on Ctrl+C (exit code 130 = 128 + SIGINT)
            if [[ $gum_exit_code -eq 130 ]]; then
                echo ""
                exit 130
            fi
        else
            echo "Select a category:"
            echo ""
            
            local categories=()
            while IFS= read -r cat; do
                [[ -n "$cat" ]] && categories+=("$cat")
            done < <(_generate_category_menu)
            
            local i=1
            for cat in "${categories[@]}"; do
                echo "  $i) $cat"
                ((i++))
            done
            echo ""
            read -rp "Enter selection (1-${#categories[@]}): " sel_num
            
            if [[ "$sel_num" =~ ^[0-9]+$ ]] && (( sel_num >= 1 && sel_num <= ${#categories[@]} )); then
                selection="${categories[$((sel_num-1))]}"
            else
                selection=""
            fi
        fi
        
        echo ""
        
        # Handle empty selection
        if [[ -z "$selection" ]]; then
            continue
        fi
        
        # Handle Exit
        if [[ "$selection" == "Exit" ]]; then
            log_info "Goodbye!"
            return 0
        fi
        
        # Display the category sub-menu
        display_category_menu "$selection"
        
        clear 2>/dev/null || true
    done
}

# Execute a command by its display name
execute_command() {
    local display_name="$1"
    local func_name
    func_name=$(get_command_function "$display_name")
    
    if [[ -z "$func_name" ]]; then
        log_error "Unknown command: $display_name"
        return 1
    fi
    
    # Check if function exists
    if ! declare -f "$func_name" > /dev/null 2>&1; then
        log_error "Function not found: $func_name"
        return 1
    fi
    
    # Execute the function
    "$func_name"
}

# =============================================================================
# Help Display
# =============================================================================

# Display help information
show_help() {
    log_header "pgctl - PostgreSQL Management Tool"
    
    echo ""
    echo "Usage: pgctl [command] [options]"
    echo ""
    echo "When run without arguments, displays an interactive menu."
    echo ""
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum style --foreground 12 "COMMANDS:"
    else
        echo -e "${BOLD}COMMANDS:${NC}"
    fi
    
    echo ""
    
    # DATABASE MANAGEMENT
    echo "  DATABASE MANAGEMENT"
    echo "    create-db [dbname]           Create database with 5 standard users"
    echo "    delete-db [dbname]           Delete database and associated users"
    echo "    list-databases               List all databases"
    echo ""
    
    # SCHEMA MANAGEMENT
    echo "  SCHEMA MANAGEMENT"
    echo "    create-schema [dbname]       Create schema with 5 schema-specific users"
    echo "    delete-schema [db] [schema]  Delete schema and associated users"
    echo "    list-schemas [dbname]        List schemas in database"
    echo "    grant-schema-access          Grant user access to a schema"
    echo "    add-schema-users [db] [s]    Add 5 standard users to existing schema"
    echo ""
    
    # USER MANAGEMENT
    echo "  USER MANAGEMENT"
    echo "    create-user                  Interactive user creation wizard"
    echo "    change-password [username]   Change user password"
    echo "    delete-user [username]       Delete user"
    echo "    list-users [dbname]          List database users"
    echo "    list-schema-users [db] [s]   List schema-specific users"
    echo "    view-user <user> [dbname]    View/manage user permissions"
    echo ""
    
    # PERMISSION MANAGEMENT
    echo "  PERMISSION MANAGEMENT"
    echo "    grant-existing <dbname>      Apply permissions to existing objects"
    echo "    audit <dbname>               Generate permission audit report"
    echo ""
    
    # TESTING & UTILITIES
    echo "  TESTING & UTILITIES"
    echo "    test [options]               Run test suite"
    echo "    interactive                  Launch interactive menu"
    echo "    help                         Show this help message"
    echo "    version                      Show version information"
    echo ""
    
    echo "OPTIONS:"
    echo "    --host, -h        PostgreSQL host (default: localhost)"
    echo "    --port, -p        PostgreSQL port (default: 5432)"
    echo "    --user, -u        PostgreSQL admin user (default: postgres)"
    echo "    --password, -P    PostgreSQL password (prompts if not set)"
    echo ""
    
    echo "EXAMPLES:"
    echo "    pgctl                                # Interactive menu"
    echo "    pgctl create-db myapp_production     # Create database"
    echo "    pgctl create-schema                  # Create schema (interactive)"
    echo "    pgctl list-users myapp_production    # List users"
    echo "    pgctl test --host localhost          # Run tests"
    echo ""
    
    echo "For more information, see the README.md file."
}

# =============================================================================
# Register Commands
# =============================================================================

register_command "Help" "TESTING & UTILITIES" "show_help" \
    "Show help information"

register_command "Run Test Suite" "TESTING & UTILITIES" "cmd_run_tests" \
    "Run the test suite"
