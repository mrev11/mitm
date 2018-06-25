
/*
 *  CCC - The Clipper to C++ Compiler
 *  Copyright (C) 2005 ComFirm BT.
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

//Miből áll a HTTP üzenet:  byteokból vagy karakterekből?
//Mire vonatkozik a Content-Length header:  a byte hosszra?
//
//Ezek a programok feltételezik, hogy az msg paraméter binary string.
//Minden más paramétert binaryra konvertálnak (ha eleve nem az).
//A http_writemessage az msg-t is binaryra konvertálja.
//A visszatérési értékük binary string, pl. http_readmessage --> binary.
//A Content-Length byte számban értendő.
//A http_readmessage megköveteli, hogy Content-Length meg legyen adva.


//#define IO_WARNING  //sikertelen io műveletek jelzése

static crlf:=x"0d0a"
static debug:=getenv("HTTP_DEBUG") 

*****************************************************************************
function http_header(msg)
    return left(msg,at(crlf+crlf,msg)-1)


*****************************************************************************
function http_body(msg)
    return substr(msg,at(crlf+crlf,msg)+4)

 
*****************************************************************************
function http_getheader(msg,hdr)
local h, x, pos 

    hdr:=crlf+lower(str2bin(hdr))+a":"
    pos:=at(hdr,lower(msg))
    if( pos>0 .and. pos<at(crlf+crlf,msg) )
        x:=substr(msg,pos+len(hdr))
        pos:=at(crlf,x)
        h:=alltrim(left(x,pos-1))
    end
    return h


*****************************************************************************
function http_setheader(msg,hdr,value)

local x,y,pos

    hdr:=str2bin(hdr)
    value:=str2bin(value)

    hdr:=crlf+hdr+a":"
    pos:=at(lower(hdr),lower(msg))

    if( pos>0 .and. pos<at(crlf+crlf,msg) )
        x:=left(msg,pos-1)
        y:=substr(msg,pos+2) //crlf-et átlépni
        pos:=at(crlf,y)
        y:=substr(y,pos)
    else
        pos:=at(crlf+crlf,msg) 
        x:=left(msg,pos-1)
        y:=substr(msg,pos)
    end
    msg:=x+hdr+a" "+value+y

    return msg


*****************************************************************************
function http_removeheader(msg,hdr)
local pos1,pos2
    hdr:=crlf+str2bin(hdr)+a":"
    pos1:=at(lower(hdr),lower(msg))
    if( pos1>0 .and. pos1<at(crlf+crlf,msg) )
        pos2:=at(crlf,msg,pos1+2)
        msg:=stuff(msg,pos1,pos2-pos1,a"")
    end
    return msg


*****************************************************************************
function http_getvalue(msg,hdrnam,parnam) 

local header,pos,value,t

    hdrnam:=str2bin(hdrnam)
    parnam:=str2bin(parnam)

    header:=http_getheader(msg,hdrnam)
    parnam+=a"="

    if( header!=NIL .and. 0<(pos:=at(lower(parnam),lower(header))) )
        value:=substr(header,pos+len(parnam))
        t:=left(value,1)
        if( t==a'"' )
            value:=substr(value,2)
            pos:=at(a'"',value)
        else
            pos:=len(value)+1
            if( a" "$value  )
                pos:=min(pos,at(a" ",value))
            end
            if( a";"$value  )
                pos:=min(pos,at(a";",value))
            end
        end
        value:=left(value,pos-1)

        //? hdrnam+a":", parnam+a'"'+value+a'"'
    end
    return value
 

*****************************************************************************
function http_getcookie(msg,parnam) 
    return http_getvalue(msg,"Cookie",parnam)


*****************************************************************************
function http_writemessage(sck,msg)
local result

    if( valtype(sck)=="N" )
        //compatibility
        sck:=socketNew(sck)
    end

    msg:=str2bin(msg)
    result:=sck:send(msg)  

    if( len(msg)!=result )
        #ifdef IO_WARNING
        ? "http_writemessage error",sck,len(msg),result 
        #endif
    end

    if( "W"$debug )    
        ? ">>>>WRITE",sck
        if( !"B"$debug )    
            ? http_header(msg)
        else
            ? http_header(msg)+http_body(msg) 
        end
    end

    return result


*****************************************************************************
function http_readmessage(sck,timeout)

// A http_readmessage-et akkor lehet használni,
// ha az egész üzenet összegyűjthető egyetlen stringbe.
// A visszatérési érték az összegyűjtött komplett üzenet.
// Nem ez a helyzet például a forever frame technikánál,
// ahol a (chunked) üzenetdarabok folytatólagos feldogozást igényelnek,
// és ezért nem lehet az üzenet végét bevárni (nincs is vége).
//
// Ha van 'transfer-encoding: chunked' header, akkor a program beolvas 
// és konkatenál minden chunkot. A visszaadott messageben már nem lesznek 
// chunkok, noha a headerben megmarad az eredeti transfer encoding.
// VALTOZAS: 'transfer-encoding' kicserelve 'content-length'-re.
//
// Ha van content-length header, akkor az annak megfelelő hosszban olvasunk.
//
// Ha nincs se chunkolás, se content-length, akkor csak a headert olvassuk.
//
// Timeout esetén a program minden ágon NIL-t ad.


local t0:=gettickcount()
local crcr:=x"0d0a0d0a"
local msg:=a"",rcv,hlen,blen
local clhdr,tehdr
local start,chlen,body

    if( valtype(sck)=="N" )
        //compatibility
        sck:=socketNew(sck)
    end
    
    if( timeout==NIL )
        timeout:=60000 //1 perc
    end

    rcv:=sck:recvall(timeout)
    if( rcv==NIL )
        #ifdef IO_WARNING
        ? "http_readmessage (1) error",sck
        #endif
        return NIL  // read error
    else
        msg+=rcv
    end
    
    while( 0==(hlen:=at(crcr,msg)) )
        if( gettickcount()-t0>timeout )
            return NIL  // timeout
        end
        rcv:=sck:recvall(timeout)
        if( rcv==NIL )
            #ifdef IO_WARNING
            ? "http_readmessage (2) error",sck
            #endif
            return NIL  // read error
        else
            msg+=rcv
        end
    end
    
    if( hlen==0  )
        #ifdef IO_WARNING
        ? "http_readmessage (3) error",sck
        #endif
        return NIL //nem jött header 
    end

    hlen+=(len(crcr)-1) //header length

    if( (tehdr:=http_getheader(msg,a"Transfer-Encoding"))!=NIL .and. tehdr::lower==a"chunked" )

        body:=a""                                   // chunktalanított body
        start:=hlen+1                               // az első chunk hossz első bájtja

        while(.t.)
            chlen:=nextchunk(sck,@msg,start,t0,timeout)
            if( chlen==NIL )
                #ifdef IO_WARNING
                ? "http_readmessage (5) error",sck
                #endif
                return NIL
            elseif( chlen==0 )
                exit //utolsó chunk
            end
            
            start:=at(crlf,msg,start)+len(crlf)     // a tartalom első bájtja
            body+=msg::substr(start,chlen)          // chunktalanított body
            start+=chlen+len(crlf)                  // következő chunk hossz első bájtja
        end
        
        //VALTOZAS
        //  msg:=left(msg,hlen)+body
        //
        //  //a headerben benne van a 'Transfer-Encoding: chunked'
        //  //de valójában a body már chunktalanítva van
        //
        //KIVESZEM a 'Transfer-Encoding: chunked' headert
        //BERAKOM "Content-Length" hedaert

        msg::=left(hlen)
        msg::=http_removeheader("Transfer-Encoding")
        msg::=http_setheader("Content-Length",body::len::str::alltrim)
        msg+=body

    elseif( (clhdr:=http_getheader(msg,a"Content-Length"))!=NIL )
    
        blen:=val(clhdr) //body length

        while( len(msg)<hlen+blen  )
            if( gettickcount()-t0>timeout )
                return NIL  // timeout
            end
            rcv:=sck:recvall(timeout)    
            if( rcv==NIL )
                #ifdef IO_WARNING
                ? "http_readmessage (4) error",sck
                #endif
                return NIL  // read error
            else
                msg+=rcv
            end
        end

    else
        //se Content-Length, se chunkolás
        //csak a headert olvassuk (már megvan)
    end


    if( "R"$debug )    
        ? ">>>>READ",sck
        if( !"B"$debug )    
            ? http_header(msg)
        else
            ? http_header(msg)+http_body(msg) 
        end
    end
    
    return msg


****************************************************************************
static function nextchunk(sck,msg,start,t0,timeout)

local crpos,chlen,rcv

    // chunkok formátuma
    //
    // hhhhCRCRxxxxCRmmmmmmmmmmmmmmmmmCRxCRmmmmmmmCR0CRCR
    //         ^                        ^
    //         start1                   start2
    // 
    // h  : header
    // x  : a chunk hossza hexában
    // CR : \r\n  (két bájt)
    // m  : az üzenet tényleges tartalma (len(m)==x::bin2str::hex2l)
    //
    // az utolsó chunk (tartalmának) hossza 0

    while( (crpos:=at(crlf,msg,start))==0 )
        if( gettickcount()-t0>timeout )
            return NIL  //timeout
        end
        rcv:=sck:recvall(timeout)    
        if( rcv==NIL )
            return NIL  //read error
        else
            msg+=rcv
        end
    end
    
    chlen:=msg[start..crpos-1]::bin2str::hex2l

    while( len(msg)<crpos+len(crlf)+chlen-1 )
        if( gettickcount()-t0>timeout )
            return NIL  //timeout
        end
        rcv:=sck:recvall(timeout)    
        if( rcv==NIL )
            return NIL  //read error
        else
            msg+=rcv
        end
    end
    
    return chlen //length of next chunk


****************************************************************************
