#!/bin/bash

#------------------------------------------------------------------
#FUNCTIONS
#trap for debug
trap(){
	echo "trap trap trap!!!!!!"
}

#set the cpu to performances
#should we chang eonly the ones we are using? i think not
set_performance(){
    for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
    do 
        echo "performance" > $file
    done
}

#set the cpu to powersave
set_powersave(){
    for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
    do 
        echo "powersave" > $file
    done
}

#set_performance
#set_powersave