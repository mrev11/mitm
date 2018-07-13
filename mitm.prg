                          
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
    attrib  sslflag
    attrib  hellobyte
    
    method  initialize
    method  loop
    

***************************************************************************************
static function mitm.initialize(this,sck)
local id,pos

    this:brwsck:=socketNew(sck)  //socket fd -> object
    this:request:=http_readmessage(this:brwsck,10000) //elso request

    if( this:request==NIL )
        //neha a browser egyszeruen bont
        quit
    end

    if( prohibited_site(this:request) )
        this:brwsck:send(a"HTTP/1.1 503 Service Unavailable"+x"0d0a0d0a")  
        quit
    end

    dirmake("log")
    id:=date()::dtos+"-"+time()+"-"+getpid()::str::alltrim
    set alternate to "log/log-"+id::strtran(":","-")
    set alternate on

    ? "==========================================="
    ? "FIRST request", time(), sck
    ? this:request


    if( 0<(pos:=at(a"http://",this:request)) .and. pos<10 )
        this:sslflag:=.f.
        connect_http(this)

    elseif( a"CONNECT "==this:request::left(8) )
        connect_connect(this)

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

    //peldaul: GET http://comfirm.hu/ HTTP/1.1

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
    ? "CONNECT-HTTP to:", this:host

    begin
        this:srvsck:=socketNew()
        this:srvsck:connect(host[1],host[2])
    recover err <socketerror>
        ? "CONNECT-HTTP failed", host[1], err:description
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
static function connect_connect(this)
local host

    //peldaul: 
    // CONNECT localhost:80 HTTP/1.1
    // CONNECT localhost:443 HTTP/1.1

    host:=this:request::split(a" ")[2]::split(a":")
    if( host::len<2 )
        host::aadd(a"80")
    end
    host[2]::=val
    this:host:=host

    this:brwsck:send(a"HTTP/1.1 200 Connection established"+x"0d0a0d0a")  

    // Most a browser azt gondolja, hogy megvan a kapcsolat,
    // es kuldheti az uzeneteit, megvarjuk, hogy tenyleg kuldjon,
    // es belenezunk (!) az uzenetbe, ket dolog johet:
    // 1) client hello (elso bajt 22) --> SSL
    // 2) normal request GET,POST,stb. --> PLAIN

    select( {this:brwsck:fd} )
    this:hellobyte:=socket_lookahead(this:brwsck:fd)

    if( this:hellobyte==0 )
        //neha 0 is jon
        //szerintem ilyenkor a browser egyszeruen 
        //meggondolta magat es letette a kagylot
        //(a telefonbetyar)
        quit

    elseif( this:hellobyte==22 )
        this:sslflag:=.t.
        connect_ssl(this)

    else
        this:sslflag:=.f.
        connect_plain(this)
    end


***************************************************************************************
static function connect_plain(this)
local err

    if( this:srvsck!=NIL )
        this:srvsck:close
    end

    ? "==========================================="
    ? "CONNECT-PLAIN to:", this:host, this:hellobyte

    begin    
        this:srvsck:=socketNew()
        this:srvsck:connect(this:host[1],this:host[2])
    recover err <socketerror>
        ? "CONNECT-PLAIN failed", this:host[1], err:description
        quit
    end    

    if( this:brwreader==NIL )
        this:brwreader:=http_readerNew(this:brwsck,"brw")
    end
    this:srvreader:=http_readerNew(this:srvsck,"srv")


***************************************************************************************
static function connect_ssl(this)

