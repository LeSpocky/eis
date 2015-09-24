#!/bin/bash

lcd4linux -l >> /tmp/lcd4linux.$$ &
/var/install/bin/show-doc.cui -t "List of LCD4LINUX driver:" -f /tmp/lcd4linux.$$
rm -f /tmp/lcd4linux.$$
