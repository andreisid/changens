# changens

 ### This script is used for moving the wireless interface to a different network namespace and connect it to an WPA AP.


 ### Usage: 
 
     changens.sh [-i|--interface=<int_name>] [-n|--namespace=<namespace>] [-h|--h|-help|--help]
 
     optional arguments
       -i, --interface <int_name>        Name of the wireless interface to move to a new netwok space
       -n, --namespace <namespace>       Network namespace to move the interface to
       -c, --conf <file>                 Configuration file for logging to WPA wireless network
       -h, --help           Show this help message and exit
 
 ### Notes
 
Default value for the wireless interface is: wlan0   
Default value for the network namespace is: wifi  
Default value for the WPA config file is: ./wpa_supplicant.conf  

### wpa_supplicant.conf 
The file should look like this:

      ctrl_interface=/var/run/wpa_supplicant
      update_config=1

      network={
	    ssid="hotspot"
	    psk=b6123123102839482309480928340028828035216732b
      }
    
In order to generate the network={...} part you can run the following commmand:
      
      wpa_passphrase my_essid my_password >> wpa_supplicant.conf
      
   __my_essid__ is the name of the wireless network the interface will connect to  
   __my_password__ is the WPA password used by the network  

If you do not configure properly the config file, the interface will be moved to the new namespace, but it will not connect to any wireless network

### Example 

      ./changens.sh -i=wlan0 -n=my_ns           # will move the interface to my_ns namespace 
      ip netns exec wifi curl ifconfig.me       # will make a request from the new network namespace       
      ip netns exec wifi bash; su - myuser; DISPLAY=:0 firefox      # will run firefox from the new network namespace 

### Todo

- Add support for ethernet interfaces
- Add support for WEP and unsecured AP

