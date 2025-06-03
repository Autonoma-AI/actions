# Autonoma AI GitHub Actions

A collection of GitHub Actions for interacting with the Autonoma AI testing platform. These actions allow you to trigger and monitor test/folder runs directly from your CI/CD workflows.

## Available Actions

### 🔍 Single Test Runner

Triggers and monitors individual test execution.

### 📁 Folder Test Runner

Triggers and monitors folder test execution.

## Quick Start

### Prerequisites

You'll need to set up these repository secrets:

- `AUTONOMA_CLIENT_ID` - Your Autonoma AI client ID
- `AUTONOMA_CLIENT_SECRET` - Your Autonoma AI client secret

### Basic Usage

**Run a single test:**

```yaml
name: Run Single Test
on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Execute Single Test
        uses: autonoma-ai/actions/test-runner@v1
        with:
          test-id: "some-id"
          client-id: ${{ secrets.AUTONOMA_CLIENT_ID }}
          client-secret: ${{ secrets.AUTONOMA_CLIENT_SECRET }}
          max-wait-time: "10" # Wait up to 10 minutes
```

**Run folder tests:**

```yaml
name: Run Folder Tests
on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Execute Folder Tests
        uses: autonoma-ai/actions/folder-runner@v1
        with:
          folder-id: "some-id"
          client-id: ${{ secrets.AUTONOMA_CLIENT_ID }}
          client-secret: ${{ secrets.AUTONOMA_CLIENT_SECRET }}
          max-wait-time: "15" # Wait up to 15 minutes
```

## Actions Reference

### Single Test Runner (`test-runner`)

Executes individual tests through the Autonoma AI platform.

**Inputs:**

| Name            | Description                                                | Required | Default |
| --------------- | ---------------------------------------------------------- | -------- | ------- |
| `client-id`     | Your Autonoma AI client ID                                 | ✅       | -       |
| `client-secret` | Your Autonoma AI client secret                             | ✅       | -       |
| `max-wait-time` | Maximum wait time in minutes, allowed range 10-20 minutes. | ❌       | `10`    |

**Outputs:**

| Name           | Description                                              |
| -------------- | -------------------------------------------------------- |
| `run-id`       | ID of the test/folder run (if returned by API)           |
| `final-status` | Final status: `success`, `failed`, `timeout`, or `error` |
| `url`          | URL to check run status                                  |

**Example:**

```yaml
- name: Run Single Test
  id: single-test
  uses: autonoma-ai/github-actions/test-runner@v1
  with:
    client-id: ${{ secrets.AUTONOMA_CLIENT_ID }}
    client-secret: ${{ secrets.AUTONOMA_CLIENT_SECRET }}
    max-wait-time: "12"

- name: Check Results
  run: |
    echo "Test ID: ${{ steps.single-test.outputs.run-id }}"
    echo "Status: ${{ steps.single-test.outputs.final-status }}"
    echo "Status: ${{ steps.single-test.outputs.message }}"
```

### Folder Test Runner (`folder-runner`)

Executes folder/directory tests through the Autonoma AI platform.

**Inputs:**

| Name            | Description                                                | Required | Default |
| --------------- | ---------------------------------------------------------- | -------- | ------- |
| `client-id`     | Your Autonoma AI client ID                                 | ✅       | -       |
| `client-secret` | Your Autonoma AI client secret                             | ✅       | -       |
| `max-wait-time` | Maximum wait time in minutes, allowed range 10-20 minutes. | ❌       | `10`    |

**Outputs:**

| Name           | Description                                              |
| -------------- | -------------------------------------------------------- |
| `run-id`       | ID of the test/folder run (if returned by API)           |
| `final-status` | Final status: `success`, `failed`, `timeout`, or `error` |
| `url`          | URL to check run status                                  |

**Example:**

```yaml
- name: Run Folder Tests
  id: folder-test
  uses: autonoma-ai/github-actions/folder-runner@v1
  with:
    client-id: ${{ secrets.AUTONOMA_CLIENT_ID }}
    client-secret: ${{ secrets.AUTONOMA_CLIENT_SECRET }}
    max-wait-time: "20"

- name: Handle Results
  if: always()
  run: |
    if [ "${{ steps.folder-test.outputs.final-status }}" = "success" ]; then
      echo "✅ All tests passed!"
    else
      echo "❌ Tests failed or encountered an error"
      exit 1
    fi
```

## API Endpoints

The actions interact with these Autonoma AI endpoints:

### Single Test Runner

- **Trigger**: `POST https://api.yourservice.com/api/tests/run`
- **Status**: `GET https://api.yourservice.com/api/tests/status?id={test-id}`

### Folder Test Runner

- **Trigger**: `POST https://api.yourservice.com/api/folders/run`
- **Status**: `GET https://api.yourservice.com/api/folders/status?id={test-id}`

## Authentication

Both actions use custom header authentication:

```
autonoma-client-id: <your-client-id>
autonoma-client-secret: <your-client-secret>
```

## Status Values

The actions recognize these status responses:

- **Success**: `completed`, `success`, `passed`
- **Failure**: `failed`, `failure`, `error`
- **In Progress**: `running`, `in_progress`, `pending`

## Timeouts and Limits

- **Polling Interval**: Fixed at 30 seconds
- **Max Wait Time**: 10-20 minutes (configurable)
- **HTTP Timeout**: 60 seconds per request
- **Default Wait Time**: 10 minutes

## Setup Instructions

### 1. Add Secrets to Your Repository

Go to your repository → Settings → Secrets and variables → Actions:

- `CLIENT_ID`: Your Autonoma AI client ID
- `CLIENT_SECRET`: Your Autonoma AI client secret

### 2. Add Actions to Your Workflow

Choose the appropriate action for your needs:

- Use `test-runner` for individual test execution
- Use `folder-runner` for directory/batch test execution

### 3. Configure Timeouts

Set `max-wait-time` based on your test duration:

- **Short tests**: 10-12 minutes
- **Medium tests**: 13-17 minutes
- **Long tests**: 18-20 minutes

## Troubleshooting

### Common Issues

**❌ Authentication Failed (401)**

- Verify `CLIENT_ID` and `CLIENT_SECRET` secrets are set correctly
- Check that credentials are valid for the Autonoma AI platform

**⏰ Timeout Errors**

- Increase `max-wait-time` (maximum 20 minutes)
- Check if your tests typically take longer than expected

**🔗 Connection Issues**

- Verify GitHub Actions runner can reach `api.yourservice.com`
- Check for any network restrictions in your organization

**📊 Unexpected Status Values**

- The action logs the actual status received from your API
- Check the action logs to see what status values are being returned

### Debug Mode

Enable detailed logging by setting this repository secret:

```
ACTIONS_STEP_DEBUG = true
```

### Getting Help

1. Check the action logs for detailed error messages
2. Verify your API responses match the expected format
3. Ensure your test execution times are within the timeout limits

## License

These actions are provided under the MIT License.
