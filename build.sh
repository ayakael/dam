#!/bin/bash

EXEC=dam

echo -e "#!/bin/bash\n" > ${EXEC}

for file in src/env $(find bunc/src -type f) $(find src/ -type f -not -name env -not -name parser) src/parser; do
    awk '!/^ *#/ && NF' ${file} >> ${EXEC}
done

chmod +x ${EXEC}
