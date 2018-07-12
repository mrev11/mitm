



#include <sys/socket.h>
#include <cccapi.h>


void _clp_socket_lookahead(int argno)
{
    CCC_PROLOG("socket_lookahead",1);
    int socketfd=_parni(1);
    unsigned char c=0;
    recv(socketfd,&c,1,MSG_PEEK);
    _retni((int)c);    
    CCC_EPILOG();
}

//vajon a windowson van-e ilyen?
//visszaadja a socket-bol olvashato kovetkezo bajtot
//a bajtot nem veszi ki az olvasasi sorbol
//tehat azt a kovetkezo recv ujbol beolvassa




