#!/usr/bin/env bash

if [ "${PROJECTS}" == "" ]; then
  echo 'Set the envvar "PROJECTS" to your base projects folder'
  exit 1
fi

help() {
  [[ -n $1 ]] &&  { echo; echo "Error: ${1}"; }
  echo
  echo "Usage: [ --platform=PLATFORM | PLATFORM ]  [          Platform or all platforms if missing         *1,*2"
  echo "         [ --build-type=BUILD_TYPE | BUILD_TYPE ]  [  Build Type or all build types if missing     *1,*3,*5"
  echo "            [ --link-type=LINK_TYPE | LINK_TYPE ]]]   Link type or all link types if missing       *1,*4,*6"
  echo "       [ --folders=ONE&THE_OTHER ]                    Lists both project folders for --deep-clean"
  echo "       [ --generated-only ]                           Only files created by yaml2code.py"
  echo "       [ --deep-clean ]                               Absolutely everything"
  echo "       [ --pch ]                                      Only the pch files (for when corruption)"
  echo "       [ --dry-run ]                                  Just count files to be deleted, deletes nothing"
  echo
  echo " *1    If the keyword is given, PLATFORM, BUILD_TYPE, and LINK_TYPE can be in any order anywhere in the command"
  echo "       If the keyword is omitted, PLATFORM, BUILD_TYPE, and LINK_TYPE must be in that order"
  echo " *2    If omitted, all PLATFORM, BUILD_TYPE, and LINK_TYPE will be deleted"
  echo " *3    If omitted, all BUILD_TYPE and LINK_TYPE will be deleted"
  echo " *4    If omitted, all LINK_TYPE will be deleted"
  echo " *5    BUILD_TYPE cannot be given unless PLATFORM is also given"
  echo " *6    LINK_TYPE  cannot be given unless both PLATFORM and BUILD_TYPE are also given"
  exit 0
}

go=0
dc=0
pch=0
num=0
dry_run=

platform=""
build=""
link=""

me=$(basename "$(pwd)")
us=""
them=""
ht=0

for arg in "$@"; do
  arg_lc=$(tr '[:upper:]' '[:lower:]' <<< "$arg")
  case "$arg_lc" in
    --pch)            pch=1     ;;
    --generated-only) go=1      ;;
    --deep-clean)     dc=1      ;;
    --dry-run)        dry_run=1 ;;
    --help)           help      ;;
    --folders=*)      IFS=',' read -ra fo <<< "${arg#--folders=}"    ;;
    --platform=*)     IFS=',' read -ra pl <<< "${arg#--platform=}"   ;;
    --build-type=*)   IFS=',' read -ra bt <<< "${arg#--build-type=}" ;;
    --link-type=*)    IFS=',' read -ra lt <<< "${arg#--link-type=}"  ;;
    *)                n=${#pl[@]}; (( n == 0 )) && pl[0]=${arg} && continue;
                      n=${#bt[@]}; (( n == 0 )) && bt[0]=${arg} && continue;
                      n=${#lt[@]}; (( n == 0 )) && lt[0]=${arg} && continue;
                      help "Unknown or duplicate argument '${arg}'";;
  esac
done

(( ${#fo[@]} == 0 || ${#fo[@]} == 2 ))    || help "If provided, folders must have two folders"
(( ${#pl[@]} <= 1 )) && platform=${pl[0]} || help "Only one platform can be specified. Omit it to delete all"
(( ${#bt[@]} <= 1 )) && build=${bt[0]}    || help "Only one build-type can be specified. Omit it to delete all build-types"
(( ${#lt[@]} <= 1 )) && link=${lt[0]}     || help "Only one link-type can be specified. Omit it to delete all link-types"

[[ -n $build ]] && [[ -z $platform ]]     && help "Can't have a build-type without a platform"
[[ -n $link  ]] && [[ -z $build    ]]     && help "Can't have a link-type without a build-type"
[[ -n $link  ]] && [[ -z $platform ]]     && help "Can't have a link-type without a platform"

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

p1=$(tr '[:upper:]' '[:lower:]' <<< "$platform")
p2=$(tr '[:upper:]' '[:lower:]' <<< "$build")
p3=$(tr '[:upper:]' '[:lower:]' <<< "$link")

[[ -n $p1 ]] && { p1="/${p1}"; w1=${p1}; } || w1='/*'
[[ -n $p2 ]] && { p2="/${p2}"; w2=${p2}; } || w2='/*'
[[ -n $p3 ]] && { p3="/${p3}"; w3=${p3}; } || w3='/*'
ppath="${p1}${p2}${p3}"
wpath="${w1}${w2}${w3}"

f() {
    fc=0
    test -e "$1" && fc=$(ls -R1 "$1" | sed -e "s/^.*:$//g" | sort | sed -e "s/ //g" | wc -l) || fc=0
    printf "Removing %5d %9s files from %s...\n" $fc $2 $1
    if (( fc > 0 )); then
        num=$((num + fc))
        (( ! dry_run )) && rm -rf "$1"
    fi
    return 0
}

bye() {
    printf "Removed  %5d %9s files. I'm tired boss..." $num "total"
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
(( go || dc )) && [[ -n "$them" ]] && f "$PROJECTS/$them/generated$ppath" "generated"

# Always
f "$PROJECTS/$us/build$ppath" "build"
f "$PROJECTS/$us/out$ppath"   "out"

# --deep-clean
if (( dc )); then

  f "$PROJECTS/$us/external$ppath"  "external"

  (( ht )) && f "$PROJECTS/$them/build$ppath"     "build"
  (( ht )) && f "$PROJECTS/$them/out/$ppath"      "out"
  (( ht )) && f "$PROJECTS/$them/external$ppath"  "external"

  f "$HOME/dev/stage$ppath"         "stage"
  f "$HOME/dev/archives$ppath"      "archives"

  mkdir -p "$HOME/dev/archives$ppath"
  mkdir -p "$HOME/dev/stage$ppath"

fi

bye
