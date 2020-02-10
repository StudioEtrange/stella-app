#!/usr/bin/env bash


add_user() {
    local username="$1"
    local email="$2"

    local public_front=1
    curl -X PUT -d '{"username": "'$username'", "email": "'$email'", "public_front":"'${public_front}'"}' -H "Content-Type: application/json" $HEIMDALL_BACKEND_URL/users/
}

del_user() {

}

add_tag() {
    local user="$1"
    local title="$2"
    local color="$3"
    local auto_pinned=1
    local url=$(echo ${title} | sed -e "s/[^a-zA-Z0-9]?*/ /g" -e "s/\s\s*/-/g" -e 's/\(.*\)/\L\1/')
    local type=1
    
    curl -X PUT -d '{"user_id":"'${user}'", "title": "'${title}'", "color": "'${color}'", "url":"'${url}'", "pinned": "'${auto_pinned}'", "type":"'${type}'"}' -H "Content-Type: application/json" $HEIMDALL_BACKEND_URL/items/
}

del_tag() {

}

add_item() {
    local user="$1"
    local title="$2"
    local url="$3"
    local color="$4"
    local auto_pinned=1
    
    local type=0
    # TODO find the link between item and tag
    curl -X PUT -d '{"user_id":"'${user}'", "title": "'${title}'", "color": "'${color}'", "url":"'${url}'", "pinned": "'${auto_pinned}'", "type":"'${type}'"}' -H "Content-Type: application/json" $HEIMDALL_BACKEND_URL/items/
}
del_item() {

}