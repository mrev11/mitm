                          
#include "ssl.ch"
#include "http_reader.ch"

***************************************************************************************
class mitm(object)

    attrib  brwsck
    attrib  brwreader
    attrib  request

    attrib  srvsck
    attrib  srvreader
    attrib  response

    attrib  host
    
    method  initialize
    method  loop
    

***************************************************************************************
static function mitm.initialize(this,sck)
local id

    this:brwsck:=socketNew(sck)  //socket fd -> object
    this:request:=http_readmessage(this:brwsck,10000) //elso request

    if( this:request==NIL )
        //neha a browser egyszeruen bont
        quit
    end

    if( prohibited_site(this:request) )
        //nem jo azonnal kilepni
        //mert azonnal ujra probalkozik
        sleep(2000)
        quit

        //inkabb (de megse):
        //this:brwsck:send(a"403 Forbidden"+x"0d0a0d0a")
        //this:brwsck:send(a"404 Not Found"+x"0d0a0d0a")
        //quit
    end

    dirmake("log")
    id:=date()::dtos+"-"+time()+"-"+getpid()::str::alltrim
    set alternate to "log/log-"+id::strtran(":","-")
    set alternate on

    ? "==========================================="
    ? "FIRST request", time(), sck
    ? this:request


    if( this:request[1..4]==a"GET " )
        connect_http(this) //HTTP

    elseif( this:request[1..5]==a"POST " )
        connect_http(this) //HTTP

    elseif( this:request[1..8]==a"CONNECT " )
        connect_https(this) //HTTPS

    else

        ? "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        ? "Not implemented"
        ? "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        quit
    end

    return this
    

***************************************************************************************
static function connect_http(this)

local err
local pos1:=at(a'http://',this:request)
local pos2:=at(a'/',this:request,pos1+7)
local host:=this:request[pos1+7..pos2-1]

    host::=split(":")
    if( len(host)<2 )
        aadd(host,a"80")
    end
    host[2]:=val(host[2])

    this:request:=this:request[1..pos1-1]+this:request[pos2..]

    if( this:srvsck!=NIL )
        if( this:host[1]==host[1] .and. this:host[2]==host[2] )
            ? "REUSE existing connection to", this:host
            return NIL
        else
            this:srvsck:close
        end
    end

    this:host:=host

    ? "==========================================="
    ? "HTTP connect to:", this:host

    begin
        this:srvsck:=socketNew()
        ?? this:srvsck:connect(host[1],host[2])
    recover err <socketerror>
        ? "SOCKET CONNECT failed", host[1], err:description
        quit
    end

    if( this:brwreader==NIL )
        this:brwreader:=http_readerNew(this:brwsck,"brw")
        this:brwreader:buffer:=this:request

        //Az elso requestet nem a http_reader:read
        //hanem a http_readmessage() olvasva.
        //A requestet bele kell rakni a bufferbe,
        //hogy onnan a http_reader:next elovehesse.
        
        //A kesobbi requestek nem erintik a brwreader-t,
        //ui. ha a browser megszakitja a kapcsolatot,
        //akkor a session vegeter.
    end    

    this:srvreader:=http_readerNew(this:srvsck,"srv")


***************************************************************************************
static function connect_https(this)

