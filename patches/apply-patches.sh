#!/bin/bash
# Apply patches to Klipper source code
# This script applies all patches in numbered order using git am

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KLIPPER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Applying patches to Klipper at: $KLIPPER_ROOT"

cd "$KLIPPER_ROOT"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Enable nullglob to handle empty directories gracefully
shopt -s nullglob

# Apply patches in order
patch_dirs=("$SCRIPT_DIR"/*/)
if [ ${#patch_dirs[@]} -eq 0 ]; then
    echo "No patch directories found"
    exit 0
fi

for patch_dir in "${patch_dirs[@]}"; do
    if [ ! -d "$patch_dir" ]; then
        continue
    fi
    
    patch_name=$(basename "$patch_dir")
    echo "Applying patch: $patch_name"
    
    # Apply all .patch files in the directory using git am
    patch_files=("$patch_dir"*.patch)
    if [ ${#patch_files[@]} -eq 0 ]; then
        echo "  No patch files found in $patch_name"
        continue
    fi
    
    for patch_file in "${patch_files[@]}"; do
        if [ ! -f "$patch_file" ]; then
            continue
        fi
        
        echo "  - $(basename "$patch_file")"
        # Use git am to apply the patch
        # --3way allows for better conflict resolution
        # --ignore-whitespace helps with whitespace differences
        if ! git am --3way --ignore-whitespace < "$patch_file"; then
            echo "Error: Failed to apply patch $(basename "$patch_file")"
            echo "You may need to resolve conflicts manually"
            exit 1
        fi
    done
done

echo "All patches applied successfully"
