#!/bin/bash -e

github_api_get_team(){
    ORG="$1"
    TEAM="$2"
    DEBUG_ROOT=".tmp/github/check_team/${ORG}/${TEAM}/"
    DEBUG_LOG="${DEBUG_ROOT}/response.json"   
    
    mkdir -p "${DEBUG_ROOT}"
    RESPONSE_CODE=`curl -s --location "${GITHUB_API}/orgs/${ORG}/teams/${TEAM}" \
         --header "Authorization: token ${GITHUB_AUTH}" -w "%{http_code}" -o ${DEBUG_LOG}`
    RESPONSE=`cat ${DEBUG_LOG}`
    echo "${RESPONSE_CODE}
${RESPONSE}"
}

github_api_create_team(){
    ORG="$1"
    TEAM="$2"
    TEAM_DESCRIPTION="$3"

    DEBUG_ROOT=".tmp/github/create_team/${ORG}/${TEAM}/"
    DEBUG_REQUEST="${DEBUG_ROOT}/request.json"
    DEBUG_LOG="${DEBUG_ROOT}/response.json"

    mkdir -p "${DEBUG_ROOT}"
    
    REQUEST_BODY='{"name":"'${TEAM}'","description":"'${TEAM_DESCRIPTION}'","permission":"pull","notification_setting":"notifications_enabled","privacy":"closed"}'
    echo "${REQUEST_BODY}" > ${DEBUG_REQUEST}

    RESPONSE_CODE=`curl -s -X POST --location "${GITHUB_API}/orgs/${ORG}/teams" \
         --header "Authorization: token ${GITHUB_AUTH}" --header 'Content-Type: application/json' \
         --data "${REQUEST_BODY}" \
         -w "%{http_code}" -o ${DEBUG_LOG}`
    RESPONSE=`cat ${DEBUG_LOG}`
    echo "${RESPONSE_CODE}
${RESPONSE}"
}

github_api_patch_team(){
    ORG="$1"
    TEAM="$2"
    PARENT_TEAM_ID="$3"
    DEBUG_ROOT=".tmp/github/patch_team/${ORG}/${TEAM}/"
    DEBUG_LOG="${DEBUG_ROOT}/response.json"   
    
    mkdir -p "${DEBUG_ROOT}"
    RESPONSE_CODE=`curl -s -X PATCH --location "${GITHUB_API}/orgs/${ORG}/teams/${TEAM}" \
         --header "Authorization: token ${GITHUB_AUTH}" --header 'Content-Type: application/json' \
         --data '{"parent_team_id":'${PARENT_TEAM_ID}'}' \
         -w "%{http_code}" -o ${DEBUG_LOG}`
    RESPONSE=`cat ${DEBUG_LOG}`
    echo "${RESPONSE_CODE}
${RESPONSE}"
}

github_api_get_user_team_membership(){
    ORG="$1"
    USER="$2"
    DEBUG_ROOT=".tmp/github/get_user_team_membership/${ORG}/${USER}"
    DEBUG_LOG="${DEBUG_ROOT}/response.json"   
    
    mkdir -p "${DEBUG_ROOT}"
    RESPONSE_CODE=`curl -s -X POST --location "${GITHUB_API}/graphql" \
         --header "Authorization: token ${GITHUB_AUTH}" --header 'Content-Type: application/json' \
         --data '{"query":"query { organization(login: \"'${ORG}'\") { teams(first: 100, userLogins: [\"'${USER}'\"]) { totalCount edges { node { name description } } } } }"}' \
         -w "%{http_code}" -o ${DEBUG_LOG}`
    RESPONSE=`cat ${DEBUG_LOG}`
    echo "${RESPONSE_CODE}
${RESPONSE}"
}

github_api_patch_user_team_membership(){
    ORG="$1"
    TEAM="$2"
    USER="$3"
    DEBUG_ROOT=".tmp/github/patch_user_team_membership/${ORG}/${USER}"
    DEBUG_LOG="${DEBUG_ROOT}/response.json"   
    
    mkdir -p "${DEBUG_ROOT}"
    RESPONSE_CODE=`curl -s -X PUT --location "${GITHUB_API}/orgs/${ORG}/teams/${TEAM}/memberships/${USER}" \
         --header "Authorization: token ${GITHUB_AUTH}" --header 'Content-Type: application/json' \
         --data '{"role":"member"}' \
         -w "%{http_code}" -o ${DEBUG_LOG}`
    RESPONSE=`cat ${DEBUG_LOG}`
    echo "${RESPONSE_CODE}
${RESPONSE}"
}