local srvctx,clnctx,host,pem,err
local cafile:="/etc/ssl/certs/ca-certificates.crt"
local capath:="/etc/ssl/certs"

    //kapcsolodas a szerverhez
    //a browser helyett konnektalunk a szerverbe
    //a browser ellenorizne a szerver hitelesseget
    //mi itt csak kapcsolodunk, nem ellenorzunk 


    //peldaul: CONNECT localhost:443 HTTP/1.1
    host:=this:request::split(a" ")[2]::split(a":")
    if( host::len<2 )
        host::aadd(a"443")
    end
    host[2]::=val
    this:host:=host

    ? "==========================================="
    ? "HTTPS connect to:", this:host

    begin    
        //srvctx:=sslctxNew("TLS_client") 
        srvctx:=sslctxNew() 
        srvctx:set_verify(SSL_VERIFY_PEER_CERT)
        //srvctx:set_verify_depth(15)
        srvctx:load_verify_locations(cafile,capath)

        this:srvsck:=sslconNew(srvctx)
        ?? this:srvsck:connect(host[1],host[2])
    recover err <sslerror>
        ? "SSLCON CONNECT failed", host[1], err:description
        quit
    end    
    

    //kapcsolodas a browserhez
    //a plain socketen jelezzuk, hogy megvan a kapcsolat a szerverhez
    //a browser client hello-t kuld, ezt NEM kuldjuk tovabb a szevernek
    //hanem ugy teszunk, mintha mi volnank a szerver:
    //ropteben keszitunk egy olyan tanusitvanyt, amit a browser elfogad
    //a tanusitvanyban szerepel a szerver neve, ezt a browse ellenorzi
    //a szerver nevet korulmenyes megszerezni, mi egyszeruen
    //az url-bol kiolvasott szerver nevet hasznaljuk (ami nem mindig jo)
    //profibb megoldas (1): a szerver tanusitvanyabol is ki lehetne olvasni
    //profibb megoldas (2): a client helloban levo SNI kiterjesztesbol


    this:brwsck:send(a"200 connected"+x"0d0a0d0a")  //felel: a kapcsolat megvan

    //generalunk egy host[1] nevre szolo tanusitvanyt,
    //ami ala van irva a CN=mitm nevre szolo kulccsal
    //(ami installalva van a browseer authorities tabjaban)
    
    pem:=gencert(host[1]::bin2str)

    begin    
        clnctx:=sslctxNew("TLS_server") 
        clnctx:use_certificate_file(pem)
        clnctx:use_privatekey_file(pem)
        this:brwsck:=sslconAccept(clnctx,this:brwsck)  //socket -> sslcon
    recover err <sslerror>
        ? "SSLCON ACCEPT failed", host[1], err:description
        quit
    end    

    this:brwreader:=http_readerNew(this:brwsck,"brw")
    this:srvreader:=http_readerNew(this:srvsck,"srv")


***************************************************************************************
static function mitm.loop(this)

local pos,sel,n
local status
local continue:=.t.

    while(.t.)

        if( (this:response:=this:srvreader:next(@status))!=NIL )
            forward_to_browser(this,status)    

        elseif( (this:request:=this:brwreader:next(@status))!=NIL )
            if( status==STATUS_HEADER )
                //a browser a meglevo TCP kapcsolat bontasa nelkul
                //olyan requestet is kuldhet, amiben abszolut URL van
                //ilyenkor konnektalni kell a megadott (uj) URL-hez
                pos:=at(a"http://",this:request)
                if( 0<pos .and. pos<10 )
                    connect_http(this)
                end
            end
            forward_to_server(this,status)

        elseif( !continue )
            exit

        else
            select(sel:={this:brwsck,this:srvsck})
            ? "SELECT:"

            for n:=1 to len(sel)
                if( sel[n]==this:srvsck )
                    ?? "S"
                    if( !this:srvreader:read )
                        ?? "!"
                        continue:=.f.  //megszakadt a kapcsolat
                    end
                elseif( sel[n]==this:brwsck )
                    ?? "B"
                    if( !this:brwreader:read )
                        ?? "!"
                        continue:=.f.  //megszakadt a kapcsolat
                    end
                end
            next

        end
    end
    
    if( this:brwsck!=NIL )
       this:brwsck:close
    end       
    if( this:srvsck!=NIL )
       this:srvsck:close
    end       

    ? "==========================================="
    ? "DISCONNECTED ", this:host[1], time()
    ?; this:srvreader:printstate
    ?; this:brwreader:printstate
    ?


***************************************************************************************
static function forward_to_server(this,status)
local nbyte:=this:srvsck:send(this:request)
    if( status==STATUS_HEADER )
        ? "..........................................."
        ? "FORWARDED header to server",this:host[1], nbyte
        ? this:request
    elseif( status==STATUS_BODY )
        ? "..........................................."
        ? "forwarded body to server", this:host[1], nbyte
        ?
    elseif( status==STATUS_CHUNK )
        ? "..........................................."
        ? "forwarded chunk to server", this:host[1], nbyte
        ?
    end


***************************************************************************************
static function forward_to_browser(this,status)
local nbyte:=this:brwsck:send(this:response)
    if( status==STATUS_HEADER )
        ? "..........................................."
        ? "FORWARDED header to browser",this:host[1], nbyte
        ? this:response
    elseif( status==STATUS_BODY )
        ? "..........................................."
        ? "forwarded body to browser", this:host[1], nbyte
        ?
    elseif( status==STATUS_CHUNK )
        ? "..........................................."
        ? "forwarded chunk to browser", this:host[1], nbyte
        ?
    end


***************************************************************************************

