

#define INDENT     chr(10)+"   "

#define DEBUGINFO  INDENT, "time            :", time(),         ;
                   INDENT, "frame_fin       :", frame_fin,      ;
                   INDENT, "frame_opcode    :", frame_opcode,   ;
                   INDENT, "frame_masked    :", frame_masked,   ;
                   INDENT, "frame_compress  :", frame_compress, ;
                   INDENT, "payload_len     :", payload_len,    ;    
                   INDENT, "timeout         :", timeout
                   

#define FRGSIZ 8192

#define TIMEOUT 10000 //millisec 


#define RECV(n)  (c:=buffer::substr(offset,n),offset+=n,c::len==n)

***************************************************************************************
function readmessage(buffer)

local err
local fragment,c,n
local frame_fin
local frame_opcode
local frame_masked
local frame_compress
local payload_len
local masking_key
local timeout:=TIMEOUT
local body
local offset:=1

    while(.t.)

        frame_fin       :=NIL
        frame_opcode    :=NIL
        frame_masked    :=NIL
        payload_len     :=NIL
        masking_key     :=NIL

        begin
            if( !RECV(1) )
                break("No opcode")
            else
                c::=asc
            end
            frame_fin:=(c::numand(0b10000000))!=0
            frame_opcode:=c::numand(0b00001111) //1=text 2=binary  8=close 9=ping 10=pong

            if( frame_compress==NIL )
                //(csak) az elso frame-ben
                //lehet beallitva a tomorites bit
                frame_compress:=(c::numand(0b01000000))!=0  //RSV1
            end

            if( !RECV(1) )
                break("No payload_len1")
            else
                c::=asc
            end
            frame_masked:=(c::numand(0b10000000))!=0
            payload_len:=c::numand(0b01111111)
    
            if( payload_len==126 )
                payload_len:=0
                for n:=1 to 2
                    if( !RECV(1) )
                        break("No payload_len2("+n::str::alltrim+")")
                    else
                        c::=asc
                    end
                    payload_len:=payload_len*256+c
                next
    
            elseif( payload_len==127 )
                payload_len:=0
                for n:=1 to 8
                    if( !RECV(1) )
                        break("No payload_len8("+n::str::alltrim+")")
                    else
                        c::=asc
                    end
                    payload_len:=payload_len*256+c
                next
            end

    
            if( frame_masked )
                if( !RECV(4) )
                    break("No masking_key")
                else
                    masking_key:=c
                end
            end

            if( !RECV(payload_len) )
                 break("Not enough data")
            else
                 fragment:=c
            end
    
            if( frame_masked )
                fragment::=websocket.mask(masking_key)
            end
            
        recover err <C>    
            //? err, DEBUGINFO
            return NIL
        end

        // fragmentation
        //  unfragmented message : A(FIN==1,OP!=0)  
        //  fragmented message   : B(FIN==0,OP!=0)  C(FIN==0,OP==0)*  D(FIN==1,OP==0)
        // control frames (ping, pong) are always unfragmented 
        // control frames may be injected in a fragmented message


        if( frame_opcode==0 ) //continuation
            //C|D eset
            if( body==NIL )
                body:=a""  
            end
            body+=fragment
            if( frame_fin )
                return if(frame_compress,decompress(body),body)
            end

        elseif( frame_opcode==1 ) //text
            //A|B eset
            body:=fragment
            if( frame_fin )
                return if(frame_compress,decompress(body),body)
            end
            
        elseif( frame_opcode==2 ) //binary
            //A|B eset
            body:=fragment
            if( frame_fin )
                return if(frame_compress,decompress(body),body)
            end


        elseif( frame_opcode==8 ) //close
            ? "close" //, DEBUGINFO
            return NIL

        elseif( frame_opcode==9 ) //ping
            ?? " ping" //, DEBUGINFO
            return a""

        elseif( frame_opcode==10 ) //pong
            ?? " pong" //, DEBUGINFO
            return a""

        else
            ? "Invalid opcode",DEBUGINFO
            return a""
        end
    end


***************************************************************************************
static function decompress(x)
static strm:=zlib.inflateinit2(-15) //winbit=15, 32K window, -15=RAW 
    //? "INFLATE", len(x), " ->"
    x:=zlib.inflate(strm,x+x"0000ffff")
    //?? len(x)
    return x


***************************************************************************************
static function compress(x)
static strm:=zlib.deflateinit2(NIL,-15)
static cnt:=0
    //? "DEFLATE", len(x), " ->"
    x:=zlib.deflate(strm,x,3) //Z_FULL_FLUSH
    x:=left(x,len(x)-4)
    //?? len(x)
    return x
    

***************************************************************************************