github_api_revoke_user_team_membership(){
    ORG="$1"
    TEAM="$2"
    USER="$3"
    DEBUG_ROOT=".tmp/github/revoke_user_team_membership/${ORG}/${TEAM}/${USER}"
    DEBUG_LOG="${DEBUG_ROOT}/response.json"   
    
    mkdir -p "${DEBUG_ROOT}"
    RESPONSE_CODE=`curl -s -X DELETE --location "${GITHUB_API}/orgs/${ORG}/teams/${TEAM}/memberships/${USER}" \
         --header "Authorization: token ${GITHUB_AUTH}" --header 'Content-Type: application/json' \
         -w "%{http_code}" -o ${DEBUG_LOG}`
    RESPONSE=`cat ${DEBUG_LOG}`
    echo "${RESPONSE_CODE}
${RESPONSE}"
}

github_api_patch_team_repository(){
    ORG="$1"
    TEAM="$2"
    REPO="$3"
    PERMISSION="$4"
    DEBUG_ROOT=".tmp/github/patch_team_repository/${ORG}/${TEAM}/${REPO}"
    DEBUG_REQUEST="${DEBUG_ROOT}/request.txt"
    DEBUG_LOG="${DEBUG_ROOT}/response.json"
    
    mkdir -p "${DEBUG_ROOT}"
    
    REQUEST_URL="${GITHUB_API}/orgs/${ORG}/teams/${TEAM}/repos/${REPO}"
    REQUEST_BODY='{"permission":"'${PERMISSION}'"}'

    echo "${REQUEST_URL}" > ${DEBUG_REQUEST}
    echo "${REQUEST_BODY}" >> ${DEBUG_REQUEST}

    RESPONSE_CODE=`curl -s -X PUT --location "${REQUEST_URL}" \
         --header "Authorization: token ${GITHUB_AUTH}" --header 'Content-Type: application/json' \
         --data "${REQUEST_BODY}" \
         -w "%{http_code}" -o ${DEBUG_LOG}`
    RESPONSE=`cat ${DEBUG_LOG}`
    echo "${RESPONSE_CODE}
${RESPONSE}"
}

github_org_sync_team(){
    ORG="$1"
    TEAM="$2"
    JSON_FILE="$3"

    echo ""
    echo " > Sync team"

    TEAM_DESCRIPTION=`jq -r '.teams[] | select(.team == "'${TEAM}'") | .team_description' ${JSON_FILE} | tr -d '"'`

    TEAM_EXISTS=`github_api_get_team "$ORG" "$team"`
    RESPONSE_CODE=`echo "${TEAM_EXISTS}" | head -n 1`

    if [ "$RESPONSE_CODE" == "200" ]; then
        echo " < Team already exists"
        return
    fi

    echo " < Team doesn't exist, creating team"
    CREATE_TEAM_REQUEST=`github_api_create_team "${ORG}" "${TEAM}" "${TEAM_DESCRIPTION}"`
    RESPONSE_CODE=`echo "${CREATE_TEAM_REQUEST}" | head -n 1`

    if [ "$RESPONSE_CODE" != "201" ]; then
        echo " < Error creating team, check logs"
        return 1
    fi

    echo " < Team created"
}

github_org_sync_parent_team(){
    ORG="$1"
    TEAM="$2"
    JSON_FILE="$3"

    echo ""
    echo " > Sync parent team"
    PARENT_TEAM=`jq -r '.teams[] | select(.team == "'${TEAM}'") | .parent' ${JSON_FILE}`

    echo " > Parent: ${PARENT_TEAM}"

    if [ "${PARENT_TEAM}" == "null" ]; then
        echo " < Nothing to do here"
        return
    fi

    API_REQUEST=`github_api_get_team "${ORG}" "${PARENT_TEAM}"`
    RESPONSE_CODE=`echo "${API_REQUEST}" | head -n 1`
    RESPONSE=`echo "${API_REQUEST}" | sed -n '2,$p'`

    if [ "$RESPONSE_CODE" != "200" ]; then
        echo " < An error occured, check logs. Team should already exist at this point."
        exit 1
    fi

    PARENT_TEAM_ID=`echo "${RESPONSE}" | jq '.id'`

    echo " > Updating parent to ${PARENT_TEAM} (${PARENT_TEAM_ID})"

    API_REQUEST=`github_api_patch_team "${ORG}" "${TEAM}" "${PARENT_TEAM_ID}"`
    RESPONSE_CODE=`echo "${API_REQUEST}" | head -n 1`

    if [ "$RESPONSE_CODE" == "200" ]; then
        echo " < Updated parent team (200)"
        return
    elif [ "$RESPONSE_CODE" == "201" ]; then
        echo " < Updated parent team (201)"
        return
    else
        echo " < An error occured, check logs. Team should already exist at this point."
        exit 1
    fi

    echo "DONE"
}

