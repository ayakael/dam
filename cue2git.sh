#!/bin/bash
source /usr/lib/bash/bunc
IFS='	
'

file_name() {
    local SOURCE="${1}"
    local SHA256="${2}"
    echo "SHA256-${SOURCE}-${SHA256}"
}

fix_apos() {
    local fileList=("${@}")
    for file in ${fileList[@]}; do
        sed -i 's/\xc2\x92/\x27/g' "${file}"
        sed -i 's/\xc2\x85/\x2e\x2e\x2e/g' "${file}"
         sed -i 's/\xc2\x96/\x2d/g' "${file}"
    done
    return 0
}    

addbom() {
    local fileList=("${@}")
    for file in ${fileList[@]}; do
        sed -i '1s/^\(\xef\xbb\xbf\)\?/\xef\xbb\xbf/' "${file}"
    done
    return 0
}

deploy_split() {
    local FLAC="${1}"
    local CUE="${2}"

    ## breakpointList generator
    # Generates list with cuebreakpoints utility
    local breakpointList=($(cuebreakpoints "${CUE}" 2>/dev/null))

    # In the event that breakpointList is empty because image represents only one track, 
    # no split occurs, and returns a 0.
    [[ -z "${breakpointList[@]}" ]] && { cat "${FLAC}" > split-track01.flac; return 0; }
    
    # Attempts first split. If fails because of lack of CD quality file, retries with modified breakpointList
    if ! printf '%s\n' ${breakpointList[@]} | shntool split "${FLAC}" -o flac -O always ; then 
        printf '%s\n' ${breakpointList[@]} | sed s/$/0/ | shntool split "${FLAC}" -o flac -O always
        [[ $? -eq 0 ]] && return 2 || return 1
    fi
    return 0
}


gen_trackid() {
    FLAC="${1}"
    CUE="${2}"
    
    deploy_split ${FLAC} ${CUE} >/dev/null 2>&1
    local TOTALTRACKS="$(grep -e "TRACK [0-9][0-9] AUDIO" "${CUE}" | wc -l)"
    
    local COUNT=1
    while [[ ${COUNT} -le ${TOTALTRACKS} ]]; do
        local TRACKID="$(metaflac --list --block-number=0 $(printf "split-track%02d.flac" ${COUNT}) | awk 'BEGIN{FS=": "}{if($1=="  MD5 signature") {print $2}}')"
        printf "%s\t" ${TRACKID}
        rm $(printf "split-track%02d.flac" ${COUNT})
        local COUNT=$(( ${COUNT} + 1 ))
    done
}


