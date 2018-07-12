## mitm - Man In The Middle HTTP proxy

Egyszerű, CCC-ben írt **mitm** (man in the middle) HTTP(S) proxy Linuxon és BSD-ken. 
Mire jó?

* Szórakoztató.

* Tanulmányozni lehet vele a HTTP üzeneteket.

* Ki lehet belőle nézni egy csomó okosságot: 
  socket programozás, SSL programozás, autentikáció, kulcsgenerálás.

* Le lehet tiltani bizonyos site-okat. Ha például elegem van belőle, 
  hogy a browser ezredszer is konnektál a *safebrowsing.googleapis.com*-ra 
  vagy a *twitter.com*-ra  (a mobilinternetem terhére), akkor azt letilthatom.
  Ezzel egyrészt gyorsítom a böngészést, másrészt spórolok.

Man in the middle: Azaz a böngésző és a szerver üzeneteit közvetíti egymásnak. 
Eközben a HTTP üzeneteket elemzi, hogy értse, mikor melyik és mekkora üzenetrész 
(header, body, chunk) következik, és hogy mikor mennyit kell olvasni a socketekből. 
Ehhez  dekódolni kell a titkosított üzeneteket, majd a továbbítás 
előtt újra titkosítani.  A böngésző ellenőrzi (ellenőrizné) a szerverek tanúsítványát, 
a program ezek helyett röptében olyan tanúsítványt generál, amit a böngésző elfogad.

Látni lehet belőle, milyen egy CCC program hangulata. Hasonló, mint a pythoné, 
kivéve, hogy  nem interpretált, hanem fordított/linkelt programról van szó. 
Az egész program kb. 700 sor (pythonban is kb. ennyi volna). Csak a legelemibb 
dolgokat tudja, de az olyan egyszerűbb oldalak, mint a *hup.hu* vagy a *github.com* 
már böngészhetőek rajta keresztül. Működnek vele a webapp (websocketes) alkalmazások
is, SSL-lel vagy anélkül.

### Fordítás

CCC környezetben az *m* (make) bash script mindent lefordít.
Két végrehajtható program keletkezik:

* listener/mitm-listener.exe

* mitm-session.exe

Előbbi egy listener, ami a böngésző kapcsolódása után indítgatja a másodikat, 
ami a tényleges munkát végzi.


### Üzembe helyezés

Installálni kell a Linuxunkon az *openssl* csomagot, ami szükséges a kulcsgeneráláshoz
és tanúsítvány készítéshez.

A böngészőben (a Firefox authorities tabjában) importálni kell a *site/mitm-cert.pem*
tanúsítványt. Ez kell ahhoz, hogy a Firefox elfogadja a felkeresett szerverek eredeti
tanúsítványa helyett automatikusan készülő tanúsítványokat. 

A Firefox *Preferences* menüjének *Network Proxy* szakasza alatt be kell állítani a
*Manual proxy configuration*-t **localhost:3128**-ra (ez a default). A Chromium browsernek
nincs ilyen dialogboxa, helyette parancssorból indítva lehet beállítani a proxyt: 

    chromium-browser --proxy-server="localhost:3128"


### Használat
    
A proxyt egy xterm ablakban helyből (a mitm directoryból) indítom az *s* (start) bash scripttel.
A program a terminálban listázza, merre kalandozik a böngésző, egyúttal lehet nézegetni 
a headereket. Ugyanez az infó session-ok szerinti bontásban megőrződik a 
*log/log-\** fájlokban.
    

A *sites-visited* fájlban feljegyzésre kerül, hogy a böngésző mely site-okat 
látogatta meg.

A meglátogatott site-ok listája a *sites-visited1* fajlban is megőrződik, 
de ebben minden site csak 1-szer lesz feltüntetve.

Ha bizonyos site-ok látogatását le akarom tiltani, akkor létrehozom a
*sites-prohibited*  nevű fájlt, amiben felsorolom a kerülendő helyeket. 
Ugyanaz a formátum, mint ahogy az előbbi fájlok is keletkeznek.

A tiltás miatt elutasított site-ok listája gyűlik a *sites-refused* fájlban.







 
    


 
     

 