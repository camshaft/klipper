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

# Apply patches in order
for patch_dir in "$SCRIPT_DIR"/*/; do
    if [ -d "$patch_dir" ]; then
        patch_name=$(basename "$patch_dir")
        echo "Applying patch: $patch_name"
        
        # Apply all .patch files in the directory using git am
        for patch_file in "$patch_dir"*.patch; do
            if [ -f "$patch_file" ]; then
                echo "  - $(basename "$patch_file")"
                # Use git am to apply the patch
                # --3way allows for better conflict resolution
                # --ignore-whitespace helps with whitespace differences
                if ! git am --3way --ignore-whitespace < "$patch_file"; then
                    echo "Error: Failed to apply patch $(basename "$patch_file")"
                    echo "You may need to resolve conflicts manually"
                    exit 1
                fi
            fi
        done
    fi
done

echo "All patches applied successfully"
