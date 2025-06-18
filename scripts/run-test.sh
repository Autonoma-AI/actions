#!/bin/bash

echo "🚀 Triggering test run..."

trigger_url=$1
test_id=$2
max_wait_minutes=$3
client_id=$4
client_secret=$5

if [ "$max_wait_minutes" -lt 10 ] || [ "$max_wait_minutes" -gt 20 ]; then
  echo "⚠️ max-wait-time must be between 10-20 minutes. Provided: ${max_wait_minutes}, using default time 10 minutes"
  max_wait_minutes=10
fi

run_url="$trigger_url/$test_id/run"
echo "📡 Calling endpoint: $run_url"

response=$(curl -s -w "%{http_code}" \
  -X POST \
  -H "autonoma-client-id: $client_id" \
  -H "autonoma-client-secret: $client_secret" \
  -H "Content-Type: application/json" \
  --connect-timeout 60 \
  --max-time 60 \
  "$run_url" \
  -o response_body.json)

http_code="${response: -3}"

if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
  echo "✅ Test run triggered successfully (HTTP $http_code)"
  
  if [ -f response_body.json ]; then
    run_id=$(jq -r '.run_id // .folder_run_id ' response_body.json 2>/dev/null || echo "")
    if [ -n "$run_id" ] && [ "$run_id" != "null" ]; then
      echo "run-id=$run_id" >> $GITHUB_OUTPUT
      echo "📋 Run ID: $run_id"
    fi
  fi
else
  echo "❌ Failed to trigger test run (HTTP $http_code)"
  if [ -f response_body.json ]; then
    echo "Response body:"
    cat response_body.json
  fi
  exit 1
fi

rm -f response_body.json
