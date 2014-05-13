#!/bin/bash
touch /tmp/wps.log
touch /tmp/reaver_out.log
tail -f /tmp/wps.log | while read line;do echo "rpush auto_pins '$line'"|redis-cli;done &
tail -f /tmp/reaver_out.log | while read line;do echo "rpush pin_aps '$line'"|redis-cli;done &
/usr/local/sbin/airmon-ng start rtl8187
