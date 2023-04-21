# print out the IP address of connected headset
adb shell ip addr show wlan0 | grep -o -E "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -1
# start the syncset app
adb shell "am start -S org.syncset.app/org.syncset.app.Activity"
