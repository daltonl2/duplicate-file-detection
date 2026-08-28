#!/bin/bash

# Ask for the directory path
echo "Enter the directory path:"
read directory

# Check if the directory exists
if [[ ! -d "$directory" ]]; then
    echo "Directory does not exist."
    exit 1
fi

# Create or clear log files
log_file="duplicate_files.txt"
> "$log_file"

hash_index="index.txt"
> "$hash_index"

echo "Indexing files... (this may take a while on network drives)"

# Count files first so the terminal can show indexing progress.
file_count=$(find "$directory" -type f -not -path '*/.git/*' -print0 | tr -cd '\0' | wc -c)
processed_files=0

# Process each file in the directory
find "$directory" -type f -not -path '*/.git/*' -print0 |
while IFS= read -r -d $'\0' file; do
    size=$(stat -c%s "$file")
    hash=$(md5sum "$file" | awk '{print $1}')
    printf "%s\t%s\t%s\n" "$hash" "$size" "$file" >> "$hash_index"

    processed_files=$((processed_files + 1))
    if [[ "$file_count" -gt 0 ]]; then
        progress_percent=$((processed_files * 100 / file_count))
        printf '\rIndexing: %d/%d files (%d%%)' "$processed_files" "$file_count" "$progress_percent"
    fi
done

if [[ "$file_count" -eq 0 ]]; then
    printf '\rIndexing: 0/0 files (0%%)'
fi
printf '\n'

echo "Grouping and sorting duplicates..."

# Process index into groups and store file lists in tab-separated fields
awk -F'\t' '
{
    hash=$1
    size=$2
    file=$3

    # Unique key grouped by hash + size
    key = hash FS size

    # Track count
    count[key]++

    # Store files as tab-separated fields
    if (files[key] == "")
        files[key] = file
    else
        files[key] = files[key] FS file
}

END {
    # Output format: size TAB count TAB hash TAB file1 TAB file2 TAB ...
    for (k in count) {
        if (count[k] > 1) {
            split(k, parts, FS)
            hash=parts[1]
            size=parts[2]
            printf "%s\t%d\t%s\t%s\n", size, count[k], hash, files[k]
        }
    }
}
' "$hash_index" |

# Sort groups by size desc, then count desc
sort -t $'\t' -k1,1nr -k2,2nr |

# Pretty-print groups
awk -F'\t' '
{
    size=$1
    count=$2
    hash=$3

    print "Duplicate group:"
    print "  Hash: " hash
    print "  Size: " size " bytes"
    print "  Count: " count
    print "  Files:"

    # Print all files (fields 4..NF)
    for (i=4; i<=NF; i++) {
        print "    " $i
    }
    print ""
}
' >> "$log_file"

echo "Duplicate groups logged to $log_file"