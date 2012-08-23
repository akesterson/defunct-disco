#!/bin/bash

#########################
#
# 00-installpkgs.sh
#
# For each package listed under $(hostname)/packages/[present|absent], 
# install/remove the package there using the package management 
# commands under $(hostname)/packages/commands/[present|absent].
#########################

HOSTNAME=$(hostname)
RETVAL=0

for op in present absent
do
    PKGCMD=$(disco-param get ${HOSTNAME}/packages/commands/${op})
    for pkgname in $(disco-param keys ${HOSTNAME}/packages/${op})
    do
	$PKGCMD $pkgname
	RETVAL=$(expr $RETVAL + $?)
    done
done

exit $RETVAL