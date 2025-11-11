#!/bin/bash
#
# incremental-arc-migrate-cleanup.sh
# Incrementally enables ARC on Objective-C files in order of
# increasing non-ARC line count. Prompts user per file.
# When confirmed, also removes manual retain/release/autorelease/dealloc lines.
# Skipped files are recorded in arc_skip_list.txt.
#

PROJECT_FILE=$(find ../.. -name "*.xcodeproj" -type d -maxdepth 2 | head -n 1)/project.pbxproj
SKIP_FILE="arc_skip_list.txt"
TMP_FILE=$(mktemp)

if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ Could not find .xcodeproj in current directory."
    exit 1
fi

# Ensure skip file exists
touch "$SKIP_FILE"

# 1️⃣ Build list of files with non-ARC line counts
echo "🔍 Scanning Objective-C files for non-ARC lines..."
find ../.. -type f -name "*.m" | while read -r FILE; do
    count=$(grep -E 'retain|release|autorelease|\[super[[:space:]]+dealloc\]' "$FILE" | grep -vE '^\s*//' | wc -l | tr -d ' ')
    echo -e "$count\t$FILE"
done > "$TMP_FILE"

# 2️⃣ Filter out skipped files and sort ascending
FILES_TO_PROCESS=$(grep -vFf "$SKIP_FILE" "$TMP_FILE" | sort -n | awk '{print $2}')

if [ -z "$FILES_TO_PROCESS" ]; then
    echo "✅ No files left to process."
    rm -f "$TMP_FILE"
    exit 0
fi

# 3️⃣ Backup project and source files
BACKUP_DIR="arc_migration_backup_$(date +%Y%m%d%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp "$PROJECT_FILE" "$BACKUP_DIR"
echo "🛟 Backup created: $BACKUP_DIR"

for f in $FILES_TO_PROCESS; do
    cp "$f" "$BACKUP_DIR"
done

# 4️⃣ Process files interactively
for FILE in $FILES_TO_PROCESS; do
    LINE_COUNT=$(grep -E 'retain|release|autorelease|\[super[[:space:]]+dealloc\]' "$FILE" | grep -vE '^\s*//' | wc -l | tr -d ' ')
    echo
    echo "File: $FILE"
    echo "Non-ARC lines: $LINE_COUNT"
    read -p "Enable ARC and remove manual memory management for this file? [y/N]: " CONFIRM

    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        ESCAPED_FILE=$(printf '%s\n' "$FILE" | sed 's/[.[\*^$/]/\\&/g')

        # Enable ARC in project
        if grep -q "$ESCAPED_FILE" "$PROJECT_FILE"; then
            if ! grep -A3 "$ESCAPED_FILE" "$PROJECT_FILE" | grep -q "compilerFlags"; then
                sed -i '' "/$ESCAPED_FILE/{
n
a\\
\t\t\tcompilerFlags = \"-fobjc-arc\";
}" "$PROJECT_FILE"
                echo "✅ ARC enabled in project for $FILE"
            else
                echo "⚙️  Already has compilerFlags for $FILE"
            fi
        else
            echo "⚠️  File not found in project: $FILE"
        fi

        # Remove manual retain/release/autorelease/[super dealloc] lines
        sed -i '' -E '/\b(retain|release|autorelease)\b|^\s*\[super[[:space:]]+dealloc\]/d' "$FILE"
        echo "🧹 Removed non-ARC lines from $FILE"

    else
        echo "$FILE" >> "$SKIP_FILE"
        echo "⏭ Skipped $FILE (recorded in $SKIP_FILE)"
    fi
done

rm -f "$TMP_FILE"

echo
echo "✅ Incremental ARC migration & cleanup complete."
echo "💡 Backups of project and original files are in: $BACKUP_DIR"
echo "💡 Reopen Xcode to refresh build settings."
