#!/bin/bash
#
# Add puzzle images to the iOS asset catalog.
#
# Usage:
#   ./scripts/add-images.sh photo1.jpg photo2.png ~/Downloads/cat.jpeg ...
#
# Accepts any image format (jpg, jpeg, png, heic, webp, etc.)
# Images are copied into the asset catalog with proper .imageset structure.
# The app handles center-cropping to 4:3 at runtime — no pre-processing needed.
#
# The script auto-detects the next available animal_N index.

set -e

ASSETS_DIR="ios/KaleysPuzzle/Assets.xcassets/user-uploaded-pictures"

# Ensure we're in the repo root
if [ ! -d "$ASSETS_DIR" ]; then
    echo "Error: Run this script from the puzzle-app repo root."
    echo "  cd /path/to/puzzle-app && ./scripts/add-images.sh ..."
    exit 1
fi

if [ $# -eq 0 ]; then
    echo "Usage: ./scripts/add-images.sh <image1|folder1> [image2|folder2] ..."
    echo ""
    echo "Accepts: jpg, jpeg, png, heic, webp, gif, bmp, tiff"
    echo "Pass individual files or a folder containing images."
    echo "Images are added to the iOS asset catalog automatically."
    exit 1
fi

# Expand arguments: if a directory is passed, collect all image files from it
expanded_args=()
for arg in "$@"; do
    if [ -d "$arg" ]; then
        while IFS= read -r -d '' file; do
            expanded_args+=("$file")
        done < <(find "$arg" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.tif" \) -print0 | sort -z)
        if [ ${#expanded_args[@]} -eq 0 ]; then
            echo "⚠️  No image files found in directory: $arg"
        fi
    else
        expanded_args+=("$arg")
    fi
done

if [ ${#expanded_args[@]} -eq 0 ]; then
    echo "No image files to add."
    exit 1
fi

# Find the next available index
next_index=1
while [ -d "$ASSETS_DIR/animal_${next_index}.imageset" ]; do
    next_index=$((next_index + 1))
done

added=0

for img_path in "${expanded_args[@]}"; do
    # Validate file exists
    if [ ! -f "$img_path" ]; then
        echo "⚠️  Skipping (not found): $img_path"
        continue
    fi

    # Get filename and extension
    filename=$(basename "$img_path")
    extension="${filename##*.}"
    extension_lower=$(echo "$extension" | tr '[:upper:]' '[:lower:]')

    # Validate it's an image
    case "$extension_lower" in
        jpg|jpeg|png|heic|webp|gif|bmp|tiff|tif)
            ;;
        *)
            echo "⚠️  Skipping (unsupported format .$extension_lower): $img_path"
            continue
            ;;
    esac

    # Normalize extension for the asset catalog
    case "$extension_lower" in
        jpeg) extension_lower="jpg" ;;
        tif) extension_lower="tiff" ;;
    esac

    # Create imageset directory
    imageset_dir="$ASSETS_DIR/animal_${next_index}.imageset"
    mkdir -p "$imageset_dir"

    # Copy image with standardized name
    dest_filename="animal_${next_index}.${extension_lower}"
    cp "$img_path" "$imageset_dir/$dest_filename"

    # Create Contents.json
    cat > "$imageset_dir/Contents.json" << EOF
{
  "images" : [
    {
      "filename" : "$dest_filename",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

    echo "✅  Added: animal_${next_index} ← $filename"
    next_index=$((next_index + 1))
    added=$((added + 1))
done

echo ""
echo "Done! Added $added image(s). Total images now: $((next_index - 1))"
echo "No code changes needed — the app auto-detects new images."
