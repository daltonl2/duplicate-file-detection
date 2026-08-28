#!/bin/bash

# Ask for the directory path
echo "Enter the directory path:"

read directory

# Check if the directory exists
if [[ ! -d "$directory" ]]; then
    echo "Directory does not exist."
    exit 1
fi

# Create or clear the log file
log_file="duplicate_files.txt"

> "$log_file"

# Temporary file to store hashes and filenames
hash_index="index.txt"

> "$hash_index"

echo "Indexing files... (this may take a while on network drives)"

# Count files first so the terminal can show indexing progress.
file_count=$(find "$directory" -type f -not -path '*/.git/*' -print0 | tr -cd '\0' | wc -c)
processed_files=0

# Process each file in the directory
find "$directory" -type f -not -path '*/.git/*' -print0 |
while IFS= read -r -d $'\0' file; do

    # Generate SHA-256 hash for the file
    hash=$(sha256sum "$file" | awk '{print $1}')

    # Append in index file: "hash filepath"
    printf "%s\t%s\n" "$hash" "$file" >> "$hash_index"

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

echo "Scanning for Duplicates..."

# create copy of sorted index
sort "$hash_index" > index_sorted.txt

# Sort and group by hash; find duplicates
echo "Sorting Index ..."

sort "$hash_index" | awk -F '\t' '
{
    hash = $1
    file = $2
    if (hash == last_hash) {
        count++
        files[count] = file
    } else {
        if (count > 1) {
            print "Duplicate group for hash " last_hash ":"
            for (i = 1; i <= count; i++) {
                print "  " files[i]
            }
            print ""
        }
        # reset group
        delete files
        count = 1
        files[count] = file
    }
    last_hash = hash
}

END {
    # process the final group

    if (count > 1) {
        print "Duplicate group for hash " last_hash ":"
        for (i = 1; i <= count; i++) {
            print "  " files[i]
        }
    }
}

' | tee -a "$log_file"

echo "Duplicate file names have been logged to $log_file"