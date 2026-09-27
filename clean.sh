#!/bin/bash
if [ "${PROJECTS}" == "" ]; then
  echo 'Set the envvar "PROJECTS" to your base projects folder'
  exit 1
fi

if (( $# < 3 )); then
  echo Usage: $0 PLATFORM BUILD_TYPE LINK_TYPE [ --other COMPANION_FOLDER ] [ --generated-only ] [ --deep-clean ] [ --pch ] [ --dry-run ]
  exit 0
fi

source $COMMONDIR/early.sh

go=0
dc=0
pch=0
num=0
dryrun=0

us=$(basename $(pwd))
them=""

p1=$(tr '[:upper:]' '[:lower:]' <<< "$1")
p2=$(tr '[:upper:]' '[:lower:]' <<< "$2")
p3=$(tr '[:upper:]' '[:lower:]' <<< "$3")

next_is_them=0
for arg in "$@"; do
  if (( next_is_them)); then
    next_is_them=0
    them="$arg"
  else
    arg_lc=$(tr '[:upper:]' '[:lower:]' <<< "$arg")
    case "$arg_lc" in
      --pch)            pch=1           ;;
      --generated-only) go=1            ;;
      --deep-clean)     dc=1            ;;
      --dry-run)        dryrun=1        ;;
      --other)          next_is_them=1  ;;
    esac
  fi
done

f() {
    fc=0
    test -e "$1" && fc=$(ls -R1 "$1" | sed -e "s/^.*:$//g" | sort | sed -e "s/ //g" | wc -l) || fc=0
    printf "Removing %5d %9s files from %s...\n" $fc $2 $1
    if (( fc > 0 )); then
        num=$((num + fc))
        if (( dryrun )); then
          echo rm -rf "$1"
        else
          rm -rf "$1"
        fi
    fi
    return 0
}

if (( pch || dc )); then

  f "$PROJECTS/$us/build/$p1/$p2/$p3/pch" pch

  if (( dc )); then
    test -n "$them" && f "$PROJECTS/$them/build/$p1/$p2/$p3/pch" pch || true;
  else
    printf "Removed  %5d %9s files. I'm tired now. Sleeping. Zzzzzz...." $num " "
    sleep 5
    exit 0
  fi
fi

if (( go || dc )); then

  f "$PROJECTS/$us/generated/$p1/$p2/$p3" "generated"

  if (( dc )); then
    test -n "$them" && f "$PROJECTS/$them/generated/$p1/$p2/$p3" "generated" || true
  else
    printf "Removed  %5d %9s files. I'm tired now. Sleeping. Zzzzzz...." $num " "
    sleep 5
    exit 0
  fi
fi

f "$PROJECTS/$us/build/$p1/$p2/$p3" "build"
f "$PROJECTS/$us/out/$p1/$p2/$p3"   "out"

if (( dc )); then

  test -n "$them" && f "$PROJECTS/$them/build/$p1/$p2/$p3" "build"  || true
  test -n "$them" && f "$PROJECTS/$them/out/$p1/$p2/$p3"   "out"    || true

  f "$HOME/dev/stage/$p1/$p2/$p3" "staged"
  f "$HOME/dev/archives/$p1/$p2/$p3" "archived"
  f "$PROJECTS/$us/external/$p1/$p2/$p3" "external"
  test -n "$them" && f "$PROJECTS/$them/external/$p1/$p2/$p3" "external" || true

  mkdir -p "$HOME/dev/archives/$p1/$p2/$p3"
  mkdir -p "$HOME/dev/stage/$p1/$p2/$p3"

fi

printf "Removed  %5d %9s files. I'm tired now. Sleeping. Zzzzzz...." $num " "
sleep 5
