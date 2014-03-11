#!/bin/sh
###########

mailfile=$1

function cleanUp () {
    rm -fr $tmp_path
}

# unzip zip files and find executable
unpack() {
    local file=""
    for file in "$@"
    do
        if [ "${file%.[zZ][iI][pP]}" != "${file}" ]
        then
            unzip -o "$file" >/dev/null
            rm "$file"
        elif [ "${file%.[rR][aA][rR]}" != "${file}" ]
        then
            unrar e "$file" >/dev/null
            rm "$file"
        elif [ -f "${file}" ]
        then
            unpack ${file}/*
            rm -rf ${file}
        elif [ "${file%.[eE][xX][eE]}" != "${file}" ]
        then
            exit 10
        elif [ "${file%.[cC][oO][mM]}" != "${file}" ]
        then
            exit 10
        elif [ "${file%.[bB][aA][tT]}" != "${file}" ]
        then
            exit 10
        elif [ "${file%.[cC][mM][dD]}" != "${file}" ]
        then
            exit 10
        elif [ "${file%.[pP][iI][fF]}" != "${file}" ]
        then
            exit 10
        elif [ "${file%.[sS][cC][fFrRtT]}" != "${file}" ]
        then
            exit 10
        elif [ "${file%.[vV][bB][sS]}" != "${file}" ]
        then
            exit 10
        fi
    done
}

trap cleanUp EXIT

tmp_path=/var/tmp/smc-$$
mkdir -p --mode=0777 "$tmp_path"
cd "$tmp_path"
/usr/bin/ripmime --unique_names -d "$tmp_path" -i "$mailfile"

unpack *
unpack *
unpack *

exit 0
