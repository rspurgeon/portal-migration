#!/bin/bash

# Default base URL (can be overridden with -u)
BASE_URL="http://localhost:8001"

# Get command line arguments
while getopts ":u:" opt; do
  case $opt in
    u)
      BASE_URL="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))

# Function to fetch data from API
 fetch_data() {
  local url="${BASE_URL}${1}"
  echo "Fetching files from: $url" >&2
  curl -s "$url"
}

# Function to process the data
process_data() {
  local json_data=$1
  shift  # Shift the arguments so $1 is removed and $2 becomes $1
  
  # Extract 'next' value from JSON data
  next_link=$(echo "$json_data" | jq -r '.next // empty')
  
  # For each filter path passed as a positional argument
  for FILTER_PATH in "$@"; do
    # Extract and filter 'path' values from JSON data based on FILTER_PATH
    paths_to_save=$(echo "$json_data" | jq -c ".data[] | select(.path | startswith(\"$FILTER_PATH\"))")
    
    # If paths found, iterate and save contents to file
    echo "$paths_to_save" | jq -c -r '.path' | while read path; do
      # Get the contents for the file
      contents=$(echo "$paths_to_save" | jq -r "select(.path == \"$path\") | .contents")

      dl_path=".dl/kong/$path"

      # Create directory if it doesn't exist
      mkdir -p "$(dirname "$dl_path")"

      # Save contents to file
      echo "$contents" > "$dl_path"

      echo "Wrote file: $dl_path"
    done
  done
  
  # If 'next' value exists and is non-empty, recursively call process_data with new link
  if [ -n "$next_link" ]; then
    new_data=$(fetch_data "$next_link")
    process_data "$new_data" "$@"
  fi
}

# Check if filter paths are provided
if [ $# -eq 0 ]; then
  echo "Please provide at least one filter path."
  exit 1
fi

# Begin script execution
json_response=$(fetch_data "/files")
process_data "$json_response" "$@"

