#!/bin/bash
set -e

# optimize_golden.sh: Deterministically strip to_json data from large corpus files.
# Extracts only necessary fields for global fuzzing.
# Usage: ./scripts/optimize_golden.sh [-f <limit>] <source_file> <destination_file>

RICH_LIMIT=128

usage() {
    echo "Usage: $0 [-f <limit>] <source_file> <destination_file>"
    echo "  -f <limit>  Number of lines at the start to keep with full 'to_json' data (default: 128)"
    exit 1
}

while getopts "f:h" opt; do
    case "$opt" in
        f) RICH_LIMIT=$OPTARG ;;
        h) usage ;;
        *) usage ;;
    esac
done

shift $((OPTIND-1))

if [ "$#" -ne 2 ]; then
    usage
fi

SOURCE="$1"
DESTINATION="$2"

# Check for dependencies
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is required but not installed."
    exit 1
fi

# Create a temporary directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

RAW_SOURCE="$TEMP_DIR/raw_source.jsonl"

# Decompress if necessary
if [[ "$SOURCE" == *.gz ]]; then
    echo "Decompressing $SOURCE..."
    zcat "$SOURCE" > "$RAW_SOURCE"
else
    cp "$SOURCE" "$RAW_SOURCE"
fi

echo "Optimizing corpus..."
echo "  -> Keeping first $RICH_LIMIT lines intact with full 'to_json'"
echo "  -> Extracting vendor data to 'tests.fuzz' for all lines"

# Transformation: 
# 1. Add .tests.fuzz from .tests.to_json.vendor
# 2. If line number > RICH_LIMIT, delete .tests.to_json
# 3. Always delete to_json from the output to save space? No, keep RICH_LIMIT as requested.

jq -c "
  .tests.fuzz = .tests.to_json.vendor | 
  if (input_line_number > $RICH_LIMIT) then del(.tests.to_json) else . end
" "$RAW_SOURCE" > "$DESTINATION"

echo "Success: Optimized corpus saved to $DESTINATION"
echo "New MD5: $(md5sum "$DESTINATION" | cut -d' ' -f1)"
