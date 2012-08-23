#!/bin/bash

########################
# 00-makegroups.sh
#
# Make linux groups for the 'group' disco ball
# Each group is represented as a key under ${HOSTNAME}/groups, with the value
# of each key being a list of groupadd/groupmod compatible command line flags
# that are passed, one each, directly into groupmod/groupadd
########################

HOSTNAME=$(hostname)

RETVAL=0

for op in present absent
do
    for groupname in $(disco-param keys ${HOSTNAME}/groups/${op})
    do
	disco-linux-ents group $groupname $op
	RETVAL=$(expr $RETVAL + $?)
    done
done

exit $RETVAL

