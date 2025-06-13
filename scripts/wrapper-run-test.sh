#!/bin/bash

echo "🚀 Starting Autonoma test runner for GitLab..."

# Parse arguments
item_id=$1
max_wait_minutes=$2
client_id=$3
client_secret=$4
type=$5  # "test" or "folder"

RUN_TEST_URL="https://autonoma.app/api/run/test"
RUN_STATUS_URL="https://autonoma.app/api/run/"
RUN_FOLDER_URL="https://autonoma.app/api/run/folder"
RUN_FOLDER_STATUS_URL="https://autonoma.app/api/run/folder"

export GITHUB_OUTPUT=$(mktemp)

if [ -z "$item_id" ] || [ -z "$max_wait_minutes" ] || [ -z "$client_id" ] || [ -z "$client_secret" ] || [ -z "$type" ]; then
    echo "❌ Usage: $0 <item_id> <max_wait_minutes> <client_id> <client_secret> <type>"
    echo "   type: 'test' or 'folder'"
    exit 1
fi

if [ "$type" = "test" ]; then
    BASE_URL="$RUN_TEST_URL"
    BASE_POLL_URL="$RUN_STATUS_URL"
elif [ "$type" = "folder" ]; then
    BASE_URL="$RUN_FOLDER_URL"
    BASE_POLL_URL="$RUN_FOLDER_STATUS_URL"
else
    echo "❌ Invalid type: $type. Must be 'test' or 'folder'"
    exit 1
fi

echo "📋 Configuration:"
echo "   Item ID: $item_id"
echo "   Type: $type"
echo "   Max wait: ${max_wait_minutes} minutes"
echo "   API URL: $BASE_URL"

echo ""
echo "=== Step 1: Triggering $type run ==="
/autonoma/run-test.sh \
    "$BASE_URL" \
    "$item_id" \
    "$max_wait_minutes" \
    "$client_id" \
    "$client_secret"

trigger_exit_code=$?

if [ $trigger_exit_code -ne 0 ]; then
    echo "❌ Failed to trigger $type run"
    rm -f "$GITHUB_OUTPUT"
    exit $trigger_exit_code
fi

if [ -f "$GITHUB_OUTPUT" ]; then
    RUN_ID=$(grep "^run-id=" "$GITHUB_OUTPUT" | cut -d'=' -f2)
    
    if [ -z "$RUN_ID" ] || [ "$RUN_ID" = "null" ]; then
        echo "❌ Failed to extract run ID from trigger response"
        rm -f "$GITHUB_OUTPUT"
        exit 1
    fi
    
    echo "✅ Retrieved run ID: $RUN_ID"
else
    echo "❌ Output file not found"
    exit 1
fi

echo ""
echo "=== Step 2: Polling for status ==="
/autonoma/poll-status.sh \
    "$BASE_POLL_URL" \
    "$RUN_ID" \
    "$max_wait_minutes" \
    "$client_id" \
    "$client_secret" \
    "$type"

poll_exit_code=$?

rm -f "$GITHUB_OUTPUT"

exit $poll_exit_code
