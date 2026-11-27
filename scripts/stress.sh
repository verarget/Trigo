#!/bin/bash

ZONE="us-central1"
MIG="web-mig"
DURATION=900

END=$((SECONDS + DURATION))

while [ "$SECONDS" -lt "$END" ]; do

    INSTANCES=$(gcloud compute instance-groups \
        managed list-instances "$MIG" \
        --zone="$ZONE" \
        --filter="instanceStatus=RUNNING" \
        --format="value(instance.basename())")

    for VM in $INSTANCES; do

        gcloud compute ssh "$VM" \
            --zone="$ZONE" \
            --tunnel-through-iap \
            --quiet \
            --command="
                if ! pgrep -x stress-ng >/dev/null; then
                    nohup stress-ng \
                        --cpu 0 \
                        --cpu-load 100 \
                        --timeout 120s \
                        >/tmp/stress.log 2>&1 </dev/null &
                fi
            " &

    done

    wait
    sleep 30

done