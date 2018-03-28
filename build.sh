#!/bin/bash

EXEC=dam

echo -e "#!/bin/bash\n" > ${EXEC}

for file in src/env $(find src/ -type f -not -name env -not -name parser) src/parser; do
    awk '!/^ *#/ && NF' ${file} >> ${EXEC}
done


