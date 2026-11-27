#!/bin/bash

set -euo pipefail

ZONE="${ZONE:-us-east1-c}"
MIG="${MIG:-web-mig}"
DURATION="${DURATION:-900}"
INTERVAL="${INTERVAL:-30}"

for SETTING in DURATION INTERVAL; do
    if [[ ! "${!SETTING}" =~ ^[1-9][0-9]*$ ]]; then
        printf '%s must be a positive number of seconds.\n' "$SETTING" >&2
        exit 1
    fi
done

GCLOUD_FLAGS=(--quiet)
if [[ -n "${PROJECT_ID:-}" ]]; then
    GCLOUD_FLAGS+=(--project="$PROJECT_ID")
fi

END=$((SECONDS + DURATION))

while [ "$SECONDS" -lt "$END" ]; do

    if ! INSTANCE_OUTPUT=$(gcloud compute instance-groups managed list-instances "$MIG" \
        --zone="$ZONE" \
        --filter="instanceStatus=RUNNING" \
        --format="value(instance.basename())" \
        "${GCLOUD_FLAGS[@]}"); then
        printf 'Could not list instances in %s.\n' "$MIG" >&2
        exit 1
    fi

    # Native Windows gcloud emits CRLF; a trailing CR makes the VM name invalid.
    INSTANCE_OUTPUT=${INSTANCE_OUTPUT//$'\r'/}
    mapfile -t INSTANCES <<< "$INSTANCE_OUTPUT"

    for VM in "${INSTANCES[@]}"; do
        [[ -z "$VM" ]] && continue
        if [[ ! "$VM" =~ ^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$ ]]; then
            printf 'Invalid VM name from gcloud: %q\n' "$VM" >&2
            exit 1
        fi

        printf 'Ensuring CPU stress is running on %s...\n' "$VM"
        # Foreground connections serialize key generation and allow first-use
        # host-key verification. Only the remote stress process is backgrounded.
        if ! gcloud compute ssh "$VM" \
            --zone="$ZONE" \
            --tunnel-through-iap \
            "${GCLOUD_FLAGS[@]}" \
            --command="
                if ! pgrep -x stress-ng >/dev/null; then
                    nohup stress-ng \
                        --cpu 0 \
                        --cpu-load 100 \
                        --timeout 120s \
                        >/tmp/stress.log 2>&1 </dev/null &
                fi
            "; then
            printf 'SSH failed for %s; resolve the connection error before retrying.\n' "$VM" >&2
            exit 1
        fi

    done

    REMAINING=$((END - SECONDS))
    (( REMAINING <= 0 )) && break
    if (( REMAINING < INTERVAL )); then
        sleep "$REMAINING"
    else
        sleep "$INTERVAL"
    fi

done
