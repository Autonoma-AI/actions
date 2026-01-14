#!/bin/bash
set -e

echo "🚀 Triggering test run..."

trigger_url=$1
test_id=$2
max_wait_minutes=$3
client_id=$4
client_secret=$5
application_versions_json=$6
run_type=$7

# Validate that run_type is provided
if [ -z "$run_type" ]; then
  echo "❌ Error: run_type parameter is required"
  exit 1
fi

if [ "$max_wait_minutes" -lt 10 ] || [ "$max_wait_minutes" -gt 20 ]; then
  echo "⚠️ max-wait-time must be between 10-20 minutes. Provided: ${max_wait_minutes}, using default time 10 minutes"
  max_wait_minutes=10
fi

echo "📋 Run type: $run_type"

# Build payload based on run type
if [ -n "$application_versions_json" ] && [ "$application_versions_json" != "[]" ]; then
  app_versions=$(echo "$application_versions_json" | jq -c '[.[] | {
    application_id: (."application-id"),
    application_version_ids: [(."version-id")]
  }]')
  
  case "$run_type" in
    "folder")
      # Folder runs use recursive flag
      data_payload=$(jq -n -c \
        --argjson app_versions "$app_versions" \
        '{
          source: "ci-cd",
          recursive: true,
          application_versions: $app_versions
        }')
      ;;
    "tag")
      # Tag runs don't use recursive flag
      data_payload=$(jq -n -c \
        --argjson app_versions "$app_versions" \
        '{
          source: "ci-cd",
          application_versions: $app_versions
        }')
      ;;
    "test")
      # Test runs use application_version_id (single version)
      version_id=$(echo "$application_versions_json" | jq -r '.[0]."version-id"')
      data_payload=$(jq -n -c \
        --arg version_id "$version_id" \
        '{
          source: "ci-cd",
          application_version_id: $version_id
        }')
      ;;
    *)
      echo "❌ Unknown run type: $run_type. Must be one of: folder, tag, test"
      exit 1
      ;;
  esac
else
  # If no application versions provided
  case "$run_type" in
    "tag")
      echo "❌ application_versions is required for tag runs"
      exit 1
      ;;
    "folder")
      # For folders, allow running without application versions (non-recursive)
      data_payload='{"source": "ci-cd"}'
      ;;
    "test")
      # For tests, allow running without application version (uses test's default)
      data_payload='{"source": "ci-cd"}'
      ;;
    *)
      echo "❌ Unknown run type: $run_type. Must be one of: folder, tag, test"
      exit 1
      ;;
  esac
fi

run_url="$trigger_url/$test_id/run"
echo "📡 Calling endpoint: $run_url"
echo "📦 Payload: $data_payload"

# Use Python to make the request
python3 << EOF
import urllib.request
import json
import sys

payload = '''$data_payload'''
url = "$run_url"
client_id = "$client_id"
client_secret = "$client_secret"

headers = {
    'Content-Type': 'application/json',
    'autonoma-client-id': client_id,
    'autonoma-client-secret': client_secret
}

try:
    req = urllib.request.Request(
        url,
        data=payload.encode('utf-8'),
        headers=headers,
        method='POST'
    )
    
    with urllib.request.urlopen(req, timeout=60) as response:
        response_body = response.read().decode('utf-8')
        status_code = response.status
        
        # Write response to file for bash to process
        with open('response_body.json', 'w') as f:
            f.write(response_body)
        
        # Write status code to file
        with open('/tmp/status_code.txt', 'w') as f:
            f.write(str(status_code))
            
        sys.exit(0)
        
except urllib.error.HTTPError as e:
    error_body = e.read().decode('utf-8')
    
    with open('response_body.json', 'w') as f:
        f.write(error_body)
    with open('/tmp/status_code.txt', 'w') as f:
        f.write(str(e.code))
    
    sys.exit(1)
    
except Exception as e:
    print(f"ERROR: {str(e)}")
    sys.exit(1)
EOF

# Check if Python script succeeded
python_exit_code=$?
http_code=$(cat /tmp/status_code.txt 2>/dev/null || echo "000")

if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
  echo "✅ Test run triggered successfully (HTTP $http_code)"
  
  if [ -f response_body.json ]; then
    cat response_body.json
    echo ""
    
    run_id=$(jq -r '.folderRunID // .folder_run_id // .run_id // empty' response_body.json 2>/dev/null || echo "")
    
    if [ -n "$run_id" ] && [ "$run_id" != "null" ]; then
      echo "run-id=$run_id" >> $GITHUB_OUTPUT
      echo "📋 Run ID: $run_id"
      
      url=$(jq -r '.url // empty' response_body.json 2>/dev/null || echo "")
      if [ -z "$url" ] || [ "$url" == "null" ]; then
        case "$run_type" in
          "tag")
            url="https://autonoma.app/run/tag/$run_id"
            ;;
          "folder")
            url="https://autonoma.app/run/folder/$run_id"
            ;;
          "test")
            url="https://autonoma.app/run/$run_id"
            ;;
        esac
      fi
      
      echo "url=$url" >> $GITHUB_OUTPUT
      echo "🔗 View results at: $url"
      
      message=$(jq -r '.message // empty' response_body.json 2>/dev/null || echo "Test run triggered successfully")
      echo "message=$message" >> $GITHUB_OUTPUT
    else
      echo "⚠️ Warning: Could not extract run ID from response"
      message=$(jq -r '.message // empty' response_body.json 2>/dev/null || echo "Test run triggered successfully")
      echo "message=$message" >> $GITHUB_OUTPUT
    fi
  fi
else
  echo "❌ Failed to trigger test run (HTTP $http_code)"
  if [ -f response_body.json ]; then
    echo "Response body:"
    cat response_body.json
  fi
  
  echo "message=Failed to trigger test run (HTTP $http_code)" >> $GITHUB_OUTPUT
  exit 1
fi

rm -f response_body.json
rm -f /tmp/status_code.txt
