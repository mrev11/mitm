

#include "fileio.ch"


function session_counter(c)
static counter
    if( c!=NIL )
        counter:=c
    end
    return counter



function writelog(x)
static cnt:=0
local fd
    fd:=fopen( "LOG-"+session_counter()+"-"+(++cnt)::str::alltrim+".log",FO_CREATE+FO_READWRITE)
    fwrite(fd,x)
    fclose(fd)


