

static hash_rewrite:=inihash()


********************************************************************************************
static function inihash()

local hash
local sr:=memoread("sites_rewrite"),n

    sr::=strtran(chr(13),"")
    sr::=strtran(chr(9)," ")
    while( "  "$ sr )
        sr::=strtran("  "," ")
    end
    sr::=split(chr(10))
    
    if( !empty(sr) )

        hash:=simplehashNew()    
        for n:=1 to len(sr)
            sr[n]::=alltrim
            sr[n]::=split(" ")
        
            if( sr[n]::len==2 )
                hash[sr[n][1]]:=sr[n][2]
            end
        next
        
        //hash:list
    end

    return hash


********************************************************************************************
function rewrite(host)
local host1

    if( hash_rewrite!=NIL )
        host1:=hash_rewrite[host::bin2str]
        if( host1!=NIL )
            host:=host1::str2bin
        end
    end

    return host


********************************************************************************************
