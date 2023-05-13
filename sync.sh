#!/bin/bash -e
export GITHUB_API="https://api.github.com"
source .env
source functions.sh

TEAMS_SYNC_JSON=`jq -r '.sync[]' sync.json`

while read -r json
do
    echo ""
    echo "Sync Team ${json} ..."
    echo "---------------------------------------------"
    sync_team "${json}"
    
done <<< "$TEAMS_SYNC_JSON"
