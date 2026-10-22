#!/bin/sh
curl -L --output xpdf-4.06.tar.gz https://dl.xpdfreader.com/xpdf-4.06.tar.gz
ls -al xpdf-4.06.tar.gz
tar -xvzf xpdf-4.06.tar.gz
cd xpdf-4.06
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ../
make install
ls build
cp xpdf/pdftotext /usr/local/bin/pdftotext
pdftotext -v
RESULT=$?
cd ../../
rm -Rf xpdf-4.06 xpdf-4.06.tar.gz /etc/install-xpdf-tools.sh

if [ "$RESULT" != 99 ] 
then
    >&2 echo 'ERROR: pdftotext exited with a bad code'
    exit 1
else
    exit 0
fi