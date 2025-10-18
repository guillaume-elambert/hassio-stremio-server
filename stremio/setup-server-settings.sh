#!/bin/bash

SETTING=${1^^}
STREMIO_URL=http://127.0.0.1:11470
SETTINGS_URL=$STREMIO_URL/settings

wait_for_server() {
    local timeout=300  # 5 minutes in seconds
    local start=$SECONDS
    
    until curl -s -f -o /dev/null "$SETTINGS_URL"; do
        (( SECONDS - start >= timeout )) && return 1
        sleep 1
    done
}

if ! wait_for_server; then
    echo "Server not running."
    exit 1
fi

get_settings(){
    local SETTINGS_RAW
    SETTINGS_RAW=$(curl -s "$SETTINGS_URL")
    if [ -z "$SETTINGS_RAW" ] || ! jq -e . >/dev/null 2>&1 <<<"$SETTINGS_RAW"; then
        return 1
    fi
    echo "$SETTINGS_RAW"
}


set_auto_transcoding(){
    local SETTINGS_RAW=$(get_settings) || return 1
    local PROFILES
    readarray -t PROFILES < <(jq -r '.values?.allTranscodeProfiles[]? // empty' <<<"$SETTINGS_RAW")
    
    if [ ${#PROFILES[@]} -eq 0 ]; then
        echo "No transcoding profile"
        return 0
    fi

    curl -s "$SETTINGS_URL" \
        -H 'content-type: application/json' \
        --data-raw "{\"transcodeProfile\":\"${PROFILES[0]}\", \"transcodeHardwareAccel\": true}" > /dev/null && \
    echo "Transcoding profile successfully defined to: ${PROFILES[0]}."
}

# Set the appropriate
case $SETTING in
    "AUTO_TRANSCODING")
        # Additionnal sleep to be sure transcoding profiles are populated
        sleep 2
        set_auto_transcoding || return 1
    ;;

    *)
        echo "$SETTING not supported yet"
    ;;
esac