# Shell Scripting Crash Course

A practical guide to bash scripting. Examples follow patterns used in this project.

---

## 1. Shebang and Basic Structure

```bash
#!/bin/bash

# Your script starts here
echo "Hello, world"
```

- **Shebang** `#!/bin/bash` — tells the OS to run the script with bash (use `#!/usr/bin/env bash` for portability).
- Make executable: `chmod +x script.sh`

---

## 2. Fail-Fast and Safety Options

```bash
set -e          # Exit immediately if a command fails (non-zero exit)
set -u          # Treat unset variables as an error
set -o pipefail # In a pipeline, fail if any command fails (not just the last)
```

Common at the top of scripts. `set -e` is used in pgctl.

---

## 3. Variables

### Assignment and Usage

```bash
NAME="value"           # No spaces around =
echo "$NAME"           # Always quote: "$NAME"
echo "${NAME}"         # Braces help when concatenating: "${NAME}_suffix"
```

**Rule:** Quote variables — `"$var"` — to avoid word-splitting and glob expansion.

### Defaults and “Unset or Empty”

```bash
# Use default if unset or empty
DIR="${HOME:-/tmp}"
PORT="${PGPORT:-5432}"

# Use default only if unset (empty is kept)
DIR="${HOME-/tmp}"

# Assign only if unset
: "${CONFIG_FILE:=config.env}"
```

### Export (Environment)

```bash
export PGHOST="localhost"
export PGCTL_ROOT="/path/to/pgctl"
```

---

## 4. Strings and Quoting

| Form        | Meaning                                      |
|------------|-----------------------------------------------|
| `"$var"`   | Variable expanded, spaces preserved           |
| `'$var'`   | Literal `$var`, no expansion                  |
| `` `cmd` ``| Command substitution (prefer `$(cmd)`)        |
| `$'...\n'` | C-style escapes: `$'line1\nline2'`            |

```bash
# Prefer $( ) for command substitution
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LINES="$(wc -l < file.txt)"
```

---

## 5. Conditionals

### `[[ ]]` vs `[ ]`

- Use **`[[ ]]`** in bash: better parsing, `==`, `=~`, `&&`, `||`.
- `[ ]` is the POSIX test; fine in `sh`, less featureful.

### Common Tests

```bash
# Strings
[[ -z "$var" ]]     # Empty or unset
[[ -n "$var" ]]     # Non-empty
[[ "$a" == "$b" ]]  # Equality
[[ "$a" != "$b" ]]  # Inequality
[[ "$a" =~ ^re ]]   # Regex (bash)

# Files
[[ -f "$path" ]]    # Regular file
[[ -d "$path" ]]    # Directory
[[ -e "$path" ]]    # Exists
[[ -r "$path" ]]    # Readable
[[ -x "$path" ]]    # Executable

# Numbers (also in [ ])
[[ $n -eq 0 ]]      # Equal
[[ $n -ne 0 ]]      # Not equal
[[ $n -gt 0 ]]      # Greater than
[[ $n -ge 0 ]]      # Greater or equal
[[ $n -lt 0 ]]      # Less than
[[ $n -le 0 ]]      # Less or equal
```

### If / Elif / Else

```bash
if [[ -z "$name" ]]; then
    echo "Name is required"
    exit 1
elif [[ ! -f "$config" ]]; then
    echo "Config not found"
    exit 1
else
    echo "OK"
fi
```

### Short-Circuit

```bash
[[ -n "${LOADED:-}" ]] && return   # "If LOADED set, return"
[[ -f "$file" ]] || touch "$file"  # "If file missing, create it"
```

---

## 6. Case (Pattern Matching)

Good for commands, flags, and one-of-many choices:

```bash
case "$1" in
    start)
        do_start
        ;;
    stop)
        do_stop
        ;;
    --help|-h)
        show_help
        ;;
    *)
        echo "Unknown: $1"
        exit 1
        ;;
esac
```

`;;` ends each branch. `*)` is the default. Use `;&` or `;;&` for fall-through if needed.

---

## 7. Loops

### For (list)

```bash
for item in a b c; do
    echo "$item"
done

for f in *.txt; do
    echo "$f"
done
```

### For (C-style, bash)

```bash
for (( i = 0; i < 10; i++ )); do
    echo "$i"
done
```

### While

```bash
while read -r line; do
    echo "$line"
done < file.txt

# Or from a command
psql -t -A -c "SELECT name FROM users" | while read -r name; do
    echo "User: $name"
done
```

### Until

```bash
until ping -c1 host &>/dev/null; do
    sleep 1
done
```

---

## 8. Functions

### Definition and Call

```bash
greet() {
    local name="${1:-World}"
    echo "Hello, $name"
}

greet
greet "Alice"
```

