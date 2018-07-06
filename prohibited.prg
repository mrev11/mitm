
#include "fileio.ch"

#define VISITED     "sites-visited"          //meglatogatott site-ok
#define VISITED1    "sites-visited1"         //meglatogatott site-ok (mindegyik csak egyszer)
#define PROHIBITED  "sites-prohibited"       //tiltott site-ok
#define REFUSED     "sites-refused"          //tiltas miatt elutasitott site-ok


**********************************************************************************************
function prohibited_site(req)

static fdvisited:=fopen(VISITED,FO_READWRITE+FO_CREATE+FO_APPEND)
static fdvisited1:=fopen(VISITED1,FO_READWRITE+FO_CREATE+FO_APPEND)
static fdrefused:=fopen(REFUSED,FO_READWRITE+FO_CREATE+FO_APPEND)
static hash_visited1:=loadhash(VISITED1)
local host

    if( req[1..4]==a"GET " )
        host:=http_getheader(req,"Host")
    elseif( req[1..5]==a"POST " )
        host:=http_getheader(req,"Host")
    elseif( req[1..8]==a"CONNECT " )
        host:=req::split(a" ")[2]
    else
        return .f.  //ismeretlen tipusu request
    end

    //if( !empty(hash_prohibited[host]) )
    if( isprohibited(host) )
        fwrite(fdrefused,date()::dtos+"-"+time()+": ")
        fwrite(fdrefused,host)
        fwrite(fdrefused,x"0a")
        return .t.
    end
    
    if( empty(hash_visited1[host]) )
        fwrite(fdvisited1,host)
        fwrite(fdvisited1,x"0a")
        hash_visited1[host]:=.t.
    end

    fwrite(fdvisited,date()::dtos+"-"+time()+": ")
    fwrite(fdvisited,host)
    fwrite(fdvisited,x"0a")
    
    return .f.


**********************************************************************************************
static function loadhash(filename)
local x:=memoread(filename,.t.)::split(x"0a")
local hash:=simplehashNew(),n
    for n:=1 to len(x)
        if( !empty(x[n]) )
            hash[x[n]]:=.t.
        end
    next
    return hash


**********************************************************************************************
static function isprohibited(host)
static hash_prohibited:=loadhash(PROHIBITED)
local ahost:=split(host,a"."),n
local xhost:=atail(ahost)

    for n:=len(ahost)-1 to 1 step -1
        xhost:=ahost[n]+a"."+xhost
        if( hash_prohibited[xhost]!=NIL )
            return .t.
        end
    next
    return .f.


**********************************************************************************************
