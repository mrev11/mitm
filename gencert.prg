

************************************************************************************************
function gencert(host)

local curdir:="/"+curdir()
local certdir:=curdir+"/cert"           //itt gyulnek a certificate-ek
local mkcert:=certdir+"/mkcert"         //certificate keszito script
local pemfile:=certdir+"/"+host+".pem"  //ezt kell elkesziteni

static script:=<<SCRIPT>>#!/bin/bash

NAME=$1
DAYS=1000

SITE_CA=../site/mitm.pem
SITE_SRL=../site/serial.srl


##############################################################################
# make config file
##############################################################################

cat >config-$NAME <<-EOF

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
    -out $NAME-req.pem\
    -newkey rsa:2048\
    -keyout $NAME-key.pem\
    -nodes\
    -config config-$NAME


##############################################################################
# sign cert request
##############################################################################

openssl x509 -req\
    -in $NAME-req.pem\
    -out $NAME-cert.pem\
    -days $DAYS\
    -CA $SITE_CA\
    -CAkey $SITE_CA\
    -CAserial $SITE_SRL\
    -CAcreateserial\
    -extfile config-$NAME\
    -extensions req_ext


##############################################################################
# concatenate all results
##############################################################################

cat $NAME-cert.pem  >>$NAME-key.pem
rm  $NAME-cert.pem
rm  $NAME-req.pem
rm  config-$NAME
mv  $NAME-key.pem   $NAME.pem


##############################################################################
<<SCRIPT>>

local cmd

    if( !file(mkcert) )
        dirmake(certdir)
        memowrit(mkcert,script)
        chmod(mkcert,0b111111101) /775
    end

    if( !file(pemfile) )
        cmd:="cd CERTDIR; mkcert HOST; cd CURDIR"
        cmd::=strtran("CERTDIR",certdir)
        cmd::=strtran("HOST",host)
        cmd::=strtran("CURDIR",curdir)
        run( cmd )
        ? "GENERATED", pemfile
        ?
    end
    
    return pemfile

************************************************************************************************
    