#!/usr/bin/env bash

if [ "${PROJECTS}" == "" ]; then
  echo 'Set the envvar "PROJECTS" to your base projects folder'
  exit 1
fi

help() {
  [[ -n $1 ]] &&  { echo; echo "Error: ${1}"; }
  echo

  echo "Usage: [ --build-type=BUILD_TYPE | BUILD_TYPE ] [   Build Type or all build types if missing        *1"
  echo "       [ --folders=ONE&THE_OTHER ]                  Lists both project folders for --deep-clean     *3"
  echo "       [ --generated-only ]                         Only files created by yaml2code.py"
  echo "       [ --deep-clean ]                             Absolutely everything"
  echo "       [ --pch ]                                    Only the pch files (for when corruption)"
  echo "       [ --dry-run ]                                Just count files to be deleted, deletes nothing"
  echo
  echo " *1    If omitted, all BUILD_TYPE will be deleted"
  echo " *2    Only needed if a side-by-side build; if add_subdirectory there is only one build dir"
  exit 0
}

go=0
dc=0
pch=0
num=0
dry_run=

build=""

me=$(basename "$(pwd)")
us=""
them=""
ht=0
while (( $# != 0 )); do
  arg=$1
  arg2=$2
  arg_lc=$(tr '[:upper:]' '[:lower:]' <<< "$arg")
  shift
  case "$arg_lc" in
    --pch)            pch=1;;
    --generated-only) go=1;;
    --deep-clean)     dc=1;;
    --dry-run)        dry_run=1;;
    --help)           help;;
    --folders=*)      IFS=',' read -ra fo <<< "${arg#--folders=}";;
    --folders)        IFS=',' read -ra fo <<< "${arg2#--folders=}";     shift;;
    --build-type=*)   IFS=',' read -ra bt <<< "${arg#--build-type=}";;
    --build-type)     IFS=',' read -ra bt <<< "${arg2#--build-type=}";  shift;;
    *)                if [ "$arg_lc" == 'debug' ] || [ "$arg_lc" == 'release' ] ; then
                        n=${#bt[@]}; (( n == 0 )) && bt[0]=$arg_lc || help "BUILD_TYPE argument '$arg' ignored"
                      else
                        help "Unknown or duplicate argument '$arg'"
                      fi;;
  esac
done

(( ${#fo[@]} == 0 || ${#fo[@]} == 2 ))    || help "If provided, folders must have two folders"
(( ${#bt[@]} <= 1 )) && build=${bt[0]}    || help "Only one build-type can be specified. Omit it to delete all build-types"

if (( ${#fo[@]} == 0 )); then
 us=${me}
else
  if [[ "${fo[0]}" == "${me}" ]]; then
    us="${fo[0]}"
    them="${fo[1]}"
    ht=1
  elif [[ "${fo[1]}" == "${me}" ]]; then
    us="${fo[1]}"
    them="${fo[0]}"
    ht=1
  else
    help "Current directory ($me} is not one of folders (${fo[0]}, ${fo[1]})"
  fi
fi

p1=$(tr '[:upper:]' '[:lower:]' <<< "$build")

[[ -n $p1 ]] && { p1="/${p1}"; w1=${p1}; } || w1='/*'

ppath="${p1}"
wpath="${w1}"

f() {
    fc=0
    test -e "$1" && fc=$(ls -R1 "$1" | sed -e "s/^.*:$//g" | sort | sed -e "s/ //g" | wc -l) || fc=0
    printf "Removing %5d %9s files from %s\n" $fc $2 $1
    if (( fc > 0 )); then
        num=$((num + fc))
        (( ! dry_run )) && rm -rf "$1"
    fi
    return 0
}

bye() {
    printf "Removed %6d %9s files. I'm tired boss...\n" $num "total"
    exit 0
}

echo
(( dry_run )) && echo "Dry-run... No files will be deleted"
(( dc ))      && echo "Deep clean in progress..."
(( dry_run || dc )) && echo

# --pch or --deep-clean
((  pch || dc )) &&         f "$PROJECTS/$us/build$wpath/pch"   pch
(( (pch || dc)  && ht )) && f "$PROJECTS/$them/build$wpath/pch" pch
((  pch )) && bye

# --generated-only or --deep-clean
(( go || dc )) && f "$PROJECTS/$us/generated$ppath" "generated"
(( go || dc )) && [[ -n "$them" ]] && f "$PROJECTS/$them/generated$ppath" "generate"
(( go )) && bye

# Always
f "$PROJECTS/$us/build$ppath" "build"
f "$PROJECTS/$us/out$ppath"   "out"

# --deep-clean
if (( dc )); then

  f "$PROJECTS/$us/external$ppath"  "external"

  (( ht )) && f "$PROJECTS/$them/build$ppath"     "build"
  (( ht )) && f "$PROJECTS/$them/out$ppath"       "out"
  (( ht )) && f "$PROJECTS/$them/external$ppath"  "external"

  f "$HOME/dev/stage$ppath"         "stage"
  f "$HOME/dev/archives$ppath"      "archives"

  mkdir -p "$HOME/dev/archives$ppath"
  mkdir -p "$HOME/dev/stage$ppath"

fi

bye
