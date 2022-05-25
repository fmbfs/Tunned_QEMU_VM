#!/bin/bash

###########################################################################
#DEFAULTS

Disk_Size="${5:-40}"
Cluster_Size="${6:-64}K"
# 1Mb for 8Gb using 64Kb. Make it cluster size fit no decimals.
# The value that is beeing divided by is the range that 1Mb of that 
# cluster size can reach
case "${Cluster_Size}" in
"64K")
    L2_calculated=$(( ${Disk_Size}/8 + 1 ))
    L2_Cache_Size="${L2_calculated}M"
    shift
    ;;
"128K")
    L2_calculated=$(( ${Disk_Size}/16 + 1 ))
    L2_Cache_Size="${L2_calculated}M"
    shift
    ;;
"256K")
    L2_calculated=$(( ${Disk_Size}/32 + 1 ))
    L2_Cache_Size="${L2_calculated}M"
    shift
    ;;
"512K")
    L2_calculated=$(( ${Disk_Size}/64 + 1 ))
    L2_Cache_Size="${L2_calculated}M"
    shift
    ;;
"1024K")
    L2_calculated=$(( ${Disk_Size}/128 + 1 ))
    L2_Cache_Size="${L2_calculated}M"
    shift
    ;;
"2048K")
    L2_calculated=$(( ${Disk_Size}/256 + 1 ))
    L2_Cache_Size="${L2_calculated}M"
    shift
    ;;
esac

echo "${Cluster_Size}"