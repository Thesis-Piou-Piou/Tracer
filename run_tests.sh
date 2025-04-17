#!/bin/bash

set -euo pipefail

mkdir -p results

ERROR_LOG="results/errors.log"
>"$ERROR_LOG"

if [[ ! -f "endpoints.json" ]]; then
  echo "[ERROR] endpoints.json not found. Exiting."
  exit 1
fi

if ! jq -e '.[0] | has("url")' endpoints.json >/dev/null 2>&1; then
  echo "[ERROR] First entry missing 'url' field. Exiting."
  exit 1
fi

TIMESTAMP=$(date --iso-8601=seconds)

jq -c '.[]' endpoints.json | while IFS= read -r entry; do
  NAME=$(echo "$entry" | jq -r '.name')
  URL=$(echo "$entry" | jq -r '.url')
  WORKLOAD=$(echo "$entry" | jq -r '.workload_type')
  PLATFORM=$(echo "$entry" | jq -r '.platform')
  LANG=$(echo "$entry" | jq -r '.language')

  echo "Testing $NAME at $URL..."

  START_TIME=$(date +%s.%N)
  RESP=$(curl -s --max-time 10 "$URL")

  END_TIME=$(date +%s.%N)
  TOTAL_MS=$(echo "$END_TIME - $START_TIME" | bc -l)

  if [[ -z "$RESP" ]]; then
    echo "[WARN] $NAME ($URL): No response received." >>"$ERROR_LOG"
    continue
  fi

  if
    ! echo "$RESP" | jq -e '.execution' >/dev/null 2>&1
  then
    echo "[WARN] $NAME ($URL): Malformed JSON or missing 'execution' field." >>"$ERROR_LOG"
    continue
  fi

  EXEC_TS=$(echo "$RESP" | jq -r '.execution | tonumber')
  OVERHEAD=$(echo "$TOTAL_MS - $EXEC_TS" | bc -l)

  TOTAL_MS_DISPLAY=$(printf "%.6f" "$TOTAL_MS")
  OVERHEAD_DISPLAY=$(printf "%.6f" "$OVERHEAD")

  echo "$TIMESTAMP,$NAME,$WORKLOAD,$PLATFORM,$LANG,$EXEC_TS,$OVERHEAD_DISPLAY,$TOTAL_MS" \
    >>results/test_results.csv
done

echo "🐤 Test run complete."
echo "✔️ Results saved to: results/test_results.csv"

if [[ -s "$ERROR_LOG" ]]; then
  echo "⚠️  Some warnings logged to: $ERROR_LOG"
else
  echo "🎉 No errors or warnings!"
  rm -f "$ERROR_LOG"
fi
