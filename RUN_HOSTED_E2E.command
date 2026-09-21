#!/bin/zsh
set -u

cd "${0:A:h}"

if [[ ! -f .env.staging ]]; then
  echo "ERROR: .env.staging is missing."
  read -k 1 "?Press any key to close..."
  exit 1
fi

set -a
source ./.env.staging
set +a

export PATH="/Users/hishamessam/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin:$PATH"
export PLAYWRIGHT_BROWSERS_PATH="$PWD/work/pw-browsers"
app_port="${HOSTED_E2E_BASE_URL##*:}"

server_pid=""
cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

if ! curl -fsS "${HOSTED_E2E_BASE_URL}/login" >/dev/null 2>&1; then
  echo "Starting the Staging application..."
  ./node_modules/.bin/next start -p "$app_port" > /tmp/eco-healthy-hosted-e2e-server.log 2>&1 &
  server_pid=$!
  for attempt in {1..30}; do
    if curl -fsS "${HOSTED_E2E_BASE_URL}/login" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

if ! curl -fsS "${HOSTED_E2E_BASE_URL}/login" >/dev/null 2>&1; then
  echo "ERROR: The Staging application did not start."
  echo "See /tmp/eco-healthy-hosted-e2e-server.log"
  read -k 1 "?Press any key to close..."
  exit 1
fi

echo "Running the real Hosted Supabase commercial cycle..."
./node_modules/.bin/playwright test --config=playwright.hosted.config.ts
test_status=$?

if [[ $test_status -eq 0 ]]; then
  echo ""
  echo "SUCCESS: Hosted E2E completed. Evidence is in outputs/hosted-e2e."
  open "$PWD/outputs/hosted-e2e" >/dev/null 2>&1 || true
else
  echo ""
  echo "FAILED: Keep this window open and send the visible error for review."
fi

echo ""
read -k 1 "?Press any key to close..."
exit $test_status
