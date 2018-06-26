

************************************************************************************************
function gencert(host)

local curdir:="/"+curdir()
local certdir:=curdir+"/cert"           //itt gyulnek a certificate-ek
local mkcert:=certdir+"/mkcert"         //certificate keszito script
local pemfile:=certdir+"/"+host+".pem"  //ezt kell elkesziteni

static script:=<<SCRIPT>>#!/bin/bash

NAME=$1
UNIQ=$2

DAYS=1000

SITE_CA=../site/mitm.pem
SITE_SRL=../site/serial.srl


##############################################################################
# make config file
##############################################################################

cat >config-$NAME$UNIQ <<-EOF

[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C=HU
ST=Hungary
L=Budapest
O=ComFirm
CN = $NAME

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.0 = localhost
DNS.1 = $NAME
DNS.2 = www.$NAME

EOF


##############################################################################
# make keypair and cert request
##############################################################################

openssl req\
    -new\
    -out $NAME$UNIQ-req.pem\
    -newkey rsa:2048\
    -keyout $NAME$UNIQ-key.pem\
    -nodes\
    -config config-$NAME$UNIQ


##############################################################################
# sign cert request
##############################################################################

openssl x509 -req\
    -in $NAME$UNIQ-req.pem\
    -out $NAME$UNIQ-cert.pem\
    -days $DAYS\
    -CA $SITE_CA\
    -CAkey $SITE_CA\
    -CAserial $SITE_SRL\
    -CAcreateserial\
    -extfile config-$NAME$UNIQ\
    -extensions req_ext


##############################################################################
# concatenate all results
##############################################################################

cat $NAME$UNIQ-cert.pem  >>$NAME$UNIQ-key.pem
rm  $NAME$UNIQ-cert.pem
rm  $NAME$UNIQ-req.pem
rm  config-$NAME$UNIQ
mv  $NAME$UNIQ-key.pem   $NAME.pem

##############################################################################


<<SCRIPT>>

local cmd

    if( !file(mkcert) )
        dirmake(certdir)
        memowrit(mkcert,script)
        chmod(mkcert,0b111111101) /775
    end

    if( !file(pemfile) )
        cmd:="cd CERTDIR; mkcert HOST PID; cd CURDIR"
        cmd::=strtran("CERTDIR",certdir)
        cmd::=strtran("HOST",host)
        cmd::=strtran("PID","-"+getpid()::str::alltrim)
        cmd::=strtran("CURDIR",curdir)
        run( cmd )
        ? "GENERATED", pemfile
        ?
    end
    
    return pemfile

************************************************************************************************
    