gen_mtag() {
    local FILE_NAME="${1}"
    local METADATA="${2}"

    # Metadata Parsing
    metadataList=($(echo ${METADATA} | sed 's|;|    |g'))
    for metadata in ${metadataList[@]}; do
        eval local ${metadata} 
    done

    for file in ${fileList[@]}; do
        local trackList=(${trackList[@]}    $(echo ${file} | sed 's|.*/||' | cut -d- -f2 | sed 's| ||' | sed 's|\.flac||'))
    done
    echo "["
    local COUNT=0
    while [[ ${COUNT} -lt ${#titleList[@]} ]]; do
        [[ ${COUNT} -ne 0 ]] && echo "    },"
        echo "   {"
        echo "      \"@\" : \"${FILE_NAME}.cue|$(( ${COUNT} + 1 ))\","
        if [[ ${COUNT} -eq 0 ]]; then
            [[ ! -z "${ALBUM+x}" ]] && echo "      \"ALBUM\" : \"${ALBUM}\","
            [[ ! -z "${PERFORMER+x}" ]] && echo "      \"ARTIST\" : \"${PERFORMER}\","
            [[ ! -z "${META_COMPOSER+x}" ]] && echo "      \"COMPOSER\" : \"${META_COMPOSER}\","
            [[ ! -z "${META_CONDUCTOR+x}" ]] && echo "      \"CONDUCTOR\" : \"${META_CONDUCTOR}\","
            [[ ! -z "${META_ORCHESTRA+x}" ]] && echo "      \"ORCHESTRA\" : \"${META_ORCHESTRA}\","
            [[ ! -z "${DATE+x}" ]] && echo "      \"DATE\" : \"${DATE}\","
            [[ ! -z "${DISCNUMBER+x}" ]] && echo "      \"DISCNUMBER\" : \"${DISCNUMBER}\","
            [[ ! -z "${TOTALDISCS+x}" ]] && echo "      \"TOTALDISCS\" : \"${TOTALDISCS}\","
            [[ ! -z "${BATCHNUMBER+x}" ]] && echo "      \"BATCHNUMBER\" : \"${BATCHNUMBER}\","
            echo "      \"TOTALTRACKS\" : \"${#titleList[@]}\","
        fi    
        [[ ! -z "${performerList[${COUNT}]+x}" ]] && echo "      \"PERFORMER\" : \"${performerList[${COUNT}]}\","
        echo "      \"TITLE\" : \"${titleList[${COUNT}]}\","
        echo "      \"TRACKID\" : \"${trackidList[${COUNT}]}\","
        echo "      \"TRACKNUMBER\" : \"$(( ${COUNT} + 1 ))\""
        local COUNT=$(( ${COUNT} + 1 ))
    done
    echo "    }"
    echo "]"
    return 0
}

cueparser() {
    local FLAC="${1}"
    local CUE="${2}"
    dos2unix -q -R  "${CUE}" 

    ## [Input] metaList generator
    # Generates lists that are later used for the parsing of the cuesheet. This is necessary
    # because cue sheets are have two sections: a general metadata section that applies to the
    # whole disc, and a track-specific section that applies to each track. PERFORMER defined 
    # in the general section gets overriden by a PERFORMER defined in a track, thus it is 
    # important to seperate the two. Another thing of import is seperating the different tracks
    # so they can be parsed as seperate elements. The trackmetaList uses tr to remove the new
    # line, and then uses awk to have every line have a specific track's information
    local trackmetaList=($( sed -n '/TRACK 01/,$p' ${CUE} | tr -d '\n' | awk 'BEGIN {RS="TRACK"}{print $0}' | tail -n +2))
    local trackidList=($(gen_trackid ${FLAC} ${CUE}))

    # [Output] variable generator
    echo -n "PERFORMER=\"$(sed 's|\ \ .*||' "${CUE}" | grep -a "PERFORMER" | sed 's|PERFORMER ||' | sed 's|\"||g')\";"
    echo -n "ALBUM=\"$(sed 's|\ \ .*||' "${CUE}" | grep  -a "TITLE" | sed 's|TITLE ||' | sed 's|\"||g')\";"
    echo -n "DATE=$(sed 's|\ \ .*||' "${CUE}" | grep -a "REM DATE" | sed 's|REM DATE ||');"
    echo -n "DISCNUMBER=$(sed 's|\ \ .*||' "${CUE}" | grep -a "REM DISCNUMBER" | sed 's|REM DISCNUMBER ||');"
    echo -n "TOTALDISCS=$(sed 's|\ \ .*||' "${CUE}" | grep -a "REM TOTALDISCS" | sed 's|REM TOTALDISCS ||');"
    local COUNT=0
    for trackmeta in ${trackmetaList[@]}; do
        echo -n "titleList[${COUNT}]=\"$(echo ${trackmeta} | awk 'BEGIN {RS="    "}{print $0}' | grep -a TITLE | sed 's|TITLE ||' | sed 's|\"||g')\";"
        echo -n "performerList[${COUNT}]=\"$(echo ${trackmeta} | awk 'BEGIN {RS="    "}{print $0}' | grep -a PERFORMER | sed 's|PERFORMER ||' | sed 's|\"||g')\";"
        echo -n "trackidList[${COUNT}]=\"${trackidList[${COUNT}]}\";"
        local COUNT=$(( ${COUNT} + 1 ))
    done
}

gen_cover() {
    local FOLDER="${1}"
    [[ -f "${FOLDER}/folder.jpg" ]] && convert "${FOLDER}/folder.jpg" "${FOLDER}/folder.png" || { convert -size 480x480 xc:white "${FOLDER}/folder.png"; local ERROR=1; }
    cat "${FOLDER}/folder.png"
    [[ ${ERROR} -eq 1 ]] && return 1
    local IMG_SIZE="$(identify -format "%wx%h" "${FOLDER}/folder.jpg")"
    local IMG_WIDTH=$(echo ${IMG_SIZE} | cut -dx -f1)
    local IMG_HEIGHT=$(echo ${IMG_SIZE} | cut -dx -f2)
    if [[ ${IMG_WIDTH} -lt 480 ]] && [[ ${IMG_HEIGHT} -lt 480 ]]; then return 2; fi
    return 0
}

gen() {
    local FOLDER="${1}"
    _msg EXEC "Processing ${FOLDER}"
    local flacList=($(find "${FOLDER}" -name '*.flac' | sed 's|.flac||'))
    [[ ${#flacList[@]} -eq 0 ]] && { _msg FAIL "No such file or directory"; return 1; }
    
    for flac in ${flacList[@]}; do
        # Sanity check
        [[ -f "${flac}.cue" ]] || { _msg FAIL "No cue file present"; return 1; }
        [[ -f "${flac}.accurip" ]] || { _msg FAIL "No accurip file present"; return 1; }
        [[ -f "${flac}.log" ]] || { _msg FAIL "No EAC log file present"; return 1; }

        # Determines file name based on image's CHKSUM and acts accordingly
        cat ${flac}.flac > output.flac 2>/dev/null
        metaflac --remove-all --dont-use-padding "output.flac"
        local SHA256=$(sha256sum ${flac}.flac 2>/dev/null | cut -d' ' -f1)
        local SOURCE=$(grep "CTDB TOCID:" ${flac}.accurip 2>/dev/null | cut -d' ' -f3 | sed 's|]||')
        local FILE_NAME=$(file_name ${SOURCE} ${SHA256})
        mv "output.flac" ${FILE_NAME}.flac > /dev/null 2>&1
        cat "${flac}.cue" | iconv -f ISO-8859-1 -t UTF-8 | sed '1s/^\(\xef\xbb\xbf\)\?/\xef\xbb\xbf/' |  awk "!/FILE/{print} /FILE/{print \"FILE ${FILE_NAME}.flac WAVE\"}" > ${FILE_NAME}.cue 2> /dev/null
        cat "${flac}.accurip" | iconv -f ISO-8859-1 -t UTF-8  > ${FILE_NAME}.accurip
        cat "${flac}.log" | iconv -f ISO-8859-1 -t UTF-8  > ${FILE_NAME}.log        
        addbom ${FILE_NAME}.cue

        # Generates METADATA and MTAG
        local METADATA="$(cueparser ${FILE_NAME}.flac ${FILE_NAME}.cue);BATCHNUMBER=$(echo "${FOLDER}" | awk 'BEGIN{RS="/";}{print $0}' | grep batch | sed 's|.*_|_|' | sed -e 's/_0*//g');"
        gen_mtag "${FILE_NAME}" ${METADATA} > ${FILE_NAME}.tags
        addbom ${FILE_NAME}.tags
        fix_apos ${FILE_NAME}.tags
        gen_cover "${FOLDER}" > ${FILE_NAME}.png
        local EXIT="$?"
        if [[ ${EXIT} -eq 1 ]]; then
            _msg WARN "No folder.jpg in directory. Placeholder created"
        elif [[ ${EXIT} -eq 2 ]]; then
            _msg WARN "folder.jpg is under 480x480 in quality"
        else 
            _msg OK
        fi

    done
}

dirList=("${@}")
for dir in ${dirList[@]}; do
    folderList=($(find "${dir}" -name '*.cue' -printf '%h\n' | awk '!seen[$0]++'))
    for folder in ${folderList[@]}; do
        gen "${folder}"
    done
done
