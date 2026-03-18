#!/bin/bash
cd /usr/share/enigma2/ || exit 1
rm -rf /usr/share/enigma2/picon

cd /tmp || exit 1
rm -f master.zip*
rm -rf Picons_220x132_LightOnTransparent-master/

wget --no-check-certificate -O master.zip https://github.com/djgueto/Picons_220x132_LightOnTransparent/archive/master.zip
unzip -o -q master.zip

rm -rf /usr/share/enigma2/picon
mv Picons_220x132_LightOnTransparent-master/ /usr/share/enigma2/picon/

rm -rf Picons_220x132_LightOnTransparent-master/
rm -f master.zip*
exit 0
