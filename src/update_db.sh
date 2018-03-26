#!/bin/bash

# doc update_db {
#
# DESCRIPTION
#   update_db - Updates TARGET's DB_FILE with defined IMAGEIDs
#
# USAGE
#   update_db <path/to/git/dir> <path/to/target/dir> <path/to/db/file> <IMAGEID> <...>
#
# }

update_db() {
    local GITDIR="${1}"
    local TARGET="${2}"
    local DB_FILE="${3}"; shift 3
    local imageidList=(${@})

    for imageid in ${imageidList[@]}; do
        trackidList=($(awk 'BEGIN{FS="\" : \"";RS="\",\n * \""}{if($1=="TRACKID"){print $2}}'))
        for trackid in ${trackidList[@]}; do
            [[ -z $(_cfg query '$2=="'${imageid}'" && $3=="'${trackid}'"' ${DB_FILE}) ]] && _cfg insert true ${imageid} ${trackid}
        done
    done
}
