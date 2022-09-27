#!/bin/bash

mkdir -p subj1 subj2 subj3

. support_functions.sh



for name in subj*; do (
    cd $name

    title $name

    create_random() { for (( x=0; x<$1; x++ )); do echo $RANDOM; done > "$2"; }
    run "create stuff" \
        create_random 10 OUT:stuff

    sort_uniq() { sort -n "$1" | uniq > "$2"; }
    run "sort stuff and remove duplicates" \
        sort_uniq IN:stuff OUT:sorted

    run "create folder" \
        mkdir OUT:folder

    run "copy sorted into folder" \
        cp IN:sorted OUT:folder/sorted

) || ERROR "$name did not complete successfully"

done
