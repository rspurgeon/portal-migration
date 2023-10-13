#!/bin/bash

if [ ! -z "$DEBUG" ]; then
    set -x  # enable debugging
fi

print() {
    echo "$@" >&2
}

show_help() {
    print "Usage: $0 -d <directory> -u <url> -t <token>"
    print 
    print "   -d   Directory to read OpenAPI spec files from"
    print "   -u   URL for the API to POST requests to"
    print "   -t   Personal Access Token for authorization"
    exit 1
}

check_product_exists() {
    local product_name="$1"
    local escaped_product_name=$(printf "%s" "$product_name" | jq -sRr @uri)
    local url="${URL}/v2/api-products?filter\[name\]=$escaped_product_name"
    local response=$(curl -s -H "Authorization: Bearer ${TOKEN}" -XGET "$url")
    echo "$response" | jq -r ".data[0].id // empty"
}

check_version_exists() {
    local product_id="$1"
    local version_name="$2"
    local url="${URL}/v2/api-products/$product_id/product-versions?filter\[name\]=$version_name"
    local response=$(curl -s -H "Authorization: Bearer ${TOKEN}" -XGET "$url")
    echo "$response" | jq -r ".data[0].id // empty"
}

manage_product_version() {
    local product_id="$1"
    local version_name="$2"
    
    local existing_version_id=$(check_version_exists "$product_id" "$version_name")
    
    if [ -z "$existing_version_id" ]; then
        curl -s -o /dev/null --request POST \
            --url "${URL}/v2/api-products/$product_id/product-versions" \
            --header 'Content-Type: application/json' \
            --header 'accept: application/json' \
            --header "Authorization: Bearer ${TOKEN}" \
            --data "{\"name\":\"$version_name\"}"
        print "Created new product version: $version_name for product ID: $product_id"
        existing_version_id=$(check_version_exists "$product_id" "$version_name")
    else
        # Implement any PATCH operation here if needed
        print "Version $version_name already exists for product ID: $product_id"
    fi
    echo "$existing_version_id"
}

check_specification_exists() {
    local product_id="$1"
    local version_id="$2"
    local url="${URL}/v2/api-products/${product_id}/product-versions/${version_id}/specifications"
    local response=$(curl -s -H "Authorization: Bearer ${TOKEN}" -XGET "$url")
    echo "$response" | jq -r ".data[0].id // empty"
}

update_or_create_specification() {
    local product_id="$1"
    local version_id="$2"
    local file_content_base64=$(cat "$file" | base64)

    local existing_specification_id=$(check_specification_exists "$product_id" "$version_id")

    if [ ! -z "$existing_specification_id" ]; then
        print "Updating existing specification for API Product Version ${version_id}"
        local url="${URL}/v2/api-products/${product_id}/product-versions/${version_id}/specifications/${existing_specification_id}"
        curl -s -o /dev/null --request PATCH \
            --url "$url" \
            --header 'Content-Type: application/json' \
            --header 'accept: application/json' \
            --header "Authorization: Bearer ${TOKEN}" \
            --data "{\"content\":\"${file_content_base64}\"}"
    else
        print "Creating new specification for API Product Version ${version_id}"
        local url="${URL}/v2/api-products/${product_id}/product-versions/${version_id}/specifications"
        curl -s -o /dev/null --request POST \
            --url "$url" \
            --header 'Content-Type: application/json' \
            --header 'accept: application/json' \
            --header "Authorization: Bearer ${TOKEN}" \
            --data "{\"name\":\"${file}\",\"content\":\"${file_content_base64}\"}"
    fi
}

manage_api_product() {
    local payload="$1"
    local product_name=$(echo "$payload" | jq -r ".name")
    local product_version="$2"
    local existing_product_id=$(check_product_exists "$product_name")

    if [ ! -z "$existing_product_id" ]; then
        local url="${URL}/v2/api-products/$existing_product_id"
        curl -s -o /dev/null --request PATCH \
            --url "$url" \
            --header 'Content-Type: application/json' \
            --header 'accept: application/json' \
            --header "Authorization: Bearer ${TOKEN}" \
            --data "$payload"
        print "Patched existing API Product ${existing_product_id} (${product_name})"
    else
        print "Creating new API Product (${product_name})"
        response=$(curl -s \
            -X POST \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json" \
            -d "$payload" \
            "${URL}/v2/api-products")
        existing_product_id=$(echo "$response" | jq -r ".id")
        print "Created new API Product with ID: $existing_product_id"
    fi
    
    product_version_id=$(manage_product_version "$existing_product_id" "$product_version")
    update_or_create_specification "$existing_product_id" "$product_version_id"
}

while getopts "hd:u:t:" opt; do
    case "$opt" in
    h)
        show_help
        ;;
    d)
        DIRECTORY=$OPTARG
        ;;
    u)
        URL=$OPTARG
        ;;
    t)
        TOKEN=$OPTARG
        ;;
    *)
        show_help
        ;;
    esac
done

if [ -z "$DIRECTORY" ] || [ -z "$URL" ] || [ -z "$TOKEN" ]; then
    show_help
fi

shopt -s nullglob

for file in "$DIRECTORY"/*.{json,yaml,yml}; do
    if [[ "$file" == *.json ]]; then
        title=$(jq -r '.info.title' "$file")
        description=$(jq -r '.info.description //empty' "$file")
        contactName=$(jq -r '.info.contact.name //empty' "$file")
        contactEmail=$(jq -r '.info.contact.email //empty' "$file")
        licenseName=$(jq -r '.info.license.name //empty' "$file")
        version=$(jq -r '.info.version //empty' "$file")
    else
        title=$(yq e '.info.title' "$file")
        description=$(yq e '.info.description' "$file")
        contactName=$(yq e '.info.contact.name' "$file")
        contactEmail=$(yq e '.info.contact.email' "$file")
        licenseName=$(yq e '.info.license.name' "$file")
        version=$(yq e '.info.version' "$file")

        # Handling possible null values for YAML
        [ "$description" == "null" ] && description=""
        [ "$contactName" == "null" ] && contactName=""
        [ "$contactEmail" == "null" ] && contactEmail=""
        [ "$licenseName" == "null" ] && licenseName=""
        [ "$version" == "null" ] && version=""        
    fi

    if [ "$title" != "null" ] && [ ! -z "$title" ]; then
        print "Processing $file - Title: $title"

        # Start with the base JSON
        json_payload="{\"name\":\"$title\""
        
        # Add optional fields without trailing commas
        [ ! -z "$description" ] && json_payload+=",\"description\":\"$description\""
        
        # Prepare the labels part of the JSON
        labels_payload="{"
        [ ! -z "$contactName" ] && {
            contactName=$(echo "$contactName" | sed 's/ /_/g')
            labels_payload+="\"contactName\":\"$contactName\","
        }
        [ ! -z "$contactEmail" ] && {
            contactEmail=$(echo "$contactEmail" | sed 's/@/_/g')
            labels_payload+="\"contactEmail\":\"$contactEmail\","
        }
        [ ! -z "$licenseName" ] && {
            licenseName=$(echo "$licenseName" | sed 's/ /_/g')
            labels_payload+="\"license\":\"$licenseName\","
        }
        # Remove any trailing comma from the labels_payload
        labels_payload=${labels_payload%,}
        labels_payload+="}"
        
        # Merge the base json_payload and the labels_payload using jq
        json_payload=$(echo "$json_payload,\"labels\":$labels_payload}" | jq -c '.')

        manage_api_product "$json_payload" "$version"

    else
        print "No title found in $file"
    fi
    echo "---------------------------------------------------"

done

shopt -u nullglob
set +x;
