#!/bin/bash
#
# arc-migrate.sh — Unified Objective-C ARC migration toolkit
#
# Usage:
#   ./arc-migrate.sh analyze     → Analyze project for non-ARC patterns
#   ./arc-migrate.sh update      → Enable/disable ARC flags in Xcode project
#   ./arc-migrate.sh restore     → Restore from most recent project backup
#
# Safe for iterative migration of large legacy Objective-C projects.
#

# ------------- CONFIG -------------
ARC_SAFE_LIST="arc_safe_files.txt"
NON_ARC_LIST="non_arc_files.txt"
REPORT_FILE="arc_analysis_report.txt"
PROJECT_FILE=$(find ../.. -name "*.xcodeproj" -type d -maxdepth 2 | head -n 1)/project.pbxproj
# ---------------------------------

set -e

# --- Utility ---
header() {
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔹 $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# --- 1️⃣ ANALYZE MODE ---
analyze() {
    header "Analyzing Objective-C files for non-ARC patterns"

    >"$REPORT_FILE"
    >"$ARC_SAFE_LIST"
    >"$NON_ARC_LIST"

    FILES=$(find ../.. -type f -name "*.m")

    for f in $FILES; do
        echo "Analyzing ${f}"
        set -x
        NON_ARC_LINES=$(grep -nE '(retain|release|autorelease|dealloc)\]' "$f" || true)
        if [ -n "$NON_ARC_LINES" ]; then
            echo "🚫 $f" >>"$REPORT_FILE"
            echo "$NON_ARC_LINES" >>"$REPORT_FILE"
            echo >>"$REPORT_FILE"
            echo "$f" >>"$NON_ARC_LIST"
        else
            echo "$f" >>"$ARC_SAFE_LIST"
        fi
        set +x
    done

    SAFE_COUNT=$(wc -l <"$ARC_SAFE_LIST" | tr -d ' ')
    NON_SAFE_COUNT=$(wc -l <"$NON_ARC_LIST" | tr -d ' ')

    echo
    echo "✅ ARC-ready files:   $SAFE_COUNT"
    echo "⚠️  Non-ARC files:     $NON_SAFE_COUNT"
    echo
    echo "🗂️  Reports saved:"
    echo "   - $REPORT_FILE"
    echo "   - $ARC_SAFE_LIST"
    echo "   - $NON_ARC_LIST"
}

# --- 2️⃣ UPDATE MODE ---
update() {
    header "Updating Xcode project ARC flags"

    if [ ! -f "$PROJECT_FILE" ]; then
        echo "❌ Could not find .xcodeproj in this directory."
        exit 1
    fi

    BACKUP_FILE="${PROJECT_FILE}.bak-$(date +%Y%m%d%H%M%S)"
    cp "$PROJECT_FILE" "$BACKUP_FILE"
    echo "🛟 Backup created: $BACKUP_FILE"
    echo

    update_flag() {
        local FILE="$1"
        local FLAG="$2"
        local ESCAPED_FILE
        ESCAPED_FILE=$(printf '%s\n' "$FILE" | sed 's/[.[\*^$/]/\\&/g')

        if grep -q "$ESCAPED_FILE" "$PROJECT_FILE"; then
            if grep -A3 "$ESCAPED_FILE" "$PROJECT_FILE" | grep -q "compilerFlags"; then
                sed -i '' "/$ESCAPED_FILE/,/;/{s/compilerFlags = \".*\";/compilerFlags = \"$FLAG\";/}" "$PROJECT_FILE"
                echo "🔁 Updated $FLAG → $FILE"
            else
                sed -i '' "/$ESCAPED_FILE/{
n
a\\
\t\t\tcompilerFlags = \"$FLAG\";
}" "$PROJECT_FILE"
                echo "✅ Added $FLAG → $FILE"
            fi
        else
            echo "⚠️  Not found in project: $FILE"
        fi
    }

    if [ -f "$ARC_SAFE_LIST" ]; then
        echo "✅ Enabling ARC (-fobjc-arc) for safe files"
        while read -r FILE; do
            [ -n "$FILE" ] && update_flag "$FILE" "-fobjc-arc"
        done <"$ARC_SAFE_LIST"
        echo
    fi

    if [ -f "$NON_ARC_LIST" ]; then
        echo "🚫 Disabling ARC (-fno-objc-arc) for legacy files"
        while read -r FILE; do
            [ -n "$FILE" ] && update_flag "$FILE" "-fno-objc-arc"
        done <"$NON_ARC_LIST"
        echo
    fi

    echo "✅ Done. Reopen Xcode to refresh build settings."
}

# --- 3️⃣ RESTORE MODE ---
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
    echo "✅ Restored from: $LATEST_BACKUP"
    echo "📄 Original saved as: ${PROJECT_FILE}.restore-bak-$TIMESTAMP"
}

# --- MAIN ENTRY POINT ---
case "$1" in
    analyze)
        analyze
        ;;
    update)
        update
        ;;
    restore)
        restore
        ;;
    *)
        echo "Usage: $0 {analyze|update|restore}"
        exit 1
        ;;
esac
