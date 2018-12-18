#!/bin/bash

function showUsage {
   cat << HEREDOC

   Usage: $progname [-i|--interface=<int_name>] [-n|--namespace=<namespace>] [-h|--h|-help|--help]

   optional arguments:
     -i, --interface <int_name>        Name of the wireless interface to move to a new netwok space
     -n, --namespace <namespace>       Network namespace to move the interface to
     -c, --conf <file>                 Configuration file for logging to WPA wireless network
     -h, --help           Show this help message and exit
    To run a process in a namespace do: ip netns exec <namespace> <process>
    Example: ip netns exec wifi curl ifconfig.me
             ip netns exec wifi bash; su - myuser; DISPLAY=:0 firefox  
HEREDOC
}

# Remove interface from namespace. 
function rollback {
    local INTERFACE=$(head -1 /tmp/.changens.cfg)
    local PHY_INTERFACE=$(head -2 /tmp/.changens.cfg|tail -1)
    local NAMESPACE=$(head -3 /tmp/.changens.cfg|tail -1)
    local CONF_FILE=$(head -4 /tmp/.changens.cfg|tail -1)

ip netns exec ${NAMESPACE} iw phy ${PHY_INTERFACE} set netns 1 && echo "Interface ${INTERFACE} moved out of ${NAMESPACE}"
systemctl restart wpa_supplicant && echo "Restarted wpa_supplicant"
ip netns delete wifi && echo "Namespace ${NAMESPACE} deleted"
}

# Create network Namespace, add interface to namespace, connect interface to Access Point
function start {

# Check if the namespace already exists, and create it if not
local exists=0
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
}


# Starts the execution of the script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

readonly PROGNAME=$(basename $0)
readonly PROGDIR=$(readlink -m $(dirname $0))
readonly ARGS="$@"

# Default values 
INTERFACE="wlan0"
PHY_INTERFACE="phy0"
NAMESPACE="wifi"
CONF_FILE="./wpa_supplicant.conf"

for i in ${ARGS}
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
    shift
    exit
    ;;
    -r|--rollback)
    rollback
    shift # past argument=value
    exit
    ;;
    
    *)
          # unknown option
    ;;
esac
done

# Starts the execution of the script

# If interface provided does not exist, exit.
is_interface=$(ip a|grep $INTERFACE)
if [[ -z "$is_interface" ]]; then
   echo "Provided interface does not exist" 
   exit 1
fi

PHY_INTERFACE=$(cat /sys/class/net/${INTERFACE}/phy80211/name)
echo $INTERFACE > /tmp/.changens.cfg
echo $PHY_INTERFACE >> /tmp/.changens.cfg
echo $NAMESPACE >> /tmp/.changens.cfg
echo $CONF_FILE >> /tmp/.changens.cfg

start

