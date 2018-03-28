#!/bin/bash

EXEC=dam

echo -e "#!/bin/bash\n" > ${EXEC}

for file in $(find src/ -type f); do
    awk '!/^ *#/ && NF' ${file} >> ${EXEC}
done
echo 'eval $@' >> ${EXEC}
