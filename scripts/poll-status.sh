#!/bin/bash

echo "⏳ Starting status polling..."

status_url=$1
test_id=$2
max_wait_minutes=$3
client_id=$4
client_secret=$5

max_wait=$((max_wait_minutes * 60))
poll_interval=10
start_time=$(date +%s)

final_status_url="$status_url"
if [ -n "$test_id" ]; then
  final_status_url="${status_url}/${test_id}"
fi

echo "🔍 Polling URL: $final_status_url"
echo "⏰ Max wait time: ${max_wait_minutes} minutes"

while true; do
  current_time=$(date +%s)
  elapsed=$((current_time - start_time))
  elapsed_minutes=$((elapsed / 60))
  
  if [ $elapsed -ge $max_wait ]; then
    echo "⏰ Timeout reached after ${elapsed_minutes} minutes" >> $GITHUB_OUTPUT
    echo "final-status=timeout" >> $GITHUB_OUTPUT
    exit 1
  fi
  
  echo "📡 Checking status... (${elapsed_minutes}m elapsed)"
  
  response=$(curl -s -w "%{http_code}" \
    -H "autonoma-client-id: $client_id" \
    -H "autonoma-client-secret: $client_secret" \
    -H "Content-Type: application/json" \
    --connect-timeout 60 \
    --max-time 60 \
    "$final_status_url" \
    -o status_response.json)
  
  http_code="${response: -3}"
  
  if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    if [ -f status_response.json ]; then
      status=$(jq -r '.status // empty' status_response.json 2>/dev/null || echo "")
      url=$(jq -r '.url // empty' status_response.json 2>/dev/null || echo "")
      
      echo "📊 Current status: $status"
      if [ -n "$url" ]; then
        echo "🔗 URL: $url"
      fi
      
      case "$status" in
        "passed")
          echo "message=✅ Tests completed successfully!" >> $GITHUB_OUTPUT
          echo "final-status=success" >> $GITHUB_OUTPUT
          echo "url=$url" >> $GITHUB_OUTPUT
          rm -f status_response.json
          exit 0
          ;;
        "failed")
          echo "message=❌ Tests failed!" >> $GITHUB_OUTPUT
          echo "Response details:"
          cat status_response.json
          echo "final-status=failed" >> $GITHUB_OUTPUT
          echo "url=$url" >> $GITHUB_OUTPUT
          rm -f status_response.json
          exit 1
          ;;
        "running"|"pending")
          echo "⏳ Tests still running..."
          ;;
        "")
          echo "⚠️ No status field found in response"
          cat status_response.json
          ;;
        *)
          echo "📋 Status: $status (continuing to poll)"
          ;;
      esac
    else
      echo "⚠️ Empty response body"
    fi
  else
    echo "❌ Status check failed (HTTP $http_code)"
    if [ -f status_response.json ]; then
      echo "Response body:"
      cat status_response.json
    fi
    echo "final-status=error" >> $GITHUB_OUTPUT
    rm -f status_response.json
    exit 1
  fi
  
  rm -f status_response.json
  
  echo "⏸️ Waiting 10s before next poll..."
  sleep $poll_interval
done
