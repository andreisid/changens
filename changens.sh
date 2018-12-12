#!/bin/bash

function showUsage {
   cat << HEREDOC

   Usage: $progname [-i|--interface=<int_name>] [-n|--namespace=<namespace>] [-h|--h|-help|--help]

   optional arguments:
     -h, --help           Show this help message and exit
     -i, --interface <int_name>        Name of the wireless interface to move to a new netwok space
     -n, --namespace <namespace>       Network namespace to move the interface to
     -c, --conf <file>                 Configuration file for logging to WPA wireless network

    To run a process in a namespace do: ip netns exec <namespace> <process>
    Example: ip netns exec wifi curl ifconfig.me
             ip netns exec wifi bash; su - myuser; DISPLAY=:0 firefox  
HEREDOC
}

# Remove interface from namespace. 
function rollback {
ip netns exec ${NAMESPACE} iw phy $PHY_INTERFACE set netns 1 || exit
echo "Interface ${INTERFACE} moved out of ${NAMESPACE}"
systemctl restart wpa_supplicant 
echo "Restarted wpa_supplicant"
ip netns delete wifi
echo "Namespace ${NAMESPACE} deleted"
exit
}

if [ "$#" == 0 ]; then
showUsage
fi
# Default values
INTERFACE="wlan0"
PHY_INTERFACE="phy0"
NAMESPACE="wifi"
CONF_FILE="./wpa_supplicant.conf"
for i in "$@"
do
case $i in
    -i=*|--interface=*)
    INTERFACE="${i#*=}" # http://tldp.org/LDP/abs/html/string-manipulation.html  - substring removal
    shift # past argument=value
    ;;
    -n=*|--namespace=*)
    NAMESPACE="${i#*=}"
    shift # past argument=value
    ;;
    -c=*|--conf=*)
    CONF_FILE="${i#*=}"
    shift # past argument=value
    ;;
    -h|--help|-help|--h)
    showUsage
    exit
    ;;
    -r|--rollback)
    rollback
    shift # past argument=value
    ;;
    
    *)
          # unknown option
    ;;
esac
done

# Remove interface from namespace. 
function rollback {
ip netns exec ${NAMESPACE} iw phy $(cat /sys/class/net/${INTERFACE}/phy80211/name) set netns 1 || exit
echo "Interface ${INTERFACE} moved out of ${NAMESPACE}"
systemctl restart wpa_supplicant 
echo "Restarted wpa_supplicant"
ip netns delete wifi
echo "Namespace ${NAMESPACE} deleted"
}

# Check if the namespace already exists, and create it if not
exists=0
for i in $(ip netns)
do 
if [ "$NAMESPACE" == "$i" ]; then 
    exists=1
    break
fi
done
if [ $exists == 0 ]; then 
    ip netns add $NAMESPACE; 
    echo "Namespace ${NAMESPACE} created"
else 
    echo "Namespace ${NAMESPACE} already exists. Skipping ..."
fi

# If it doesn't exist it create resolv.conf file for the namespace
if [ ! -d /etc/netns/${NAMESPACE} ]; then
    mkdir -p /etc/netns/${NAMESPACE}
fi
if [ ! -f /etc/netns/${NAMESPACE}/resolv.conf ]; then
    echo "nameserver 8.8.8.8" > /etc/netns/${NAMESPACE}/resolv.conf
    echo "Created /etc/netns/${NAMESPACE}/resolv.conf file"
fi

# If the interface specified is wireless, move it to the specified namespace, or exit the script
# 
export PHY_INTERFACE=$(cat /sys/class/net/${INTERFACE}/phy80211/name)
if [ "/sys/class/net/${INTERFACE}/phy80211/name" ]; then
    iw phy $PHY_INTERFACE set netns "$(ip netns exec ${NAMESPACE} sh -c 'sleep 1 >&- & echo "$!"')"
    echo "Moved interface ${INTERFACE} to ${NAMESPACE} network namespace "
else
    echo "Interface ${INTERFCE} is not wreless. Quitting ..."
exit 1
fi

if [ -f $CONF_FILE ]; then
    killall wpa_supplicant || exit
    echo "Killed wpa_supplicant"
    ip netns exec ${NAMESPACE} wpa_supplicant -B -i ${INTERFACE} -c "${CONF_FILE}"  || exit
    echo "Connected to wireless AP"
    ip netns exec ${NAMESPACE} dhclient ${INTERFACe} || exit
    echo "IP assigned"
    ip netns exec ${NAMESPACE} ip a|| exit
else 
    cat << HEREDOC
Config file for WPA AP is missing. Interface ${INTERFACE} is now moved to ${NAMESPACE} namespace, but not connected to any wireless AP.
In order to connect please run the script with a config file. Se provided config as example
HEREDOC
fi


