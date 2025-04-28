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

NUM_RUNS=5

while getopts "n:" opt; do
  case $opt in
  n) NUM_RUNS="$OPTARG" ;;
  *)
    echo "Usage: $0 [-n number_of_runs]"
    exit 1
    ;;
  esac
done

RESULTS_FILE="results/test_results.csv"

if [[ ! -f "$RESULTS_FILE" ]]; then
  echo "timestamp,name,trigger,platform,language,execution_ms,overhead_ms,total_ms,cold_start" >"$RESULTS_FILE"
fi

jq -c '.[]' endpoints.json | while IFS= read -r entry; do
  NAME=$(echo "$entry" | jq -r '.name')
  URL=$(echo "$entry" | jq -r '.url')
  METHOD=$(echo "$entry" | jq -r '.method')
  HAS_DATA=$(echo "$entry" | jq 'has("data")')
  TRIGGER=$(echo "$entry" | jq -r '.trigger_type')
  PLATFORM=$(echo "$entry" | jq -r '.platform')
  LANG=$(echo "$entry" | jq -r '.language')

  if [[ "$METHOD" == "POST" && "$HAS_DATA" == "true" ]]; then
    DATA=$(echo "$entry" | jq -c '.data')
    CURL_CMD=(curl -s --max-time 35 -X POST "$URL" -H "Content-Type: application/json" -d "$DATA")
  else
    CURL_CMD=(curl -s --max-time 35 -X "$METHOD" "$URL")
  fi

  echo "🐤 Tracer tool running $NUM_RUNS test(s) for $NAME at $URL..."

  for ((i = 1; i <= NUM_RUNS; i++)); do
    COLD_START=false
    if [[ $i -eq 1 ]]; then
      COLD_START=true
    fi

    START_TIME=$(date +%s.%N)
    RESP=$("${CURL_CMD[@]}")
    END_TIME=$(date +%s.%N)

    START_TIME_MS=$(echo "$START_TIME * 1000" | bc)
    END_TIME_MS=$(echo "$END_TIME * 1000" | bc)
    TOTAL_MS=$(echo "$END_TIME_MS - $START_TIME_MS" | bc -l)

    if [[ -z "$RESP" ]]; then
      echo "[WARN] $NAME ($URL) [Run #$i]: No response received." >>"$ERROR_LOG"
      continue
    fi

    if
      ! echo "$RESP" | jq -e '.execution' >/dev/null 2>&1
    then
      echo "[WARN] $NAME ($URL) [Run #$i]: Malformed JSON or missing 'execution' field." >>"$ERROR_LOG"
      continue
    fi

    EXEC_TS=$(echo "$RESP" | jq -r '.execution | tonumber')
    OVERHEAD=$(echo "$TOTAL_MS - $EXEC_TS" | bc -l)

    TOTAL_MS_DISPLAY=$(printf "%.6f" "$TOTAL_MS")
    EXEC_TS_DISPLAY=$(printf "%.6f" "$EXEC_TS")
    OVERHEAD_DISPLAY=$(printf "%.6f" "$OVERHEAD")

    echo "$TIMESTAMP,$NAME,$TRIGGER,$PLATFORM,$LANG,$EXEC_TS_DISPLAY,$OVERHEAD_DISPLAY,$TOTAL_MS_DISPLAY,$COLD_START" \
      >>"$RESULTS_FILE"
  done
done

echo "✅ Test run complete."
echo "✔️ Results saved to: $RESULTS_FILE"

if [[ -s "$ERROR_LOG" ]]; then
  echo "⚠️  Some warnings logged to: $ERROR_LOG"
else
  echo "🎉 No errors or warnings!"
  rm -f "$ERROR_LOG"
fi
