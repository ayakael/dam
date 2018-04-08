#!/bin/bash
source /usr/lib/bash/bunc
IFS='	
'

sec2min() {
    local secList=("${@}")
    for sec in ${secList[@]}; do
        MIN=$(($sec%3600/60))
        SEC=$(($sec%60))
        [[ ${sec} -ge 3600 ]] && MIN=$(( ${MIN} + 60 ))
        printf '%02d:%02d:%02d\n' ${MIN} ${SEC} 00
    done
}

med_convert() {
    local EXT="${1}"; shift 1
    local fileList=("${@}")
    for file in ${fileList[@]}; do
        local FILE_EXT="$(echo "${file}" | sed 's|.*\.||')"
        ffmpeg -loglevel 24 -y -i "${file}" "$(echo ${file} | sed "s|${FILE_EXT}|${EXT}|")" >${STDERR} 2>&1
        [[ $? -ne 0 ]] && local ERROR=true   
    done
    [[ ${ERROR} ]] && return 1 || return 0
}

file_name() {
    local SOURCE="${1}"
    local SHA256="${2}"
    echo "SHA256-${SOURCE}--${SHA256}"
}

cdcount() {
    local FOLDER="${1}"
    local tracknoList=($(find "${1}"/* -type f -follow -not -name '*cover*' -not -name '*.pdf' -printf '%f\n' | cut -d' ' -f1))

    for trackno in ${tracknoList[@]}; do
        if [[ ${trackno} == *.* ]]; then
            local CDCOUNT=$(echo ${trackno} | cut -d. -f1)
        else
            local CDCOUNT=1
        fi
    done
    echo ${CDCOUNT}
}

ismp3() {
    local fileList=("${@}")
    for file in ${fileList[@]}; do
        local FILE_EXT="$(echo "${file}" | sed 's|.*\.||')"
        [[ "${FILE_EXT}" == "mp3" ]] && local MP3=0 || local MP3=1
    done
    [[ ${MP3} -eq 0 ]] && return 0 || return 1
}

addbom() {
    local fileList=("${@}")
    for file in ${fileList[@]}; do
        sed -i '1s/^\(\xef\xbb\xbf\)\?/\xef\xbb\xbf/' "${file}"
    done
    return 0
}

gen_breaklist() {
    local fileList=("${@}")
    local breakList=(0:00:00)
    if shntool cue ${fileList[@]} >/dev/null 2>&1; then
        shntool cue ${fileList[@]} > joined.cue
        local breakList=(${breakList[@]}  $(cuebreakpoints joined.cue | sed 's|\.|:|g'))
        rm joined.cue
    else
        local durList=($(soxi -D "${fileList[@]}"))
        local breaksecList=(0)
        local COUNT=0
        while [[ $(( ${COUNT} + 1 )) -lt ${#durList[@]} ]]; do
            local breaksecList=(${breaksecList[@]}	$(awk "BEGIN {printf ${breaksecList[-1]} + ${durList[${COUNT}]}}" ))
            local COUNT=$(( ${COUNT} + 1 ))
        done
        local breaksecList=($(printf "%s\n" ${breaksecList[@]} | sed 's|\..*||g'))
        local breakList=($(sec2min ${breaksecList[@]})) 
    fi
    printf '%s\n' ${breakList[@]}
}

gen_image() {
    local fileList=("${@}")
    if [[ ${#fileList[@]} -eq 1 ]]; then
        cat ${fileList[@]} > joined.flac
    else
        shntool join -O always ${fileList[@]} -o flac
        if [[ $? -ne 0 ]]; then
            med_convert wav ${fileList[@]}
            [[ $? -ne 0 ]] && { echo "Image generation failed with fatal errors"; return 1; }
            echo ${fileList[@]}
            fileList=($(printf '%s\n' ${fileList[@]} | sed 's|flac|wav|'))
            echo ${fileList[@]}
            shntool join -O always ${fileList[@]} -o flac
            [[ $? -ne 0 ]] && { echo "Image generation failed with fatal errors"; return 1; }
            echo "Image generated with non-fatal error"; return 2
        fi
    fi
    echo "Image generated with no errors"; return 0
}

gen_cue() {
    local FILE_NAME="${1}"
    local METADATA="${2}"; shift 2
    local fileList=("${@}")
    
    # Metadata Parsing
    metadataList=($(echo ${METADATA} | sed 's|;|	|g'))
    for metadata in ${metadataList[@]}; do
        eval local ${metadata} 
    done

    for file in ${fileList[@]}; do
	    local trackList=(${trackList[@]}	$(echo ${file} | sed 's|.*/||' | awk 'BEGIN{ FS="-"; OFS=":"}{$1=""}{print $0}' | sed 's|: ||'))
    done

    # Generates breaklist
    breakList=($(gen_breaklist ${fileList[@]}))

    [[ ! -z "${META_DATE+x}" ]] && echo "REM DATE ${META_DATE}"
    [[ ! -z "${META_COMPOSER+x}" ]] && echo "PERFORMER \"${META_COMPOSER}\""
    [[ ! -z "${META_CONDUCTOR+x}" ]] && echo "REM CONDUCTOR \"${META_CONDUCTOR}\""
    [[ ! -z "${META_ORCHESTRA+x}" ]] && echo "REM ORCHESTRA \"${META_ORCHESTRA}\""
    [[ ! -z "${META_ARTIST+x}" ]] && echo "PERFORMER \"${META_ARTIST}\""
    [[ ! -z "${META_ALBUM+x}" ]] && echo "TITLE \"${META_ALBUM}\""
    echo "FILE \"${FILE_NAME}.flac\" WAVE"
    local COUNT=0
    while [[ ${COUNT} -lt ${#breakList[@]} ]]; do
        [[ ${COUNT} -le 8 ]] && local TRACK_NO="0$(( ${COUNT} + 1 ))" || local TRACK_NO="$(( ${COUNT} + 1 ))"
        echo "  TRACK ${TRACK_NO} AUDIO" 
        echo "    TITLE \"${trackList[${COUNT}]}\""
        echo "    INDEX 01 ${breakList[${COUNT}]}"
        local COUNT=$(( ${COUNT} + 1 ))
    done
    return 0
}

gen_mtag() {
    local FILE_NAME="${1}"
    local METADATA="${2}"; shift 2
    local fileList=("${@}")

    # Metadata Parsing
    metadataList=($(echo ${METADATA} | sed 's|;|    |g'))
    for metadata in ${metadataList[@]}; do
        eval local ${metadata} 
    done

    for file in ${fileList[@]}; do
	    local trackList=(${trackList[@]}	$(echo ${file} | sed 's|.*/||' | awk 'BEGIN {FS="-"; OFS=":"}{$1=""}{print $0}' | sed 's|: ||'))
    done
    echo "["
    local COUNT=0
    while [[ ${COUNT} -lt ${#trackList[@]} ]]; do
        [[ ${COUNT} -ne 0 ]] && echo "    },"
        echo "   {"
        echo "      \"@\" : \"${FILE_NAME}.cue|$(( ${COUNT} + 1 ))\","
        if [[ ${COUNT} -eq 0 ]]; then
            [[ ! -z "${META_ALBUM+x}" ]] && echo "      \"ALBUM\" : \"${META_ALBUM}\","
            [[ ! -z "${META_ARTIST+x}" ]] && echo "      \"ARTIST\" : \"${META_ARTIST}\","
            [[ ! -z "${META_ALBUMARTIST+x}" ]] && echo "      \"ALBUMARTIST\" : \"${META_ALBUMARTIST}\","
            [[ ! -z "${META_COMPOSER+x}" ]] && echo "      \"COMPOSER\" : \"${META_COMPOSER}\","
            [[ ! -z "${META_CONDUCTOR+x}" ]] && echo "      \"CONDUCTOR\" : \"${META_CONDUCTOR}\","
            [[ ! -z "${META_ORCHESTRA+x}" ]] && echo "      \"ORCHESTRA\" : \"${META_ORCHESTRA}\","
            [[ ! -z "${META_DATE+x}" ]] && echo "      \"DATE\" : \"${META_DATE}\","
            [[ ! -z "${META_GENRE+x}" ]] && echo "      \"GENRE\" : \"${META_GENRE}\","
            [[ ! -z "${META_DISCNUM+x}" ]] && echo "      \"DISCNUMBER\" : \"${META_DISCNUM}\","
            [[ ! -z "${META_DISCTOT+x}" ]] && echo "      \"TOTALDISCS\" : \"${META_DISCTOT}\","
            echo "      \"TOTALTRACKS\" : \"${#trackList[@]}\","
            echo "      \"BATCHNUMBER\" : \"0\","
        fi    
        echo "      \"TITLE\" : \"${trackList[${COUNT}]}\","
        echo "      \"TRACKNUMBER\" : \"$(( ${COUNT} + 1 ))\""
        local COUNT=$(( ${COUNT} + 1 ))
    done
    echo "    }"
    echo "]"
    return 0
}

gen_metadata() {
    local FOLDER="${1}"
    local DISC_NO="${2}"
    local META_DISCTOT="${3}"
    local META_GENRE=$(echo ${FOLDER} | cut -d/ -f1)
    echo -n "META_GENRE=\"${META_GENRE}\";"
    echo -n "META_DISCTOT=${META_DISCTOT};"
    echo -n "META_DISCNUM=${DISC_NO};"
    if [[ "${META_GENRE}" == "Classical" ]] && [[ "$(echo ${FOLDER} | cut -d/ -f5 | cut -d- -f2 |  sed 's| ||')" != "" ]]; then
        echo -n "META_COMPOSER=\"$(echo ${FOLDER} | cut -d/ -f2)\";"
        echo -n "META_ALBUM=\"$(echo ${FOLDER} | cut -d/ -f3)\";"
        echo -n "META_CONDUCTR=\"$(echo ${FOLDER} | cut -d/ -f4)\";"
        echo -n "META_DATE=\"$(echo ${FOLDER} | cut -d/ -f5 | cut -d- -f1 | rev | sed 's| ||' | rev)\";"
        echo -n "META_ORCHESTRA=\"$(echo ${FOLDER} | cut -d/ -f5 | cut -d- -f2 |  sed 's| ||')\";"
    elif [[ "${META_GENRE}" == "Soundtrack" ]]; then
        echo -n "META_ALBUM=\"$(echo ${FOLDER} | cut -d/ -f2)\""
    else        
        echo -n "META_ARTIST=\"$(echo ${FOLDER} | cut -d/ -f2)\";"
        echo -n "META_DATE=\"$(echo ${FOLDER} | cut -d/ -f3 | cut -d- -f1 | rev | sed 's| ||' | rev)\";"
        echo -n "META_ALBUM=\"$(echo ${FOLDER} | cut -d/ -f3 | sed 's|.*\ -\ ||')\";"
    fi
    return 0
}

gen_cover() {
    local FOLDER="${1}"
    [[ -f "${FOLDER}/full_cover.tiff" ]] && local IMAGE="full_cover.tiff" || local IMAGE="cover.jpg"
    convert "${FOLDER}/${IMAGE}" jpeg:-
    return 0
}

gen() {
    local ROOT="${1}"
    local SUBFOL="${2}"
    local FOLDER="${ROOT}/${SUBFOL}"
    local CDCOUNT="$(cdcount "${FOLDER}")"
    local COUNT=1
    local SOURCE=FLAC

    while [[ ${COUNT} -le ${CDCOUNT} ]]; do

        # Generates file list depending on CD count
        if [[ "${CDCOUNT}" == 1 ]]; then
            local fileList=($(find "${FOLDER}"/* \( -name '*.flac' -or -name '*.mp3' -or -name '*.wav' \) -printf '%p\t'))
        else
            local fileList=($(find "${FOLDER}"/${COUNT}.* \( -name '*.flac' -or -name '*.mp3' \) -printf '%p\t'))
        fi

        if ismp3 ${fileList[@]}; then
            _msg EXEC "Converting MP3 files to FLAC"
            med_convert flac ${fileList[@]} >${STDERR} 2>&1
            [[ $? -eq 0 ]] && _msg OK || _msg WARN
            local SOURCE=MP3
        fi
        [[ "${SOURCE}" == "MP3" ]] && local fileList=($(printf "%s\t" ${fileList[@]} | sed 's|mp3|flac|g'))
        
        # Generates image
        _msg EXEC "Generating data for ${FOLDER} disk ${COUNT} of ${CDCOUNT}"
        gen_image ${fileList[@]} >${STDERR} 2>&1
        local EXIT="$?"
        if [[ ${EXIT} -eq 0 ]]; then 
            _msg OK
        elif [[ ${EXIT} -eq 2 ]]; then
            _msg WARN
        else
            _msg FAIL
            local COUNT=$(( ${COUNT} + 1 ))
            continue
        fi

        # Determines file name based on image's CHKSUM and acts accordingly
        metaflac --remove-all --dont-use-padding joined.flac
        local SHA256=$(sha256sum joined.flac | cut -d' ' -f1)
        local FILE_NAME=$(file_name ${SOURCE} ${SHA256})
        mv joined.flac ${FILE_NAME}.flac
        
        # Generates METADATA, CUE and MTAG
        _msg EXEC "Generating metadata for ${FOLDER} disk ${COUNT} of ${CDCOUNT}"
        local METADATA="$(gen_metadata "${SUBFOL}" ${COUNT} ${CDCOUNT})"
        gen_cue "${FILE_NAME}" ${METADATA} ${fileList[@]} > ${FILE_NAME}.cue
        [[ $? -ne 0 ]] && _msg WARN
        addbom ${FILE_NAME}.cue
        gen_mtag "${FILE_NAME}" ${METADATA} ${fileList[@]} > ${FILE_NAME}.tags
        [[ $? -ne 0 ]] && _msg WARN
        addbom ${FILE_NAME}.tags
        gen_cover "${FOLDER}" > ${FILE_NAME}.jpg
        [[ $? -ne 0 ]] && _msg WARN || _msg OK

        local COUNT=$(( ${COUNT} + 1 ))
    done
    
}


ROOT="${1}"; shift 1
dirList=("${@}")
for dir in ${dirList[@]}; do
    folderList=($(find ${ROOT}/${dir} -name '*cover*' -printf '%h\n' | awk '!seen[$0]++' | sed "s|${ROOT}/||g"))
    for folder in ${folderList[@]}; do
        gen ${ROOT} "${folder}"
#echo ${folder}
    done
done
