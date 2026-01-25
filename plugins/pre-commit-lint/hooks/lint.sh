#!/bin/bash
# Pre-commit lint hook for Claude Code
# Runs appropriate linters based on staged files

set -e

EXIT_CODE=0
JS_FILES=()
PY_FILES=()
GO_FILES=()
RS_FILES=()
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

while IFS= read -r -d '' file; do
    case "$file" in
        *.js|*.jsx|*.ts|*.tsx) JS_FILES+=("$file") ;;
        *.py) PY_FILES+=("$file") ;;
        *.go) GO_FILES+=("$file") ;;
        *.rs) RS_FILES+=("$file") ;;
    esac
done < <(git diff --cached --name-only --diff-filter=ACM -z)

if [ ${#JS_FILES[@]} -eq 0 ] && [ ${#PY_FILES[@]} -eq 0 ] && [ ${#GO_FILES[@]} -eq 0 ] && [ ${#RS_FILES[@]} -eq 0 ]; then
    echo "No staged files to lint"
    exit 0
fi

# JavaScript/TypeScript
if [ ${#JS_FILES[@]} -ne 0 ]; then
    echo "Linting JavaScript/TypeScript files..."
    if command -v eslint &> /dev/null; then
        eslint "${JS_FILES[@]}" || EXIT_CODE=1
    elif command -v biome &> /dev/null; then
        biome check "${JS_FILES[@]}" || EXIT_CODE=1
    fi
fi

# Python
if [ ${#PY_FILES[@]} -ne 0 ]; then
    echo "Linting Python files..."
    if command -v ruff &> /dev/null; then
        ruff check "${PY_FILES[@]}" || EXIT_CODE=1
    elif command -v flake8 &> /dev/null; then
        flake8 "${PY_FILES[@]}" || EXIT_CODE=1
    fi
fi

# Go
if [ ${#GO_FILES[@]} -ne 0 ]; then
    echo "Linting Go files..."
    declare -A GO_DIRS_SET=()
    for file in "${GO_FILES[@]}"; do
        dir=$(dirname "$file")
        GO_DIRS_SET["$dir"]=1
    done
    GO_DIRS=()
    for dir in "${!GO_DIRS_SET[@]}"; do
        if [ "$dir" = "." ]; then
            GO_DIRS+=(".")
        elif [[ "$dir" == ./* ]]; then
            GO_DIRS+=("$dir")
        else
            GO_DIRS+=("./$dir")
        fi
    done
    if [ ${#GO_DIRS[@]} -ne 0 ]; then
        mapfile -t GO_DIRS < <(printf '%s\n' "${GO_DIRS[@]}" | sort -u)
    fi
    if command -v golangci-lint &> /dev/null; then
        golangci-lint run "${GO_DIRS[@]}" || EXIT_CODE=1
    elif command -v go &> /dev/null; then
        go vet "${GO_DIRS[@]}" || EXIT_CODE=1
    fi
fi

# Rust
if [ ${#RS_FILES[@]} -ne 0 ]; then
    echo "Linting Rust files..."
    if command -v cargo &> /dev/null; then
        declare -A MANIFESTS_SET=()
        for file in "${RS_FILES[@]}"; do
            dir=$(dirname "$file")
            while [ "$dir" != "/" ] && [ "$dir" != "." ]; do
                if [ -f "$dir/Cargo.toml" ]; then
                    MANIFESTS_SET["$dir/Cargo.toml"]=1
                    break
                fi
                if [ "$REPO_ROOT" != "/" ]; then
                    abs_dir=$(cd "$dir" 2>/dev/null && pwd || echo "")
                    if [ -n "$abs_dir" ] && [ "$abs_dir" = "$REPO_ROOT" ]; then
                        break
                    fi
                fi
                dir=$(dirname "$dir")
            done
            if [ -f "Cargo.toml" ]; then
                MANIFESTS_SET["Cargo.toml"]=1
            fi
        done
        if [ ${#MANIFESTS_SET[@]} -eq 0 ]; then
            echo "No Cargo.toml found for staged Rust files"
            EXIT_CODE=1
        else
            mapfile -t MANIFESTS < <(printf '%s\n' "${!MANIFESTS_SET[@]}" | sort -u)
            for manifest in "${MANIFESTS[@]}"; do
                cargo clippy --manifest-path "$manifest" -- -D warnings || EXIT_CODE=1
            done
        fi
    fi
fi

if [ $EXIT_CODE -ne 0 ]; then
    echo '{"decision": "block", "reason": "Linting failed. Please fix the issues before committing."}'
    exit 2
fi

echo "All linting checks passed!"
exit 0
