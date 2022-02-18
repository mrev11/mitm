#!/bin/bash
rm -f *.log
cp site/sites-visited1 ./sites-prohibited
listener/mitm_listener.exe
