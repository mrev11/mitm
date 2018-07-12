

#include "http_reader.ch"

static crlf:=x"0d0a"

*************************************************************************************************
class http_reader(object)

    attrib  id
    attrib  sck
    attrib  buffer
    attrib  status
    attrib  clen
    attrib  trne
    attrib  upgrade
    
    method  initialize
    method  printstate
    method  read
    method  next
       

*************************************************************************************************
static function http_reader.initialize(this,sck,id)
    //ujrainicializalhato

    if(sck!=NIL)
        this:sck:=sck
    end
    if(id!=NIL)
        this:id:=id
    end
    if(this:id==NIL)
        this:id:="unknown"
    end
    this:buffer:=a""
    this:status:=STATUS_HEADER
    this:clen:=NIL
    this:trne:=NIL
    return this



*************************************************************************************************
static function http_reader.printstate(this,sck,id:="unknown")
    ?? " id="     ; ?? this:id
    ?? " buflen=" ; ?? this:buffer::len::str::alltrim
    ?? " status=" ; ?? this:status::str::alltrim 
    ?? " conlen=" ; ?? if(this:clen==NIL,NIL,this:clen::str::alltrim) 
    ?? " trnenc=" ; ?? this:trne


*************************************************************************************************
static function http_reader.read(this)
local recv:=this:sck:recvall
    if( recv==NIL )
        //lezarodott a kapcsolat
        return .f.
    end
    this:buffer+=recv
    this:printstate
    return .t.


*************************************************************************************************
static function http_reader.next(this,status)  //@status kimenet
local msg

    status:=this:status //ez a resz kovetkezik
    
    if( status==STATUS_HEADER )
        msg:=next_header(this)

    elseif( status==STATUS_BODY )
        msg:=next_body(this)

    elseif( status==STATUS_CHUNK )
        msg:=next_chunk(this)

    elseif( status==STATUS_WEBSCK )
        msg:=next_websck(this)

    elseif( status==STATUS_END )
        msg:=NIL
    end
    
    if( this:status==STATUS_END )
        //rafordul a kovetkezore
        this:initialize(this:sck,this:id)
    end

    
    return msg

// az objektum nyilvantartja,
// hogy az uzenet mely reszenek belovasasa van soron
// ha a visszaadott msg==NIL, akkor meg nincs eleg adat
// ha a visszaadott msg!=NIL, akkor a @status parameterben
// visszaadott ertek mutatja, hogy mely reszt tartalmazza az msg

// minden next ugy mukodik,
// hogy megnezi, van-e mar eleg adat a bufferben,
// ha van, akkor visszaadja a megfelelo komponenst,
// ha nincs, akkor NIL-t ad, es tovabb kell varni/olvasni


*************************************************************************************************
static function next_header(this)        
local msg,pos:=at(crlf+crlf,this:buffer)

    if(pos==0)
        //nem gyult meg ossze a header
        return NIL 
    end

    pos+=3
    msg:=this:buffer::left(pos) //header
    this:buffer::=substr(pos+1)

    this:clen:=http_getheader(msg,"content-length")
    if(this:clen!=NIL)
        this:clen::=val
    end

    this:trne:=http_getheader(msg,"transfer-encoding")
    if( this:trne!=NIL )
        this:trne::=lower
    end

    this:upgrade:=http_getheader(msg,"upgrade")
    if( this:upgrade!=NIL )
        this:upgrade::=lower
    end

    if( !empty(this:clen) )
        //ez kovetkezik: ismert hosszusagu body
        this:status:=STATUS_BODY 

    elseif( this:trne==a"chunked" )
        //ez kovetkezik: az elejen megadott hosszusagu chunk
        this:status:=STATUS_CHUNK 

    elseif( this:upgrade==a"websocket" )
        //ez kovetkezik: folyamatos forgalom (nem elemezheto)
        this:status:=STATUS_WEBSCK

    else
        //ez kovetkezik: ures body
        this:status:=STATUS_END
    end        


    if( msg!=NIL )
        ? "HEADER arrived from" //id=...
        this:printstate
    end
    
    return msg


*************************************************************************************************
static function next_body(this)        
local msg

    if( this:buffer::len>=this:clen )
        msg:=this:buffer::left(this:clen)
        this:buffer::=substr(this:clen+1)
        this:status:=STATUS_END
    end

    if( msg!=NIL )
        ? "BODY arrived from"
        this:printstate
    end

    return msg


*************************************************************************************************
static function next_websck(this)  //folyamatos tovabbitas      
local msg

    if( this:buffer::len>0 )
        msg:=this:buffer
        this:buffer:=a""
        this:status:=STATUS_WEBSCK
    end

    return msg

*************************************************************************************************
static function next_chunk(this)        

local msg
local lendata,len
local pos:=at(crlf,this:buffer)

    if( pos==0 )
        return NIL
    end

    lendata:=this:buffer::left(pos-1)::bin2str::hex2l
    len:=pos+1+lendata+2
    
    if( this:buffer::len>=len )
        msg:=this:buffer::left(len)
        this:buffer::=substr(len+1)
        this:status:=if(lendata>0,STATUS_CHUNK,STATUS_END)
    end

    if( msg!=NIL )
        ? "CHUNK arrived from"
        this:printstate
    end

    return msg

    // chunkok formatuma
    //
    // hhhhCRCRxxxxCRmmmmmmmmmmmmmmmmmCRxCRmmmmmmmCR0CRCR
    //         ^                        ^           ^
    //         start1                   start2      start-last
    // 
    // h  : header
    // x  : a chunk hossza hexaban
    // CR : \r\n  (ket bajt)
    // m  : az uzenet tenyleges tartalma (len(m)==x::bin2str::hex2l)
    //
    // az utolso chunk (tartalmanak) hossza 0

*************************************************************************************************
    