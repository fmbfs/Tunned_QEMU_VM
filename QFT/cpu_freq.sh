#!/bin/bash

#------------------------------------------------------------------
#FUNCTIONS

#set the cpu to performances
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