#!/bin/bash
cd log

#FIGYELEM, ezekre kell ügyelni:
#
#1) Az ncterm-es programok nem futhatnak háttérben.
#
#2) Az ncterm-es child programok csak örökölt terminállal működnek jól.
#   Másképp két terminál fut egyszerre, és összekeverednek az üzenetek.
#
#3) Amikor a child a parentjétől örökölt terminálban fut,
#   akkor a parentnek mindenképp meg kell várnia a child kilépését, 
#   másképp összekeverednek az üzenetek (és bármi lehet, pl. coredump).
#   Ezt ncterm-es és X-es programoknál is be kell tartani.


export OREF_SIZE=200000
export CCCTERM_SIZE=120x40

export TEMP=~/.temp
export GREP='grep --text -i -H -n'
export FIND='savex.exe . -y -f -lilog-* -r.ppo. -lrobj* -lr*.nopack'


if echo "$CCCTERM_CONNECT" | grep "ncterm.exe" >/dev/null; then
    export CCCTERM_INHERIT=yes
    zgrep.exe "$1" "$2"         #must not run in background

elif echo "$CCCTERM_CONNECT" | grep "SOCKET:" >/dev/null; then
    zgrep.exe "$1" "$2"         #must not run in background

else    
    export CCCTERM_INHERIT=no   #choice: separate window
    #export CCCTERM_INHERIT=yes  #choice: inherited window
    zgrep.exe "$1" "$2" &       #may run in bacground
fi    
