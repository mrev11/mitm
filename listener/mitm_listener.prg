




function main()

local sck_listener:=socket()
local sck_client
local session_counter:=0


    ? sck_listener::setsockopt("REUSEADDR",.t.)
    ? sck_listener::bind("localhost",3128)
    ? sck_listener::listen
    
    while(.t.)
        sck_client:=sck_listener::accept
        run( "mitm_session.exe"+sck_client::str+" "+(++session_counter)::str::alltrim+" &" )  //vagy thread
        sck_client::sclose
    end 


