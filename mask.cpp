

#include <cccapi.h>

namespace _nsp_websocket{

void _clp_mask(int argno)
{
    CCC_PROLOG("websocket.mask",2);
    char *buf=_parb(1);
    int len=_parblen(1);
    char *key=_parb(2);
    if( 4!=_parblen(2) )
    {
        ARGERROR();
    }
    for(int i=0; i<len; i++)
    {
        buf[i]^=key[i%4];
    }
    stack=base+1; // retv(base);
    CCC_EPILOG();
}

}//namespace