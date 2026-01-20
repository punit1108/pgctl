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

# Generate menu items array for gum choose
generate_menu_array() {
    local category
    
    while IFS= read -r category; do
        [[ -z "$category" ]] && continue
        
        local has_items=false
        local i
        for i in "${!PGCTL_CMD_NAMES[@]}"; do
            if [[ "${PGCTL_CMD_CATS[$i]}" == "$category" ]]; then
                has_items=true
                break
            fi
        done
        
        if [[ "$has_items" == "true" ]]; then
            get_commands_for_category "$category"
        fi
    done <<< "$MENU_CATEGORIES"
    
    echo "Exit"
}

# =============================================================================
# Menu Display Functions
# =============================================================================

# Display the main interactive menu
display_menu() {
    while true; do
        log_header "PostgreSQL Management (pgctl)"
        
        echo ""
        
        local selection
        
        if [[ "$GUM_AVAILABLE" == "true" ]]; then
            # Generate menu with category headers
            selection=$(generate_menu_array | gum choose --header "Select an operation:")
        else
            # Fallback menu display
            echo "Select an operation:"
            echo ""
            
            local i=1
            local category
            local menu_items=()
            
            while IFS= read -r category; do
                [[ -z "$category" ]] && continue
                
                local has_items=false
                local idx
                for idx in "${!PGCTL_CMD_NAMES[@]}"; do
                    if [[ "${PGCTL_CMD_CATS[$idx]}" == "$category" ]]; then
                        has_items=true
                        break
                    fi
                done
                
                if [[ "$has_items" == "true" ]]; then
                    echo -e "\n  ${BOLD}$category${NC}"
                    while IFS= read -r cmd; do
                        [[ -z "$cmd" ]] && continue
                        echo "    $i) $cmd"
                        menu_items+=("$cmd")
                        ((i++))
                    done < <(get_commands_for_category "$category")
                fi
            done <<< "$MENU_CATEGORIES"
            
            echo ""
            echo "    $i) Exit"
            menu_items+=("Exit")
            
            echo ""
            read -rp "Enter selection (1-$i): " sel_num
            
            if [[ "$sel_num" =~ ^[0-9]+$ ]] && (( sel_num >= 1 && sel_num <= i )); then
                selection="${menu_items[$((sel_num-1))]}"
            else
                selection=""
            fi
        fi
        
        echo ""
        
        # Handle selection
        if [[ -z "$selection" ]]; then
            continue
        fi
        
        if [[ "$selection" == "Exit" ]]; then
            log_info "Goodbye!"
            return 0
        fi
        
        # Execute the selected command
        execute_command "$selection"
        
        echo ""
        
        # Wait for user to acknowledge before showing menu again
        if [[ "$GUM_AVAILABLE" == "true" ]]; then
            if gum confirm "Return to main menu?"; then
                continue
            else
                return 0
            fi
        else
            read -rp "Press Enter to return to main menu (or 'q' to quit): " response
            if [[ "$response" == "q" ]]; then
                return 0
            fi
        fi
        
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
