#!/bin/bash

go=0
dc=0
pch=0

for arg in "$@"; do [[ ${arg,,} == --pch ]]            && { pch=1; break; }; done
for arg in "$@"; do [[ ${arg,,} == --generated-only ]] && { go=1;  break; }; done
for arg in "$@"; do [[ ${arg,,} == --deep-clean ]]     && { dc=1;  break; }; done

f() {
    fc=0
    test -e "$1" && fc=$(ls -R1 "$1" | sed -e "s/^.*:$//g" | sort | sed -e "s/ //g" | wc -l) || fc=0
    printf "Removing %5d %9s files from %s...\n" $fc $2 $1
    if (( fc > 0 )); then
        rm -rf $1
    fi
    return 0
}

if (( pch || dc )); then

  f "build/${1,,}/${2,,}/${3,,}/pch" pch
  if (( dc == 0 )); then
    echo "Done.           Sleeping zzzzzz...."
    sleep 5
    exit 0
  fi
fi

if (( go || dc )); then

  f "build/${1,,}/${2,,}/${3,,}/_deps/generated" "generated"
  if (( dc == 0 )); then
    echo "Done.           Sleeping zzzzzz...."
    sleep 5
    exit 0
  fi
fi

f "build/${1,,}/${2,,}/${3,,}" "build"
f "out/${1,,}/${2,,}/${3,,}"   "out"
f "/home/geoffrey/dev/stage/${1,,}/${2,,}/${3,,}" "staged"
mkdir -p /home/geoffrey/dev/stage/${1,,}/${2,,}/${3,,}

if (( dc )); then

  f "/home/geoffrey/dev/archives/${1,,}/${2,,}/${3,,}" "archived"
  f "external/${1,,}/${2,,}/${3,,}" "external"
  mkdir -p /home/geoffrey/dev/archives/${1,,}/${2,,}/${3,,}

fi

echo "Done.           Sleeping zzzzzz...."
sleep 5

