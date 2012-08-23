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

for username in $(disco-param keys ${HOSTNAME}/users)
do
    NAME=$username
    PARAMS=$(disco-param get ${HOSTNAME}/users/${NAME})
    getent passwd | grep "^${NAME}" 2>&1 | disco-shutup
    RETVAL=$?
    if [ $RETVAL -eq 0 ] && [ "$PARAMS" == "" ]; then
	userdel ${NAME}
    elif [ $RETVAL -ne 0 ]; then
	usermod ${PARAMS} ${NAME}
    elif [ "$PARAMS" != "" ]; then
	useradd ${PARAMS} ${NAME}
    fi
done
