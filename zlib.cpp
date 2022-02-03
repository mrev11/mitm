

#include <cccapi.h>
#include <memory.h>
#include <errno.h>
#include <assert.h>
#include <zlib.h>

#include <error.ch>

DEFINE_METHOD(operation);
DEFINE_METHOD(description);
DEFINE_METHOD(subsystem);
DEFINE_METHOD(gencode);
DEFINE_METHOD(subcode);
DEFINE_METHOD(severity);

#define CHUNK (128*1024)

namespace _nsp_zlib {

//-----------------------------------------------------------------------------------
void _clp_version(int argno)
{
    CCC_PROLOG("zlib.version",0);
    const char *ver=zlibVersion();
    _retcb(ver);
    CCC_EPILOG();
}

//-----------------------------------------------------------------------------------
void _clp_deflateinit2(int argno)
{
    //megjegyzes:
    //attol lesz a kimenet (zlib helyett) gzip format,
    //hogy windowBits-hez hozza van adva 16


    //megjegyzes:
    //1.2.8-ban a z_stream struct athelyezheto
    //1.2.11-ben tapasztalat szerint sajnos nem athelyezheto
    //ezert itt ugy hozom letre a strukturat
    //hogy visszatereskor is helyben maradjon
    //(_retblen peldaul rogton athelyezne)
    //ha a hivo program nem valtoztatja z_stream-et
    //peldaul nem csinal ilyet: strm:=strm[..]
    //akkor nem fog mozogni kesobb sem 

    CCC_PROLOG("zlib.deflateinit2",4);

    int level  = ISNIL(1) ? Z_DEFAULT_COMPRESSION : _parni(1);
    int winbit = ISNIL(2) ? 31 : _parni(2); //15=zlib format, 31=gzip format
    int memlev = ISNIL(3) ? 8 : _parni(3); 
    int strat  = ISNIL(4) ? Z_DEFAULT_STRATEGY : _parni(4); 

    z_streamp strm=(z_streamp)binaryl(sizeof(z_stream)); //vegleges hely!

    strm->zalloc     = Z_NULL;
    strm->zfree      = Z_NULL;
    strm->opaque     = Z_NULL;
    strm->avail_in   = 0;
    strm->next_in    = Z_NULL;

    int ret = deflateInit2 (     // gzip format
        strm, 
        level,          // compression level, default=Z_DEFAULT_COMPRESSION 
        Z_DEFLATED,     // method, kotelezoen Z_DEFLATED
        winbit,         // windowBits, 15[+16]  (+16=gzip format)
        memlev,         // memLevel, default=8
        strat );        // strategy,  default=Z_DEFAULT_STRATEGY 


    if( ret!=Z_OK )
    {
        _ret(); //NIL
    }
    else
    {
        _rettop(); //strm  
    }

    CCC_EPILOG( );
}


//-----------------------------------------------------------------------------------
void _clp_deflate(int argno)
{
    if( argno==1 )
    {
        _clp_deflateinit2(0);
        swap();
        logical(1);
        argno=3;
    }

    CCC_PROLOG("zlib.deflate",3);

    str2bin(base+1);
    z_streamp strm=(z_streamp)_parb(1);
    int lenstrm=_parblen(1);
    assert(lenstrm==(int)sizeof(z_stream)); 
    char *buf=_parb(2);
    int lenbuf=_parblen(2);
    int flush;
    
    if( ISNIL(3) )
    {
        flush=Z_NO_FLUSH;
    }
    else if( ISFLAG(3) )
    {
        flush=_parl(3)?Z_FINISH:Z_NO_FLUSH;
    }
    else
    {
        flush=_parni(3);
    }

    strm->next_in=(unsigned char*)buf;
    strm->avail_in=lenbuf;

    binaryl(0);

    // run deflate() on input until output buffer not full
    // finish compression if all of source has been read in
    int ret;
    char out[CHUNK+1];
    do 
    {
        strm->avail_out = CHUNK;
        strm->next_out = (unsigned char*)out;
        ret = deflate(strm, flush); // no bad return value 
        assert(ret != Z_STREAM_ERROR);  // strm struct is wrong

        int have = CHUNK - strm->avail_out;
        if( have>0  )
        {
            binarys(out,have);
            add();
        }
        
        // mindaddig ujrahivjuk deflate-et
        // amig mindent ki tud irni, amit akar 
        // ha maradt hely out-ban:  strm->avail_out!=0 -> kesz 
        // ha teleirta out-ot:  strm->avail_out==0  -> folytat

    } while (strm->avail_out == 0);
    assert(strm->avail_in == 0);     // all input will be used
        
    _rettop();

    if( flush == Z_FINISH )
    {
        //assert(ret == Z_STREAM_END); // stream will be complete
        (void)deflateEnd(strm);
    }

    CCC_EPILOG( );
}


//-----------------------------------------------------------------------------------
void _clp_inflateinit2(int argno)
{
    //megjegyzes:
    //attol hasznal (zlib helyett) gzip formatunot,
    //hogy windowBits-hez hozza van adva 16

    CCC_PROLOG("zlib.inflateinit2",1);

    int winbit = ISNIL(1) ? 31 : _parni(1); //15=zlib format, 31=gzip format

    z_streamp strm=(z_streamp)binaryl(sizeof(z_stream)); //vegleges hely!

    strm->zalloc     = Z_NULL;
    strm->zfree      = Z_NULL;
    strm->opaque     = Z_NULL;
    strm->avail_in   = 0;
    strm->next_in    = Z_NULL;

    int ret = inflateInit2 ( strm, winbit );

    if( ret!=Z_OK )
    {
        _ret(); //NIL
    }
    else
    {
        _rettop(); //strm
    }

    CCC_EPILOG( );
}

//-----------------------------------------------------------------------------------
void _clp_inflate(int argno)
{
    if( argno==1 )
    {
        _clp_inflateinit2(0);
        swap();
        logical(1);
        argno=3;
    }

    CCC_PROLOG("zlib.inflate",3);

    str2bin(base+1);
    z_streamp strm=(z_streamp)_parb(1);
    int lenstrm=_parblen(1);
    assert(lenstrm==(int)sizeof(z_stream)); 
    char *buf=_parb(2);
    int lenbuf=_parblen(2);
    int flush= ISNIL(3) ? Z_NO_FLUSH : (_parl(3) ? Z_FINISH : Z_NO_FLUSH);

    strm->next_in=(unsigned char*)buf;
    strm->avail_in=lenbuf;

    binaryl(0);

    // run inflate() on input until output buffer not full
    int ret;
    char out[CHUNK+1];
    do 
    {
        strm->avail_out = CHUNK;
        strm->next_out = (unsigned char*)out;
        ret = inflate(strm, Z_NO_FLUSH);
        assert(ret!=Z_STREAM_ERROR); // strm struct is wrong

        switch( ret ) 
        {
            case Z_STREAM_ERROR:
                //assert(ret!=Z_STREAM_ERROR);
                //fall through 

            case Z_NEED_DICT:
                //assert( ret!=Z_NEED_DICT ); 
                //fall through 

            case Z_DATA_ERROR:
                //assert( ret!=Z_DATA_ERROR ); 
                inflateEnd(strm);
                _clp_apperrornew(0);
                dup(); stringnb(trace->func);_o_method_operation.eval(2);pop();
                dup(); string(CHRLIT("Z_DATA_ERROR"));_o_method_description.eval(2);pop(); 
                dup(); number(ret);_o_method_subcode.eval(2);pop();  
                dup(); number(ES_ERROR);_o_method_severity.eval(2);pop();
                _clp_break(1);
                pop();  

            case Z_MEM_ERROR:
                //assert( ret!=Z_MEM_ERROR ); 
                inflateEnd(strm);
                _clp_apperrornew(0);
                dup(); stringnb(trace->func);_o_method_operation.eval(2);pop();
                dup(); string(CHRLIT("Z_MEM_ERROR"));_o_method_description.eval(2);pop(); 
                dup(); number(ret);_o_method_subcode.eval(2);pop();  
                dup(); number(ES_ERROR);_o_method_severity.eval(2);pop();
                _clp_break(1);
                pop();  
        }

        int have = CHUNK - strm->avail_out;
        if( have>0  )
        {
            binarys(out,have);
            add();
        }
        
        //ha teleirta out-ot:  strm->avail_out==0  -> folytat
        //ha maradt hely out-ban:  strm->avail_out!=0 -> kesz 

    } while (strm->avail_out == 0);
    assert(strm->avail_in == 0);     // all input will be used
        
    _rettop();

    if( flush || (ret==Z_STREAM_END) )
    {
        inflateEnd(strm);
    }

    CCC_EPILOG( );
}


//-----------------------------------------------------------------------------------
void _clp_gzerror(int argno)
{
    CCC_PROLOG("zlib.gzerror",1);
    gzFile file=(gzFile)_parp(1);
    int err;
    gzerror(file,&err);
    _retni(err);
    CCC_EPILOG();
}

//-----------------------------------------------------------------------------------
void _clp_gzdopen(int argno)
{

    CCC_PROLOG("zlib.gzdopen",2);
    str2bin(base+1);    
    int fd=_parni(1);
    char *mode=_parb(2); //mode:  "rb", "wb6"
    gzFile file=gzdopen(fd,mode); //pointer gxFile_s-re
    if( file )
    {
        _retp(file);
    }
    else
    {
        _ret(); 
    }
    CCC_EPILOG();
}

//-----------------------------------------------------------------------------------
void _clp_gzclose(int argno)
{
    CCC_PROLOG("zlib.gzclose",1);
    gzFile file=(gzFile)_parp(1);
    //printf("%lx\n",(unsigned long)file);fflush(0);
    _retl(gzclose(file)==Z_OK);
    CCC_EPILOG();
}


//-----------------------------------------------------------------------------------
void _clp_gzwrite(int argno)
{
    CCC_PROLOG("zlib.gzwrite",2);
    str2bin(base+1);    
    gzFile file=(gzFile)_parp(1);
    char *buf=_parb(2);
    int len=_parblen(2);
    _retni(gzwrite(file,buf,(unsigned)len));
    CCC_EPILOG();
}


//-----------------------------------------------------------------------------------
void _clp_gzread(int argno)  //mint a Clipper fread
{
    CCC_PROLOG("zlib.gzread",3);
    
    if( ISREFBIN(2) )
    {
        gzFile file=(gzFile)_parp(1);
        char *buf=REFBINPTR(2);
        unsigned long buflen=REFBINLEN(2);
        unsigned long cnt=_parnu(3);

        if( buflen<cnt )
        {
            error_siz("zlib.gzread",base,3);
        }

        //bufból másolatot csinálumk
        char *buf1=binaryl(buflen);
        memmove(buf1,buf,buflen);
        (base+1)->data.vref->value=*TOP();

        errno=0;
        _retni( gzread(file,buf1,cnt) );
    }
    else
    {
        ARGERROR();
    }
    
    CCC_EPILOG();
}

//-----------------------------------------------------------------------------------


} //namespace

