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

  f "~/dev/projects/Libs/build/$p1/$p2/$p3/pch" pch
  f "~/dev/projects/MyCare/build/$p1/$p2/$p3/pch" pch
  if (( dc == 0 )); then
    echo "Done.           Sleeping zzzzzz...."
    sleep 5
    exit 0
  fi
fi

if (( go || dc )); then

  f "~/dev/projects/Libs/generated/$p1/$p2/$p3" "generated"
  f "~/dev/projects/MyCare/generated/$p1/$p2/$p3" "generated"

  if (( dc == 0 )); then
    echo "Done.           Sleeping zzzzzz...."
    sleep 5
    exit 0
  fi
fi

f "~/dev/projects/Libs/build/$p1/$p2/$p3" "build"
f "~/dev/projects/MyCare/build/$p1/$p2/$p3" "build"
f "~/dev/projects/Libs/out/$p1/$p2/$p3"   "out"
f "~/dev/projects/MyCare/out/$p1/$p2/$p3"   "out"

if (( dc )); then

  f "~/dev/stage/$p1/$p2/$p3" "staged"
  f "~/dev/archives/$p1/$p2/$p3" "archived"
  f "~/dev/projects/Libs/external/$p1/$p2/$p3" "external"
  f "~/dev/projects/MyCare/external/$p1/$p2/$p3" "external"
  mkdir -p ~/dev/archives/$p1/$p2/$p3
  mkdir -p ~/dev/stage/$p1/$p2/$p3

fi

echo "Done.           Sleeping zzzzzz...."
sleep 5

