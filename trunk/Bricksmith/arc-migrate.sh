#!/bin/bash
#
# arc-migrate.sh — Robust Objective-C ARC migration toolkit
# Modes: analyze | update | restore
#
# bundle install # (prior to running, if needed)

ARC_SAFE_LIST="arc_safe_files.txt"
NON_ARC_LIST="non_arc_files.txt"
REPORT_FILE="arc_analysis_report.txt"
PROJECT_FILE=$(find . -name "*.xcodeproj" -type d -maxdepth 2 | head -n 1)/project.pbxproj

set -e

header() {
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔹 $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# -------- ANALYZE --------
analyze() {
    header "Analyzing Objective-C files for non-ARC patterns"

    >"$REPORT_FILE"
    >"$ARC_SAFE_LIST"
    >"$NON_ARC_LIST"

    FILE_COUNTS_TMP=$(mktemp)
    TMP_DIR=$(mktemp -d)

    FILES=$(find . -type f -name "*.m")

    for f in $FILES; do

        if [ -f "ignored.txt" ]; then
            if grep -q -x -F "$f" "ignored.txt"; then
            continue
            fi
        fi


        TMP_FILE="$TMP_DIR/$(echo "$f" | sed 's|/|_|g')"

        # Use awk to process file in one pass
        awk '
            # Skip full-line comments
            /^\s*\/\// { next }

            # Skip dealloc method declarations
            /^\s*[-+]\s*\(.*\)\s*dealloc(\s*\{)?/ { next }

            # Match non-ARC keywords
            /retain|release|autorelease|NSAutoreleasePool|\[super dealloc\]/ {
                print
            }
        ' "$f" > "$TMP_FILE"

        LINE_COUNT=$(wc -l < "$TMP_FILE" | tr -d ' ')

        if [ "$LINE_COUNT" -eq 0 ]; then
            echo "$f" >>"$ARC_SAFE_LIST"
        else
            echo -e "$LINE_COUNT\t$f" >>"$FILE_COUNTS_TMP"
            echo "$f" >>"$NON_ARC_LIST"
        fi
    done

    # Sort non-ARC files by line count ascending
    sort -n "$FILE_COUNTS_TMP" > sorted_non_arc_files.txt

    # Generate report
    {
        echo "Non-ARC Files Ordered by Number of Non-ARC Lines"
        echo "-----------------------------------------------"
        while read -r LINE; do
            COUNT=$(echo "$LINE" | awk '{print $1}')
            FILE=$(echo "$LINE" | awk '{$1=""; print $0}' | sed 's/^[[:space:]]*//')
            echo
            printf "%-6s  %s\n" "$COUNT" "$FILE"
            echo "------  ----"
            TMP_FILE="$TMP_DIR/$(echo "$FILE" | sed 's|/|_|g')"
            if [ -f "$TMP_FILE" ]; then
                sed 's/^/        /' "$TMP_FILE"
            fi
        done < sorted_non_arc_files.txt
    } >"$REPORT_FILE"

    rm -f "$FILE_COUNTS_TMP"
    rm -rf "$TMP_DIR"

    SAFE_COUNT=$(wc -l <"$ARC_SAFE_LIST" | tr -d ' ')
    NON_SAFE_COUNT=$(wc -l <"$NON_ARC_LIST" | tr -d ' ')

    echo
    echo "✅ ARC-ready files:   $SAFE_COUNT"
    echo "⚠️  Non-ARC files:     $NON_SAFE_COUNT"
    echo
    echo "🗂️  Report saved: $REPORT_FILE (sorted by line count with non-ARC lines)"
    echo "🗂️  ARC-safe files: $ARC_SAFE_LIST"
    echo "🗂️  Non-ARC files: $NON_ARC_LIST"
}

# -------- UPDATE --------
update() {
    header "Updating Xcode project ARC flags using xcodeproj"

    # Ensure Ruby environment
    if ! bundle exec ruby -v >/dev/null 2>&1; then
        echo "❌ Bundle environment not set up. Run 'bundle install' first."
        exit 1
    fi

    # Run the Ruby script
    bundle exec ruby update_arc_flags.rb
}


# -------- RESTORE --------
restore() {
    header "Restoring most recent project backup"

    if [ ! -f "$PROJECT_FILE" ]; then
        echo "❌ No project.pbxproj found."
        exit 1
    fi

    PROJECT_DIR=$(dirname "$PROJECT_FILE")
    BACKUPS=( "$PROJECT_DIR"/project.pbxproj.bak-* )

    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo "❌ No project backups found."
        exit 1
    fi

    LATEST_BACKUP=$(ls -1t "${PROJECT_DIR}"/project.pbxproj.bak-* | head -n 1)

    echo "🛟 Latest backup: $LATEST_BACKUP"
    read -p "⚠️  Restore this backup? Overwrite current .pbxproj? [y/N]: " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "❎ Cancelled."
        exit 0
    fi

    TIMESTAMP=$(date +%Y%m%d%H%M%S)
    cp "$PROJECT_FILE" "${PROJECT_FILE}.restore-bak-$TIMESTAMP"
    cp "$LATEST_BACKUP" "$PROJECT_FILE"

    echo
    echo "✅ Project restored from: $LATEST_BACKUP"
    echo "📄 Original saved as: ${PROJECT_FILE}.restore-bak-$TIMESTAMP"
}

# -------- MAIN --------
case "$1" in
    analyze) analyze ;;
    update) update ;;
    restore) restore ;;
    *) echo "Usage: $0 {analyze|update|restore}"; exit 1 ;;
esac
