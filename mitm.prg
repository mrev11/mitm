                          

***************************************************************************************
class mitm(object)

    attrib  brwsck
    attrib  srvsck

    attrib  request
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
        sleep(10000)
        quit
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
        //this:request bennehagyva

    elseif( this:request[1..5]==a"POST " )
        connect_http(this) //HTTP
        //this:request bennehagyva

    elseif( this:request[1..8]==a"CONNECT " )
        connect_https(this) //HTTPS
        this:request:=NIL
        //this:request eldobva

    else

        ? "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        ? "Not implemented"
        ? "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        quit
    end

    return this
    

***************************************************************************************
static function connect_http(this)

local host:=http_getheader(this:request, "Host")

    host::=split(":")
    if( len(host)<2 )
        aadd(host,a"80")
    end
    host[2]:=val(host[2])
    
    this:host:=host

    ? "==========================================="
    ? "HTTP connect to:", this:host

    this:srvsck:=socketNew()
    ?? this:srvsck:connect(host[1],host[2])



***************************************************************************************
static function connect_https(this)

local srvctx,clnctx,host,pem,err

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
        srvctx:=sslctxNew("TLS_client") 
        this:srvsck:=sslconNew(srvctx)
        ?? this:srvsck:connect(host[1],host[2])
    recover err <sslerror>
        ? "SSLCONCONNECT failed", err:description
        quit
    end    
    

    //kapcsolodas a browserhez
    //a plain socketen jelezzuk, hogy megvan a kapcsolat a szerverhez
    //a browser client hello-t kuld, ezt NEM kuldjuk tovabb a szevernek
    //hanem ugy teszunk, mintha mi volnank a szerver:
    //ropteben keszitunk egy olyan tanusutvanyt, amit a browser elfogad
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
        ? "SSLCONACCEPT failed", err:description
        quit
    end    


***************************************************************************************
static function mitm.loop(this)

local sel,n,continue:=.t.

    while( continue )

        if( this:request!=NIL )
            //van beolvasott request
            forward_to_server(this)
            this:request:=NIL    

        elseif( this:response!=NIL )
            //van beolvasott response
            forward_to_browser(this)    
            this:response:=NIL

        else
            select(sel:={this:brwsck,this:srvsck})
            
            for n:=1 to len(sel)

                if( sel[n]==this:brwsck )
                   this:request:=http_readmessage(this:brwsck,1000)
                   if( this:request==NIL )
                        continue:=.f. //megszakadt a kapcsolat
                        exit
                   end
                end

                if( sel[n]==this:srvsck )
                   this:response:=http_readmessage(this:srvsck,1000)   //chunked?
                   if( this:response==NIL )
                        continue:=.f. //megszakadt a kapcsolat
                        exit
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
    ? "DISCONNECTED ", this:host[1]
    ?


***************************************************************************************
static function forward_to_server(this)

// HTTP request:    GET http://host/xxxxxx ....
// HTTPS request:   GET /xxxxxx ....

local pos,req

    if( a"GET http://" $ this:request )
        //abszolut url-t kihagyni
        pos:=at(a"/", this:request, 12 )
        req:=a"GET "+this:request[pos..]
    else
        req:=this:request
    end
    
    this:srvsck:send(req)

    ? "..........................................."
    ? "FORWARDED to server >>",this:host[1]
    ? req


***************************************************************************************
static function forward_to_browser(this)
    this:brwsck:send(this:response)

    ? "..........................................."
    ? "FORWARDED to browser <<",this:host[1]
    ? this:response::http_header,x"0d0a0d0a"


***************************************************************************************

