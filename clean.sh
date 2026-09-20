#!/bin/bash
if [ "${PROJECTS}" == "" ]; then
  echo 'Set the envvar "PROJECTS" to your base projects folder'
  exit 1
fi

us=$(basename $(pwd))
if [ "$us" == "MyCare" ]; then
  them="Libs"
elif [ "$us" == "Libs" ]; then
  them="MyCare"
else
  echo "Where am I? Current directory should be 'MyCare' or 'Libs'"
  exit 1
fi

go=0
dc=0
pch=0
num=0

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
        num=$((num + fc))
        rm -rf $1
    fi
    return 0
}

if (( pch || dc )); then

  f "$PROJECTS/Libs/build/$p1/$p2/$p3/pch" pch

  if (( dc )); then
    f "$PROJECTS/$them/build/$p1/$p2/$p3/pch" pch
  else      Removing .
    printf "Done.    %5d files removed. I'm tired now. Sleeping. Zzzzzz...." $num
    sleep 5
    exit 0
  fi
fi

if (( go || dc )); then

  f "$PROJECTS/$us/generated/$p1/$p2/$p3" "generated"

  if (( dc )); then
    f "$PROJECTS/$them/generated/$p1/$p2/$p3" "generated"
  else
    printf "Done.    %5d files removed. I'm tired now. Sleeping. Zzzzzz...." $num
    sleep 5
    exit 0
  fi
fi

f "$PROJECTS/$us/build/$p1/$p2/$p3" "build"
f "$PROJECTS/$us/out/$p1/$p2/$p3"   "out"

if (( dc )); then

  f "$PROJECTS/$them/build/$p1/$p2/$p3" "build"
  f "$PROJECTS/$them/out/$p1/$p2/$p3"   "out"

  f "~/dev/stage/$p1/$p2/$p3" "staged"
  f "~/dev/archives/$p1/$p2/$p3" "archived"
  f "$PROJECTS/$us/external/$p1/$p2/$p3" "external"
  f "$PROJECTS/$them/external/$p1/$p2/$p3" "external"

  mkdir -p ~/dev/archives/$p1/$p2/$p3
  mkdir -p ~/dev/stage/$p1/$p2/$p3

fi

printf "Done.    %5d files removed. I'm tired now. Sleeping. Zzzzzz...." $num
sleep 5

