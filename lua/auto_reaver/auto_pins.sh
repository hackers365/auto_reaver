#!/bin/bash
INTERFACE=mon0
wash -i $INTERFACE -o /tmp/wps.log &
#ssids=`cat /tmp/ap.log|sed -n '3,$p'|sort -r -n -k3|head -n15|cut -d' ' -f1`
pid=$!
curl 'http://127.0.0.1/util?act=set_auto_pin_pid&type=set&pid='$pid
sleep 60
kill -9 $pid
echo '$exit$' >> /tmp/wps.log

