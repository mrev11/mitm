




function main()

local sck_listener:=socket()
local sck_client
local session_counter:=0


    sck_listener::setsockopt("REUSEADDR",.t.)
    if( 0!=sck_listener::bind("localhost",3128) )
        ? "bind failed"
        ?
        quit
    end
    sck_listener::listen
    
    while(.t.)
        sck_client:=sck_listener::accept
        run( "mitm_session.exe"+sck_client::str+" "+(++session_counter)::str::alltrim+" &" )
        sck_client::sclose
    end 


