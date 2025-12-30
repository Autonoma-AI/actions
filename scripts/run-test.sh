#!/bin/bash
set -e

echo "🚀 Triggering test run..."
echo "DEBUG: Bash version: $BASH_VERSION"
echo "DEBUG: Shell: $SHELL"
echo "DEBUG: Current user: $(whoami)"
echo "DEBUG: Working directory: $(pwd)"

trigger_url=$1
test_id=$2
max_wait_minutes=$3
client_id=$4
client_secret=$5
application_versions_json=$6

echo "DEBUG: application_versions_json received: '$application_versions_json'"
echo "DEBUG: application_versions_json length: ${#application_versions_json}"
echo "DEBUG: trigger_url: $trigger_url"
echo "DEBUG: test_id: $test_id"

if [ "$max_wait_minutes" -lt 10 ] || [ "$max_wait_minutes" -gt 20 ]; then
  echo "⚠️ max-wait-time must be between 10-20 minutes. Provided: ${max_wait_minutes}, using default time 10 minutes"
  max_wait_minutes=10
fi

if [ -n "$application_versions_json" ] && [ "$application_versions_json" != "[]" ]; then
  echo "DEBUG: Processing application versions..."
  
  app_versions=$(echo "$application_versions_json" | jq -c '[.[] | {
    application_id: (."application-id"),
    application_version_ids: [(."version-id")]
  }]')
  
  echo "DEBUG: app_versions after jq transform: $app_versions"
  
  data_payload=$(jq -n -c \
    --argjson app_versions "$app_versions" \
    '{
      source: "ci-cd",
      recursive: true,
      application_versions: $app_versions
    }')
  
  echo "DEBUG: data_payload with app_versions (compact): $data_payload"
else
  echo "DEBUG: No application versions provided, using default payload"
  data_payload='{"source": "ci-cd"}'
fi

echo "DEBUG: Final data_payload length: ${#data_payload}"
echo "DEBUG: Final data_payload content: $data_payload"

# Write payload to file for inspection
echo "$data_payload" > /tmp/payload.json
echo "DEBUG: Payload written to /tmp/payload.json"
echo "DEBUG: File size: $(wc -c < /tmp/payload.json) bytes"
echo "DEBUG: File contents:"
cat /tmp/payload.json
echo ""

# Calculate expected Content-Length
expected_content_length=$(echo -n "$data_payload" | wc -c)
echo "DEBUG: Expected Content-Length: $expected_content_length bytes"

run_url="$trigger_url/$test_id/run"
echo "📡 Calling endpoint: $run_url"
echo "📦 Payload: $data_payload"

# Show curl version
echo "DEBUG: Curl version:"
curl --version | head -n 1

# Actual request with verbose stderr capture
echo "DEBUG: Sending actual request with curl..."
response=$(curl -s -w "%{http_code}" -v \
  -X POST \
  -H "autonoma-client-id: $client_id" \
  -H "autonoma-client-secret: $client_secret" \
  -H "Content-Type: application/json" \
  --data-raw "$data_payload" \
  --connect-timeout 60 \
  --max-time 60 \
  "$run_url" \
  -o response_body.json 2>&1 | tee /tmp/curl_output.txt)

http_code="${response: -3}"

# Extract and display request headers from verbose output
echo "DEBUG: Curl verbose output - Request headers:"
grep -E "^> (POST|Host|Content-Type|Content-Length|autonoma-)" /tmp/curl_output.txt || echo "Could not extract request headers"

echo "DEBUG: HTTP response code: $http_code"
echo "DEBUG: Response body file size: $(wc -c < response_body.json 2>/dev/null || echo 0) bytes"

if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
  echo "✅ Test run triggered successfully (HTTP $http_code)"
  
  if [ -f response_body.json ]; then
    echo "DEBUG: Response body content:"
    cat response_body.json
    echo ""
    
    run_id=$(jq -r '.folderRunID // .folder_run_id // .run_id // empty' response_body.json 2>/dev/null || echo "")
    
    if [ -n "$run_id" ] && [ "$run_id" != "null" ]; then
      echo "run-id=$run_id" >> $GITHUB_OUTPUT
      echo "📋 Run ID: $run_id"
      
      url=$(jq -r '.url // empty' response_body.json 2>/dev/null || echo "")
      if [ -z "$url" ]; then
        url="https://autonoma.app/runs/$run_id"
      fi
      
      echo "url=$url" >> $GITHUB_OUTPUT
      echo "🔗 View results at: $url"
      
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
rm -f /tmp/payload.json
rm -f /tmp/curl_output.txt
