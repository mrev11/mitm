
#include "fileio.ch"

#define VISITED     "sites-visited"
#define PROHIBITED  "sites-prohibited"
#define REFUSED     "sites-refused"


**********************************************************************************************
function prohibited_site(req)

static fdvisited:=fopen(VISITED,FO_READWRITE+FO_CREATE+FO_APPEND)
static fdrefused:=fopen(REFUSED,FO_READWRITE+FO_CREATE+FO_APPEND)
static hash_visited:=loadhash(VISITED)
static hash_prohibited:=loadhash(PROHIBITED)
local host

    //hash_visited:list
    //hash_prohibited:list

    if( req[1..4]==a"GET " )
        host:=http_getheader(req,"Host")
    elseif( req[1..5]==a"POST " )
        host:=http_getheader(req,"Host")
    elseif( req[1..8]==a"CONNECT " )
        host:=req::split(a" ")[2]
    else
        return .f.  //ismeretlen tipusu request
    end

    if( !empty(hash_prohibited[host]) )
        fwrite(fdrefused,date()::dtos+"-"+time()+":")
        fwrite(fdrefused,host)
        fwrite(fdrefused,x"0a")
        return .t.
    end
    
    if( empty(hash_visited[host]) )
        fwrite(fdvisited,host)
        fwrite(fdvisited,x"0a")
        hash_visited[host]:=.t.
    end
    
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
