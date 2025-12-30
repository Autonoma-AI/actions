#!/bin/bash
set -e

echo "🚀 Triggering test run..."
echo "DEBUG: Bash version: $BASH_VERSION"
echo "DEBUG: Python version: $(python3 --version)"

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

run_url="$trigger_url/$test_id/run"
echo "📡 Calling endpoint: $run_url"
echo "📦 Payload: $data_payload"

# Use Python to make the request
echo "DEBUG: Sending request with Python..."
python3 << EOF
import urllib.request
import json
import sys

payload = '''$data_payload'''
url = "$run_url"
client_id = "$client_id"
client_secret = "$client_secret"

print(f"DEBUG: Python payload length: {len(payload)} bytes")
print(f"DEBUG: Python payload content: {payload}")

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
    
    print(f"DEBUG: Request headers: {dict(req.headers)}")
    print(f"DEBUG: Request data length: {len(req.data)} bytes")
    
    with urllib.request.urlopen(req, timeout=60) as response:
        response_body = response.read().decode('utf-8')
        status_code = response.status
        
        print(f"DEBUG: HTTP response code: {status_code}")
        print(f"DEBUG: Response body: {response_body}")
        
        # Write response to file for bash to process
        with open('response_body.json', 'w') as f:
            f.write(response_body)
        
        # Write status code to file
        with open('/tmp/status_code.txt', 'w') as f:
            f.write(str(status_code))
            
        sys.exit(0)
        
except urllib.error.HTTPError as e:
    error_body = e.read().decode('utf-8')
    print(f"DEBUG: HTTP error {e.code}")
    print(f"DEBUG: Error response: {error_body}")
    
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
rm -f /tmp/status_code.txt
