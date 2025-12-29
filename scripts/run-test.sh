#!/bin/bash
set -e

echo "🚀 Triggering test run..."

trigger_url=$1
test_id=$2
max_wait_minutes=$3
client_id=$4
client_secret=$5
application_versions_json=$6

echo "DEBUG: application_versions_json received: '$application_versions_json'"
echo "DEBUG: application_versions_json length: ${#application_versions_json}"

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
  
  data_payload=$(jq -n \
    --argjson app_versions "$app_versions" \
    '{
      source: "ci-cd",
      recursive: true,
      application_versions: $app_versions
    }')
  
  echo "DEBUG: data_payload with app_versions: $data_payload"
else
  echo "DEBUG: No application versions provided, using default payload"
  data_payload='{"source": "ci-cd"}'
fi

echo "DEBUG: Final data_payload length: ${#data_payload}"
echo "DEBUG: Final data_payload content: $data_payload"

run_url="$trigger_url/$test_id/run"
echo "📡 Calling endpoint: $run_url"
echo "📦 Payload: $data_payload"

response=$(curl -s -w "%{http_code}" \
  -X POST \
  -H "autonoma-client-id: $client_id" \
  -H "autonoma-client-secret: $client_secret" \
  -H "Content-Type: application/json" \
  -d "$data_payload" \
  --connect-timeout 60 \
  --max-time 60 \
  "$run_url" \
  -o response_body.json)

http_code="${response: -3}"

echo "DEBUG: HTTP response code: $http_code"

if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
  echo "✅ Test run triggered successfully (HTTP $http_code)"
  
  if [ -f response_body.json ]; then
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
