                          

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

    this:brwsck:=socketNew(sck)  //socket fd -> object
    this:request:=http_readmessage(this:brwsck,10000) //elso request

//    if( !a"localhost" $ this:request )
//        //TESZTELESHEZ IDEIGLENESEN
//        //az ff azonnal elkezd toltogetni (akadalyozza a tesztet)
//        //egyelore minden ilyen toltogetest azonnal csendben eldobunk
//        quit
//    end  


    ? "==========================================="
    ? "FIRST request", time(), sck
    ? this:request


    if( this:request[1..4]==a"GET " )
        connect_http(this) //HTTP
        //this:request bennehagyva

    elseif( this:request[1..8]==a"CONNECT " )
        connect_https(this) //HTTPS
        this:request:=NIL
        //this:request eldobva

    else

    ? "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        ? "Not implemented"
        ? this:request
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

    this:srvsck:=socketNew()
    this:srvsck:connect(host[1],host[2])

    ? "==========================================="
    ? "HTTP connected to:", this:host


***************************************************************************************
static function connect_https(this)

local srvctx,clnctx,host,pem

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

    this:srvsck:=socketNew()
    this:srvsck:connect(host[1],host[2])
    
    srvctx:=sslctxNew() 
    this:srvsck:=sslconConnect(srvctx,this:srvsck)   // socket -> sslcon



    ? "==========================================="
    ? "HTTPS connected to:", this:host


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


    this:brwsck:send(a"200 connected"+x"0d0a0d0a")  //kapcsolat megvan

    //generalunk egy host[1] nevre szolo tanusitvanyt,
    //ami ala van irva a comfirm.hu-val,
    //ami installalva van a browseer authorities tabjaban
    
    pem:=gencert(host[1]::bin2str)
    
    clnctx:=sslctxNew("TLS_server") 
    clnctx:use_certificate_file(pem)
    clnctx:use_privatekey_file(pem)
    this:brwsck:=sslconAccept(clnctx,this:brwsck)  //socket -> sslcon
    


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
                   this:response:=http_readmessage(this:srvsck,1000)
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
    ? "DISCONNECTED"
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
    this:request:=NIL

    ? "..........................................."
    ? "FORWARDED to server"
    ? req



***************************************************************************************
static function forward_to_browser(this)
    this:brwsck:send(this:response)

    ? "..........................................."
    ? "FORWARDED to browser"
    ? this:response::http_header


***************************************************************************************

