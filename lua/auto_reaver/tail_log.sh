#!/bin/bash
pid=$1 
LOG_FILE=$2
seq_count=0
MAX_ERROR_COUNT=10
ENABLE_DEBUG=true
tail -f $LOG_FILE|while read line
do
    if echo $line|grep -q '[!]';then
        seq_count=$(($seq_count + 1)) 
        $EBABLE_DEUBG && echo $seq_count
        if [ $seq_count -eq $MAX_ERROR_COUNT ];then
            kill -SIGINT $pid
            exit
        fi
    elif echo $line|grep -q 'need exit';then
        echo 'tail log exit'
        exit
    else
        seq_count=0
    fi
done &
