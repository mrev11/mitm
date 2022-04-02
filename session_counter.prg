

#include "fileio.ch"


function session_counter(c)
static counter
    if( c!=NIL )
        counter:=padl(c,4,"0")
    end
    return counter


function logfile()
static cnt:=0
    return "log-"+session_counter()+"-"+(++cnt)::str::alltrim::padl(4,"0")+".log"


