#!/bin/bash
set -e

# optimize_golden.sh: Deterministically strip to_json data from large corpus files.
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

echo "Optimizing corpus (keeping first $RICH_LIMIT lines intact with 'to_json')..."

# 1. Capture the first RICH_LIMIT lines (full data)
head -n "$RICH_LIMIT" "$RAW_SOURCE" > "$DESTINATION"

# 2. Process the remaining lines: remove tests.to_json
tail -n +"$((RICH_LIMIT + 1))" "$RAW_SOURCE" | jq -c 'del(.tests.to_json)' >> "$DESTINATION"

echo "Success: Optimized corpus saved to $DESTINATION"
echo "New MD5: $(md5sum "$DESTINATION" | cut -d' ' -f1)"
