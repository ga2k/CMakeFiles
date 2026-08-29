#!/bin/bash

go=0
dc=0
pch=0

for arg in "$@"; do [[ ${arg,,} == --pch ]] && { pch=1; break; }; done
if (( pch )); then

  printf "Removing %3d %9s files...\n" $(ls -R1 "build/${1,,}/${2,,}/${3,,}/pch/wx_pch.gch" | sed -e "s/^.*:$//g" | sort | sed -e "s/ //g" | wc -l) "pch"
  rm -f build/${1,,}/${2,,}/${3,,}/pch/wx_pch.gch
  exit 0

fi

for arg in "$@"; do [[ ${arg,,} == --generated-only ]] && { go=1; break; }; done
if (( go )); then

  printf "Removing %3d %9s files...\n" $(ls -R1 "build/${1,,}/${2,,}/${3,,}/_deps/generated" | sed -e "s/^.*:$//g" | sort | sed -e "s/ //g" | wc -l) "generated"
  rm -rf "build/${1,,}/${2,,}/${3,,}/_deps/generated"

else

  printf "Removing %3d %9s files...\n" $(ls -R1 "build/${1,,}/${2,,}/${3,,}" | sed -e "s/^.*:$//g" | sort | sed -e "s/ //g" | wc -l) "build"
  rm -rf "build/${1,,}/${2,,}/${3,,}"

  printf "Removing %3d %9s files...\n" $(ls -R1 "out/${1,,}/${2,,}/${3,,}" | sed -e "s/^.*:$//g" | sort | sed -e "s/ //g" | wc -l) "out"
  rm -rf "out/${1,,}/${2,,}/${3,,}"

  printf "Removing %3d %9s files...\n" $(ls -R1 "/home/geoffrey/dev/stage/${1,,}/${2,,}/${3,,}" | sed -e "s/^.*:$//g" | sort | sed -e "s/ //g" | wc -l) "staged"
  rm -rf /home/geoffrey/dev/stage/${1,,}/${2,,}/${3,,}
  mkdir -p /home/geoffrey/dev/stage/${1,,}/${2,,}/${3,,}

  for arg in "$@"; do [[ ${arg,,} == --generated-only ]] && { dc=1; break; }; done
  if (( dc )); then

    printf "Removing %3d %9s files...\n" $(ls -R1 "/home/geoffrey/dev/archives/${1,,}/${2,,}/${3,,}" | sed -e "s/^.*:$//g" | sort | sed -e "s/ //g" | wc -l) "archived"
    rm -rf /home/geoffrey/dev/archives/${1,,}/${2,,}/${3,,}
    mkdir -p /home/geoffrey/dev/archives/${1,,}/${2,,}/${3,,}

  printf "Removing %3d %9s files...\n" $(ls -R1 "external/${1,,}/${2,,}/${3,,}" | sed -e "s/^.*:$//g" | sort | sed -e "s/ //g" | wc -l) "external"
    rm -rf "external/${1,,}/${2,,}/${3,,}"

  fi
fi

echo "Done.        Sleeping zzzzzz...."
sleep 5