### Arguments

- `$1`, `$2`, … — positional args.
- `$#` — number of args.
- `$@` — all args as separate words (use in `"$@"`).
- `$*` — all args as one string (usually prefer `"$@"`).

```bash
process() {
    local first="$1"
    shift
    # Now $1 is what was $2, etc.
    for arg in "$@"; do
        echo "$arg"
    done
}
```

### Return and Exit

- `return N` — function exit code (0–255). Omit for 0.
- `exit N` — exit the whole script.

```bash
check_file() {
    [[ -f "$1" ]] && return 0 || return 1
}

if check_file "config.env"; then
    echo "Found"
fi
```

### Local Variables

```bash
run() {
    local dir="$1"
    local count=0
    # ...
}
```

Use `local` for variables that should not leak out of the function.

---

## 9. Argument Parsing (Manual)

### Shift-Based Option Loop

```bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--host)
            PGHOST="$2"
            shift 2
            ;;
        -p|--port)
            PGPORT="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Unknown: $1"
            exit 1
            ;;
    esac
done

# Remaining args are in $1, $2, ...
```

### Default Command

```bash
cmd="${1:-}"
shift 2>/dev/null || true
```

---

## 10. Sourcing and Libraries

Load another script into the current shell (no new process):

```bash
source "${PGCTL_ROOT}/lib/common.sh"
# or
. "${PGCTL_ROOT}/lib/common.sh"
```

**Idempotent sourcing:**

```bash
[[ -n "${PGCTL_COMMON_LOADED:-}" ]] && return
PGCTL_COMMON_LOADED=1
```

---

## 11. Paths and `dirname` / `BASH_SOURCE`

```bash
# Script’s directory (works with source)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve symlinks (simplified)
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ $SCRIPT_PATH != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
ROOT="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
```

Use `"${BASH_SOURCE[0]}"` in sourced files so the path stays correct.

---

## 12. Command Substitution and Subshells

```bash
# Capture output
out=$(command)
count=$(wc -l < file)

# In a string
echo "Files: $(ls | wc -l)"
```

`$( )` runs in a subshell; variable and `cd` changes there do not affect the parent.

---

## 13. Redirection

| Syntax        | Effect                          |
|---------------|---------------------------------|
| `> file`      | Stdout to file (overwrite)      |
| `>> file`     | Stdout to file (append)         |
| `2> file`     | Stderr to file                  |
| `&> file`     | Stdout and stderr to file       |
| `2>&1`        | Stderr to where stdout goes     |
| `< file`      | Stdin from file                 |
| `< <(cmd)`    | Stdin from process substitution |

```bash
psql ... > /dev/null 2>&1     # Silent
echo "msg" 2>/dev/null        # Hide stderr only
```

---

## 14. Arrays (Bash)

```bash
arr=(a b c)
arr+=(d e)

echo "${arr[0]}"
echo "${arr[@]}"       # All elements
echo "${#arr[@]}"      # Length

for x in "${arr[@]}"; do
    echo "$x"
done
```

---

## 15. Exit Codes

- `0` — success.
- Non-zero — failure; `1` is generic.

```bash
if command; then
    echo "OK"
else
    echo "Failed: $?"
    exit 1
fi
```

`$?` is the exit code of the last command.

---

## 16. Quick Reference: Common Patterns

```bash
# Optional (may be unset)
[[ -z "${VAR:-}" ]]

# Require a command
command -v grep &>/dev/null || { echo "Need grep"; exit 1; }

# Optional password from env
pass="${PGPASSWORD:-$(prompt_password "Password")}"

# Safely split on first ':'
"${line%%:*}"

# Trim / strip
"${var#"${var%%[![:space:]]*}"}"
```

---

## 17. Good Habits (Used in pgctl)

1. **Quote variables:** `"$var"`, `"$@"`.
2. **Use `[[ ]]`** for conditionals in bash.
3. **`local`** for function-local variables.
4. **`set -e`** (and optionally `-u`, `-o pipefail`) at the top.
5. **Default with `:-`:** `"${PGHOST:-localhost}"`.
6. **`$( )`** for command substitution, not backticks.
7. **Guard sourcing** with a `*_LOADED` flag.
8. **`BASH_SOURCE[0]`** for script path in sourced files.
9. **`case`** for commands and option dispatch.
10. **`return`** in functions, `exit` in the main script.

---

## 18. Debugging

```bash
# Print commands before running
set -x

# Turn off
set +x

# Line number in errors (bash)
trap 'echo "Error at line $LINENO"' ERR
```

---

## 19. Further Reading

- `man bash` — full manual.
- [ShellCheck](https://www.shellcheck.net/) — lint and fix common mistakes.
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) — style and best practices.