github_org_sync_repositories_add(){
    ORG="$1"
    TEAM="$2"
    REPOSITORIES="$3"
    REPOSITORY_DEFAULT_PERMISSION="$4"

    # echo " < Repositories: ${REPOSITORIES}"
    # echo " < Default Permission: ${REPOSITORY_DEFAULT_PERMISSION}"

    IFS=',' read -ra repositories_array <<< "${REPOSITORIES}"

    for repo in "${repositories_array[@]}"
    do
        echo " > Add ${repo}"
        API_REQUEST=`github_api_patch_team_repository "${ORG}" "${TEAM}" "${repo}" "${REPOSITORY_DEFAULT_PERMISSION}"`
        RESPONSE_CODE=`echo "${API_REQUEST}" | head -n 1`

        if [ "$RESPONSE_CODE" != "204" ]; then
            echo " < An error occured, check logs"
            exit 1
        fi

        echo " < Repository Added"
    done
}

github_org_sync_repositories(){
    ORG="$1"
    TEAM="$2"
    JSON_FILE="$3"

    echo ""
    echo " > Sync repositories"
    
    REPOSITORY_DEFAULT_PERMISSION=`jq -r '.teams[] | select(.team == "'${TEAM}'") | .repository_default_permission' ${JSON_FILE}`
    PARENT_TEAM=`jq -r '.teams[] | select(.team == "'${TEAM}'") | .parent' ${JSON_FILE}`
    REPOSITORIES_COUNT=`jq -r '.teams[] | select(.team == "'${TEAM}'") | .repositories | length' ${JSON_FILE}`
    
    if [ "${PARENT_TEAM}" == "null" ]; then
        REPOSITORIES_COUNT_PARENT="0"
    else
        REPOSITORIES_COUNT_PARENT=`jq -r '.teams[] | select(.team == "'${PARENT_TEAM}'") | .repositories | length' ${JSON_FILE}`
    fi
    
    echo " < Repo count: ${REPOSITORIES_COUNT}"
    echo " < Parent repo count: ${REPOSITORIES_COUNT_PARENT}"

    if [ "${REPOSITORIES_COUNT_PARENT}" != "0" ]; then
        TEAM_JSON_STRING='.team == "'${PARENT_TEAM}'"'
    fi
    if [ "${REPOSITORIES_COUNT}" != "0" ]; then
        if [ "${REPOSITORIES_COUNT_PARENT}" != "0" ]; then
            TEAM_JSON_STRING+=','
        fi
        TEAM_JSON_STRING+='.team == "'${TEAM}'"'
    fi

    # echo " < JSON Search: ${TEAM_JSON_STRING}"

    REPOSITORIES=`jq -jr '.teams[] | select('"${TEAM_JSON_STRING}"') | select(.repositories != null) | .repositories[] | "\(.)," ' poc-team.json`

    echo " < Repositories: ${REPOSITORIES}"
    echo " < Default Permission: ${REPOSITORY_DEFAULT_PERMISSION}"
    echo " < Parent: ${PARENT_TEAM}"

    github_org_sync_repositories_add "${ORG}" "${TEAM}" "${REPOSITORIES}" "${REPOSITORY_DEFAULT_PERMISSION}"
    
    echo " < Done"
}

is_in_teamlist(){
    TEAMS="$1"
    FIND_TEAM="$2"
    CHECK=`echo "${TEAMS}" | grep -x "${FIND_TEAM}"`

    if [ "${CHECK}" != "" ]; then
        echo "true"
        return
    fi
    echo "false"
}

