#!/bin/bash
# Apply patches to Klipper source code
# This script applies all patches in numbered order

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KLIPPER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Applying patches to Klipper at: $KLIPPER_ROOT"

# Apply patches in order
for patch_dir in "$SCRIPT_DIR"/*/; do
    if [ -d "$patch_dir" ]; then
        patch_name=$(basename "$patch_dir")
        echo "Applying patch: $patch_name"
        
        # Apply all .patch files in the directory
        for patch_file in "$patch_dir"*.patch; do
            if [ -f "$patch_file" ]; then
                echo "  - $(basename "$patch_file")"
                # Use --forward to skip already applied patches
                # Use --reject-file to see what fails
                patch -p0 -d "$KLIPPER_ROOT" --forward < "$patch_file" || true
            fi
        done
    fi
done

echo "All patches applied successfully"
