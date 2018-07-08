# mitm - Man In The Middle HTTP proxy

Egyszerű, CCC-ben írt mitm (man in the middle) HTTP(S) proxy. Mire jó?

* Szórakoztató.

* Tanulmányozni lehet vele a HTTP üzeneteket.

* Ki lehet belőle nézni egy csomó fontos dolgot: 
  socket programozás, ssl programozás, autentikáció, kulcsgenerálás.

* Le lehet tiltani bizonyos site-okat. Ha például elegem van belőle, 
  hogy a browser tízezredszer is konnektál a safebrowsing.googleapis.com-ra 
  (a mobilinternetem terhére), akkor azt letilthatom.

Man in the middle: Azaz a böngésző és a szerver üzeneteit közvetíti egymásnak. 
Eközben a HTTP üzeneteket elemzi, hogy értse, mikor melyik és mekkora üzenetrész 
(header, body, chunk) következik, és hogy mikor mennyit kell olvasni a socketekből. 
Ehhez nyilvánvalóan dekódolni kell a titkosított üzeneteket, majd a továbbítás 
előtt újra titkosítani.  A böngésző ellenőrzi (ellenőrizné) a szerverek tanúsítványát, 
a program ezek helyett röptében olyan tanúsítványt generál, amit a böngésző elfogad.

Látni lehet belőle, milyen egy CCC program hangulata. Hasonló, mint a pythoné, 
kivéve, hogy  nem interpretált, hanem fordított/linkelt programról van szó. 
Az egész program kb. 700 sor (pythonban is kb. ennyi volna). Csak a legelemibb 
dolgokat tudja, de az olyan egyszerűbb oldalak, mint a hup.hu vagy a github.com 
már böngészhetőek rajta keresztül.

 