github_org_sync_membership(){
    ORG="$1"
    MEMBER="$2"
    JSON_FILE="$3"

    echo ""
    echo " > Synching team membership"
    SYNC_TEAMS=`jq -jr '.teams[] | "\(.team),"' ${JSON_FILE}` # only membership in these teams will be updated
    MEMBER_TEAMS=`jq -r '.members[] | select(.member_id == "'${MEMBER}'") | .teams | @csv' ${JSON_FILE} | tr -d '"'`
    echo " < Sync teams: ${SYNC_TEAMS}"
    echo " < Member teams: ${MEMBER_TEAMS}"

    # fill arrays
    IFS=',' read -ra member_teams_array <<< "${MEMBER_TEAMS}"
    IFS=',' read -ra sync_teams_array <<< "${SYNC_TEAMS}"

    echo " > Get user team memberships"
    API_REQUEST=`github_api_get_user_team_membership "${ORG}" "${MEMBER}"`
    RESPONSE_CODE=`echo "${API_REQUEST}" | head -n 1`
    RESPONSE=`echo "${API_REQUEST}" | sed -n '2,$p'`

    TEAMS_FROM_SERVER=`echo "${RESPONSE}" | jq -r '.data.organization.teams.edges[] | .node.name'`
    TEAMS_FROM_SERVER_LIST=`echo "${RESPONSE}" | jq -jr '.data.organization.teams.edges[] | "\(.node.name),"'` # only used for logging

    echo " < Server: ${TEAMS_FROM_SERVER_LIST}"

    # First, add members to teams
    for team in "${member_teams_array[@]}"
    do
        echo " > Sync member with $team"
        CHECK=`is_in_teamlist "${TEAMS_FROM_SERVER}" "${team}"`

        if [ "$CHECK" == "true" ]; then
            echo " < Member already in ${team}"
            continue
        fi

        echo " > Add user to ${team}"
        API_REQUEST=`github_api_patch_user_team_membership "${ORG}" "${team}" "${MEMBER}"`
        RESPONSE_CODE=`echo "${API_REQUEST}" | head -n 1`

        if [ "$RESPONSE_CODE" != "200" ]; then
            echo " < An error occured, check logs"
            exit 1
        fi

        echo " < User added"
        
    done

    # Remove teams that have been granted access already
    echo " > Preparing list of teams to revoke access"
    for team in "${member_teams_array[@]}"; do
        # echo " > Removing $team from sync teams ${sync_teams_array[@]}"
        for i in "${!sync_teams_array[@]}"; do
            if [[ ${sync_teams_array[i]} == $team ]]; then
                # echo " < Removed ${sync_teams_array[i]}"
                unset 'sync_teams_array[i]'
            fi
        done
    done
    echo " < Revoke access list: ${sync_teams_array[@]}"

    # Revoke access
    for team in "${sync_teams_array[@]}"; do
        echo " > Revoking access to ${team}"
        API_REQUEST=`github_api_revoke_user_team_membership "${ORG}" "${team}" "${MEMBER}"`
        RESPONSE_CODE=`echo "${API_REQUEST}" | head -n 1`

        if [ "$RESPONSE_CODE" != "204" ]; then
            echo " < An error occured, check logs"
            exit 1
        fi

        echo " < Access revoked"
    done

    echo " < Done"
}

sync_team(){
    TEAM_JSON="$1"
    ORG=`jq -r '.github_org' ${TEAM_JSON}`
    TEAMS=`jq -r '.teams[] | [.team] | @csv' ${TEAM_JSON} | tr -d '"'`
    MEMBERS=`jq -r '.members[] | [.member_id] | @csv' ${TEAM_JSON} | tr -d '"'`

    while read -r team
    do
        echo ""
        echo " >"
        echo " > Starting sync for ${team}"
        echo " > ........................................"
        github_org_sync_team "${ORG}" "${team}" "${TEAM_JSON}"
        github_org_sync_parent_team "${ORG}" "${team}" "${TEAM_JSON}"
        github_org_sync_repositories "${ORG}" "${team}" "${TEAM_JSON}"

    done <<< "${TEAMS}"

    while read -r member
    do
        echo ""
        echo " >"
        echo " > Starting sync for ${member}"
        echo " > ........................................"
        github_org_sync_membership "${ORG}" "${member}" "${TEAM_JSON}"

    done <<< "${MEMBERS}"
}
