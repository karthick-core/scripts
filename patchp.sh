#!/bin/bash

pver=$(python -V 2>&1|awk '{print $NF}')
echo $pver
if [ "$pver" != "2.7.16" ]
then
rm /usr/bin/python2
ln -s /usr/local/bin/python2.7 /usr/bin/python2
pver=$(python -V 2>&1|awk '{print $NF}')
else
rm /usr/bin/python2
ln -s /usr/bin/python2.7 /usr/bin/python2
pver=$(python -V 2>&1|awk '{print $NF}')
fi

echo "Default python changed to Version $pver"
