#!/bin/bash

go=0
dc=0
pch=0

shopt -s nocasematch

p1=$(tr '[:upper:]' '[:lower:]' <<< "$1")
p2=$(tr '[:upper:]' '[:lower:]' <<< "$2")
p3=$(tr '[:upper:]' '[:lower:]' <<< "$3")

for arg in "$@"; do [[ $arg == --pch ]]            && { pch=1; break; }; done
for arg in "$@"; do [[ $arg == --generated-only ]] && { go=1;  break; }; done
for arg in "$@"; do [[ $arg == --deep-clean ]]     && { dc=1;  break; }; done

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

  f "build/$p1/$p2/$p3/pch" pch
  if (( dc == 0 )); then
    echo "Done.           Sleeping zzzzzz...."
    sleep 5
    exit 0
  fi
fi

if (( go || dc )); then

  f "build/$p1/$p2/$p3/_deps/generated" "generated"
  if (( dc == 0 )); then
    echo "Done.           Sleeping zzzzzz...."
    sleep 5
    exit 0
  fi
fi

f "build/$p1/$p2/$p3" "build"
f "out/$p1/$p2/$p3"   "out"
f "/home/geoffrey/dev/stage/$p1/$p2/$p3" "staged"
mkdir -p ~/dev/stage/$p1/$p2/$p3

if (( dc )); then

  f "/home/geoffrey/dev/archives/$p1/$p2/$p3" "archived"
  f "external/$p1/$p2/$p3" "external"
  mkdir -p ~/dev/archives/$p1/$p2/$p3

fi

echo "Done.           Sleeping zzzzzz...."
sleep 5