local srvctx,clnctx,pem,err
local cafile:="/etc/ssl/certs/ca-certificates.crt"
local capath:="/etc/ssl/certs"

    //MEGJEGYZES:
    //
    // Jobb eloszor a browserhez kapcsolodni,
    // ui. a browser (FF) indit egy csomo connect-et,
    // amik kozul (az SSL handshake helyett/elott) sokat eldob.
    // Ilyen esetben azonnal dobhatjuk a sessiont, mielott meg
    // fogyasztottuk volna a mobilinternet egyenlegunket
    // a szerverhez valo hiabavalo konnektalassal.
    //
    //               eloszor                  masodszor
    //browser  <--belso halozat-->  proxy  <--internet-->  szerver
    
    
    //eloszor: kapcsolodas a browserhez
    //a tcp kapcsolat mar megvan, az ssl handshake kovetkezik 
    //ropteben keszitunk egy olyan tanusitvanyt, amit a browser elfogad
    //a tanusitvanyban szerepel a szerver neve, ezt a browser ellenorzi
    //a szerver nevet korulmenyes megszerezni, mi egyszeruen
    //az url-bol kiolvasott szerver nevet hasznaljuk (ami nem mindig jo)
    //profibb megoldas (1): a szerver tanusitvanyabol is ki lehetne olvasni
    //profibb megoldas (2): a client helloban levo SNI kiterjesztesbol

    //generalunk egy host[1] nevre szolo tanusitvanyt,
    //ami ala van irva a CN=mitm nevre szolo kulccsal
    //(ami installalva van a browser authorities tabjaban)
    
    pem:=gencert(this:host[1]::bin2str)

    begin    
        clnctx:=sslctxNew("TLS_server") 
        clnctx:use_certificate_file(pem)
        clnctx:use_privatekey_file(pem)
        this:brwsck:=sslconAccept(clnctx,this:brwsck)  //socket -> sslcon
    recover err <sslerror>
        ? "SSLCON-ACCEPT failed", this:host[1], err:description
        quit
    end    


    //masodszer: kapcsolodas a szerverhez
    //a browser helyett konnektalunk a szerverbe
    //a browser ellenorizne a szerver hitelesseget
    //mi itt csak kapcsolodunk, nem ellenorzunk 
    //VALTOZAS: beepitve az ellenorzes

    if( this:srvsck!=NIL )
        this:srvsck:close
    end

    ? "==========================================="
    ? "CONNECT-SSL to:", this:host, this:hellobyte

    begin    
        srvctx:=sslctxNew() 
        //srvctx:=sslctxNew("TLS_client") 
        srvctx:set_verify(SSL_VERIFY_PEER_CERT)
        //srvctx:set_verify_depth(15)
        srvctx:load_verify_locations(cafile,capath)

        this:srvsck:=sslconNew(srvctx)
        this:srvsck:connect(this:host[1],this:host[2])
    recover err <socketerror>
        ? "CONNECT-SSL failed", this:host[1], err:description
        quit
    end    

    if( this:brwreader==NIL )
        this:brwreader:=http_readerNew(this:brwsck,"brw")
    end
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
            if( !this:sslflag .and. status==STATUS_HEADER )

                //titkositott kommunikacio eseten 
                //ide nem johet, mert a proxy nem latja a headert, 
                //tehat a browser nem kuldhet a proxynak szolo utasitast 

                //plain kommunikacio eseten
                //a browser a meglevo TCP kapcsolat bontasa nelkul
                //olyan requestet is kuldhet, amiben abszolut URL van
                //ilyenkor konnektalni kell a megadott (uj) URL-hez

                if( 0<(pos:=at(a"http://",this:request)) .and. pos<10 )
                    if( prohibited_site(this:request) )
                        this:brwsck:send(a"HTTP/1.1 503 Service Unavailable"+x"0d0a0d0a")  
                        quit
                    end
                    ? "reconnect-http"
                    connect_http(this)

                elseif( a"CONNECT "==this:request::left(8) )
                    if( prohibited_site(this:request) )
                        this:brwsck:send(a"HTTP/1.1 503 Service Unavailable"+x"0d0a0d0a")  
                        quit
                    end
                    ? "reconnect-connect"
                    connect_connect(this)
                    
                    //Ide sosem jon:
                    //Elmeletileg johetne, de nincs ra pelda,
                    //ez az ag ezert egyelore nincs tesztelve.
                    //A gyakorlatban CONNECT csak elso requestkent fordul elo, 
                    //mindig SSL kapcsolat letrehozasat szolgalja, kiveve a plain
                    //websocket esetet (az is csak nalam fordul elo).
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
//    elseif( status==STATUS_BODY )
//        ? "..........................................."
//        ? "forwarded body to server", this:host[1], nbyte
//        ?
//    elseif( status==STATUS_CHUNK )
//        ? "..........................................."
//        ? "forwarded chunk to server", this:host[1], nbyte
//        ?
    end


***************************************************************************************
static function forward_to_browser(this,status)
local nbyte:=this:brwsck:send(this:response)
    if( status==STATUS_HEADER )
        ? "..........................................."
        ? "FORWARDED header to browser",this:host[1], nbyte
        ? this:response
//    elseif( status==STATUS_BODY )
//        ? "..........................................."
//        ? "forwarded body to browser", this:host[1], nbyte
//        ?
//    elseif( status==STATUS_CHUNK )
//        ? "..........................................."
//        ? "forwarded chunk to browser", this:host[1], nbyte
//        ?
    end


***************************************************************************************
