#!/bin/bash

########################
# 00-makeusers.sh
#
# Make linux users for the 'users' disco ball
# Each user is represented as a key under ${HOSTNAME}/users, with the value
# of each key being a list of useradd/usermod compatible command line flags
# that are passed, one each, directly into usermod/useradd
########################

HOSTNAME=$(hostname)

RETVAL=0

for op in present absent
do
    for username in $(disco-param keys ${HOSTNAME}/users/${op})
    do
	disco-linux-ents user $username $op
	RETVAL=$(expr $RETVAL + $?)
    done
done

exit $RETVAL