#!/bin/bash

# doc deploy_trackid {
#
# DESCRIPTION
#   deploy_trackid - Deploys TRACKID of IMAGEID to TARGET
#
# USAGE
#   deploy_trackid <path/to/git/dir> <path/to/target> <path/to/db/file> <IMAGEID> <TRACKID_1> [<TRACKID_2>] [<...>]
#
# }

deploy_trackid() {
    ## Argument parsing
    local GIT_DIR="${1}"
    local TARGET="${2}"
    local DB_FILE="${3}"
    local IMAGEID="${4}"
    local TRACKID="${5}"


    ## Path and metadata parsing 
    local TRACKNO=$(print_track_no ${DB_FILE} ${IMAGEID} ${TRACKID})
    local FUTURE_META="$(print_future_meta ${IMAGEID}.tags ${TRACKNO})"
    local FUTURE_PATH="${TARGET}/$(print_future_path$ ${FUTURE_META}})"
    local PRESENT_PATH="${TARGET}/$(print_future_path ${IMAGEID} ${TRACKNO} ${DB_FILE})"
    local PRESENT_META="$(print_future_meta ${PRESENT_PATH})"
    local ROW_NO==$(_cfg query '$2=="'${IMAGEID}'" && $3=="'${TRACKID}'"' ${DB_FILE})

    # If the track is selected, we will check if the trackid has already been deployed, if not deploy. If the metadata to be
    # applied is different than what's deployed, apply new metadata. If the path has changed, move file to new path.
    if is_selected ${DB_FILE} ${IMAGEID} ${TRACKID}; then
        if [[ -z "${PRESENT_PATH}" ]]; then
            deploy_gen ${GIT_DIR} ${IMAGEID} ${TRACKNO}           
            local PRESENT_PATH="${GIT_DIR}/output.flac"
        fi

        if [[ "${PRESENT_META}" != "${FUTURE_META}" ]]; then
            [[ -z "${PRESENT_META}" ]] || metaflac --remove-all ${PRESENT_PATH}
            awk 'BEGIN {RS=";"}{print $0}' <<< ${FUTURE_META} | head -n -1 | metaflac --import-tags-from=- --import-picture-from="${GIT_DIR}/${IMAGEID}.jpg" "${PRESENT_PATH}"
        fi 

        if [[ "${PRESENT_PATH}" != "${FUTURE_PATH}" ]]; then
            mkdir -p "$(dirname "${FUTURE_PATH}")"
            mv "${PRESENT_PATH}" "${FUTURE_PATH}"
            _cfg change TARGET_PATH ${ROW_NO} "${FUTURE_PATH}" ${DB_FILE}
        fi

    else
        if [[ ! -z "${PRESENT_PATH}" ]]; then
            rm "${PRESENT_PATH}"
            _cfg change TARGET_PATH ${ROW_NO} ""
        fi 
    fi
    return 0
}
