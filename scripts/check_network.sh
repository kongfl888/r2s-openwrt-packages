#!/bin/sh
# [K] (C)2020
# http://github.com/kongfl888

get_ipv4_address() {
  if ! if_status=$(ifstatus $1); then
    echo "-1"
    return 1
  fi
  #empty or ip
  echo $if_status | jsonfilter -e "@['ipv4-address'][0]['address']"
}

get_eth_up() {
  if ! if_status=$(ifstatus $1); then
    echo "-1"
    return 1
  fi
  #true or false
  echo $if_status | jsonfilter -e "@['up']"
}

get_eth_pending() {
  if ! if_status=$(ifstatus $1); then
    echo "-1"
    return 1
  fi
  #true or false
  echo $if_status | jsonfilter -e "@['pending']"
}

get_eth_error() {
  if ! if_status=$(ifstatus $1); then
    echo "-1"
    return 1
  fi
  #strings or empty
  echo $if_status | jsonfilter -e "@['errors']"
}

DATE=`date +[%Y-%m-%d]%H:%M:%S`

logger 'Check Network: Script started!'
echo $DATE" Check Network: Script started!" > /tmp/check_network.log

lgetipfail=0
wgetipfail=0
landown=0
wandown=0
wpending=0
werror=0

while :; do
    sleep 30

    if ! lan_addr1=$(get_ipv4_address lan); then
        lgetipfail=1
    fi

    if ! wan_addr1=$(get_ipv4_address wan); then
        if [ "$wan_addr1" = "-1" ]; then
            wgetipfail=1
        else
            #empty
            wgetipfail=2
        fi
    fi

    if ! lanup=$(get_eth_up lan); then
        landown=1
    fi

    if ! wanup=$(get_eth_up wan); then
        wandown=1
    fi

    if wanpend=$(get_eth_pending wan); then
        if [ "$wanpend" = "true" ]; then
            wpending=1
        fi
    fi

    DATE=`date +[%Y-%m-%d]%H:%M:%S`

    if [ $lgetipfail -ne 0 -o $wgetipfail -eq 1 ]; then
        logger "[Check Network] eth0/1 lost. network restarting"
        echo $DATE" [Check Network] eth0/1 lost. network restarting" >> /tmp/check_network.log
        /etc/init.d/network restart >/dev/null 2>&1
    elif [ $landown -ne 0 ]; then
        logger "[Check Network] lan is down. network restarting"
        echo $DATE" [Check Network] lan is down. network restarting" >> /tmp/check_network.log
        /etc/init.d/network restart >/dev/null 2>&1
    elif [ $wandown -ne 0 -a $wpending -eq 0 ]; then
        logger "[Check Network] wan is down. network restarting"
        echo $DATE" [Check Network] wan is down. network restarting" >> /tmp/check_network.log
        /etc/init.d/network restart >/dev/null 2>&1
    else
        echo $DATE" 1st while break." >> /tmp/check_network.log
        logger "Check Network: 1st check is ok. Running 2nd check."
        break
    fi
    sleep 90
done

fail_countl=0
fail_countw=0

while :; do
    sleep 30s

    wpending=0

    lan_addr=$(get_ipv4_address lan)
    wan_addr=$(get_ipv4_address wan)

    if wanpend=$(get_eth_pending wan); then
        if [ "$wanpend" = "true" ]; then
            wpending=1
        fi
    fi

    if werrorstr=$(get_eth_error wan); then
        if [ -n "$werrorstr" ]; then
            werror=1
        fi
    fi

    DATE=`date +[%Y-%m-%d]%H:%M:%S`

    # try to connect
    if ping -W 1 -c 1 "$lan_addr" >/dev/null 2>&1; then
        # No problem!
        if [ $fail_countl -gt 0 ]; then
            logger 'Check Network: LAN problems solved!'
            echo $DATE" Check Network: LAN problems solved!" >> /tmp/check_network.log
        fi
        fail_countl=0
    else
        fail_countl=$((fail_countl + 1))
    fi
    if ping -W 1 -c 1 "$wan_addr" >/dev/null 2>&1; then
        # No problem!
        if [ $fail_countw -gt 0 ]; then
            logger 'Check Network: WAN problems solved!'
            echo $DATE" Check Network: WAN problems solved!" >> /tmp/check_network.log
        fi
        fail_countw=0
    else
        if [ "$wan_addr" = "-1" ];then
            fail_countw=$((fail_countw + 1))
        elif [ $wpending -eq 0 ]; then
            fail_countw=$((fail_countw + 1))
        elif [ $errors -ne 0 ]; then
            fail_countw=$((fail_countw + 1))
        fi
    fi

    if [ $fail_countl -eq 0 -a $fail_countw -eq 0 ]; then
        continue
    fi

    DATE=`date +[%Y-%m-%d]%H:%M:%S`

    # May have some problem
    logger "Check Network: Network may have some problems!"
    echo $DATE" Check Network: Network may have some problems!" >> /tmp/check_network.log

    fail_count=$(($fail_countl+$fail_countw))
  
    if [ $fail_count -ge 5 ]; then
        # try again!
        wpending=0
        werror=0
        lan_addr=$(get_ipv4_address lan)
        wan_addr=$(get_ipv4_address wan)

        if wanpend=$(get_eth_pending wan); then
            if [ "$wanpend" = "true" ]; then
                wpending=1
            fi
        fi

        if werrorstr=$(get_eth_error wan); then
            if [ -n "$werrorstr" ]; then
                werror=1
            fi
        fi

        mokl=0
        mokw=0
        if ping -W 1 -c 1 "$lan_addr" >/dev/null 2>&1; then
            mokl=1
        fi
        if ping -W 1 -c 1 "$wan_addr" >/dev/null 2>&1; then
            mokw=1
        elif [ "$wan_addr" = "-1" ]; then
            mokw=0
        elif [ $wpending -ne 0 ]; then
            mokw=1
        elif [ $werror -eq 0 ]; then
            mokw=1
        fi
        if [ $mokl -eq 1 -a $mokw -eq 1 ]; then
            continue
        fi

        DATE=`date +[%Y-%m-%d]%H:%M:%S`

        echo $DATE" Check Network: Network problem! Firewall reloading..." >> /tmp/check_network.log
        logger 'Check Network: Network problem! Firewall reloading...'
        /etc/init.d/firewall reload >/dev/null 2>&1
        sleep 30

        mokl=0
        mokw=0
        if ping -W 1 -c 1 "$lan_addr" >/dev/null 2>&1; then
            mokl=1
        fi
        if ping -W 1 -c 1 "$wan_addr" >/dev/null 2>&1; then
            mokw=1
        elif [ "$wan_addr" = "-1" ]; then
            mokw=0
        elif [ $wpending -ne 0 ]; then
            mokw=1
        fi

        wan_addr=`/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`
        if [ ! -n "$wan_addr" ]; then
            wan_addr=`/sbin/ifconfig eth0 | awk '/inet6/ {print $3}' | cut -d '/' -f1`
        fi
        pingt=`ping -c1 $wan_addr 2>&1`
        case $pingt in
            *permitted* ) mokw=0 ;;
        esac

        if [ $mokl -eq 1 -a $mokw -eq 1 ]; then
            continue
        fi

        DATE=`date +[%Y-%m-%d]%H:%M:%S`

        echo $DATE" Check Network: Network problem! Network reloading..." >> /tmp/check_network.log
        logger 'Check Network: Network problem! Network reloading...'
        /etc/init.d/network restart >/dev/null 2>&1
        sleep 80
    fi
done
