#!/bin/bash
EXEC=dam
while true; do
    case ${1} in
        --version)
            shift
            VERSION="${1}"
        ;;

        *)
            break
        ;;

    esac
    shift
done

if [[ ! -d .git ]] && [[ -z ${VERSION+x} ]]; then echo "Not in git environement, please specify version via --version argument"; exit 1; fi
[[ -z ${VERSION+x} ]] && VERSION=$(git describe --tags)

test_function() {
    local functionList=(${@})
    source src/env
    for function in ${functionList[@]}; do
        local dependencyList=($(grep "# DEPENDENCIES" ${function} | sed 's|# DEPENDENCIES||'))
        for dependency in ${dependencyList[@]}; do
            eval source ${dependency}
        done
        bash ${function}
    done
}

gen_help() {
    for file in $(find help/ -type f -printf "%P\n"); do
        echo -e "
            # ${file} help
            help_${file}() {
                echo -e \""
                cat help/${file} 
        echo -e "\"
            }"
    done

}

gen_env() {
    echo -e "#!/bin/bash\n" 
    echo "VERSION=${VERSION}"
    echo "REPO_VERSION=1"
    awk '!/^ *#/ && NF' src/env
}

gen_function() {
    local functionList=(${@})    
    for function in ${functionList[@]}; do
        awk '!/^ *#/ && NF' ${function} 
    done
}

gen_parser() {
    awk '!/^ *#/ && NF' src/parser
}

test_function  $(find src/ -type f -not -name env -not -name parser)
# test_function src/import_track

gen_env > ${EXEC}
gen_help >> ${EXEC}
gen_function $(find src/ -type f -not -name env -not -name parser) >> ${EXEC}
gen_function $(find bunc/src/ -type f) >> ${EXEC}
gen_parser >> ${EXEC}

echo ${@} >> ${EXEC}

chmod +x ${EXEC}
