#!/bin/bash

EXEC=dam

test_function() {
    functionList=(${@})
    source src/env
    for function in ${functionList[@]}; do
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
    echo "VERSION=$(git describe --tags)"
    awk '!/^ *#/ && NF' src/env
}

gen_function() {
    functionList=(${@})    
    for function in ${functionList[@]}; do
        awk '!/^ *#/ && NF' ${function} 
    done
}

gen_parser() {
    awk '!/^ *#/ && NF' src/parser
}

test_function  $(find src/ -type f -not -name env -not -name parser)

gen_env > ${EXEC}
gen_help >> ${EXEC}
gen_function $(find src/ -type f -not -name env -not -name parser) >> ${EXEC}
gen_function $(find bunc/src/ -type f) >> ${EXEC}
gen_parser >> ${EXEC}

chmod +x ${EXEC}
