#!/bin/bash

set -euo pipefail

ZONE="${ZONE:-us-east1-c}"
MIG="${MIG:-web-mig}"
DURATION="${DURATION:-900}"
INTERVAL="${INTERVAL:-30}"
SSH_RETRIES="${SSH_RETRIES:-6}"
SSH_RETRY_DELAY="${SSH_RETRY_DELAY:-10}"

for SETTING in DURATION INTERVAL SSH_RETRIES SSH_RETRY_DELAY; do
    if [[ ! "${!SETTING}" =~ ^[1-9][0-9]*$ ]]; then
        printf '%s must be a positive integer.\n' "$SETTING" >&2
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

        # RUNNING instances can still be starting SSH or installing stress-ng.
        SSH_SUCCEEDED=false
        for (( ATTEMPT=1; ATTEMPT<=SSH_RETRIES; ATTEMPT++ )); do
            printf 'Connecting to %s (attempt %s/%s)...\n' "$VM" "$ATTEMPT" "$SSH_RETRIES"
            # Serialize SSH so key generation cannot race. Windows gcloud may
            # automatically answer Plink's host-key prompt, then keep going.
            if gcloud compute ssh "$VM" \
                --zone="$ZONE" \
                --tunnel-through-iap \
                "${GCLOUD_FLAGS[@]}" \
                --command="
                command -v stress-ng >/dev/null 2>&1 || {
                    echo 'stress-ng is not installed yet; waiting for VM startup.' >&2
                    exit 75
                }
                if ! pgrep -x stress-ng >/dev/null; then
                    nohup stress-ng \
                        --cpu 0 \
                        --cpu-load 100 \
                        --timeout 120s \
                        >/tmp/stress.log 2>&1 </dev/null &
                    echo 'Started CPU stress for 120 seconds.'
                else
                    echo 'CPU stress is already running.'
                fi
            "; then
                printf '\nSSH succeeded on %s.\n' "$VM"
                SSH_SUCCEEDED=true
                break
            fi

            printf '\nSSH or VM setup is not ready on %s.\n' "$VM" >&2
            if (( ATTEMPT < SSH_RETRIES )); then
                printf 'Retrying in %s seconds...\n' "$SSH_RETRY_DELAY" >&2
                sleep "$SSH_RETRY_DELAY"
            fi
        done

        if [[ "$SSH_SUCCEEDED" != true ]]; then
            printf 'SSH failed for %s after %s attempts.\n' "$VM" "$SSH_RETRIES" >&2
            printf 'Run: gcloud compute ssh %q --zone=%q --tunnel-through-iap --troubleshoot' "$VM" "$ZONE" >&2
            printf ' %q' "${GCLOUD_FLAGS[@]}" >&2
            printf '\n' >&2
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
