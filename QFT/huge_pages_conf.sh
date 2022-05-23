#!/bin/bash

#------------------------------------------------------------------
#DEFAULTS

#x will print all
#set -euox pipefail
set -euo pipefail

#trap for debug
trap(){
	echo "trap trap trap!!!!!!"
}

#print_error -- Error handler function
print_error(){
    echo "Error: $1"; exit 1
}

#mount directory if needed
#mkdir -p  /dev/hugepages/
#mount -t hugetlbfs hugetlbfs /dev/hugepages/

#1G = 1048576kB
big_pages="1048576"
small_pages="2048"

# RAM for VM
VD_RAM="${3:-8}"
#echo "${VD_RAM}"

#the correct calculation is RAM_GB/pageSize_MB to get the number of pages.
#20 is to get a little bit more see if makes any difference
total_pages=$((( ${VD_RAM} * ${big_pages} / ${small_pages}) + 20 ))
#total_pages=$(( ${VD_RAM} * ${big_pages} / ${small_pages} ))
#echo "${total_pages}"

#------------------------------------------------------------------
# FUNCTIONS

# It is recommended to use the largest supported hugepage size for the best performance.
page_size(){
    #big pages
    if [ "$(grep Hugepagesize /proc/meminfo | awk '{print $2}')" = "${big_pages}" ]; then
        hugepages "${big_pages}" "${VD_RAM}"
        echo "HP_1 - ${big_pages} OK"
    else
        echo "HP_1 - ${big_pages} Not avalilable"
        #small pages
        if [ "$(grep Hugepagesize /proc/meminfo | awk '{print $2}')" = "${small_pages}" ]; then 
                hugepages "${small_pages}" "${total_pages}"
                echo "HP_2 - ${small_pages} OK"
        else
            print_error "HP_2 - ${small_pages} Not avalilable"
        fi      
    fi
}

# Allocate huge pages size
# see if there is a better way to define the max number of huge pages
hugepages(){
    sysctl -w vm.nr_hugepages="${2}"

    #disable THP 
    echo "never" > "/sys/kernel/mm/transparent_hugepage/enabled"
    echo "never" > "/sys/kernel/mm/transparent_hugepage/defrag"
    
    for i in $(find /sys/devices/system/node/node* -maxdepth 0 -type d);
    do
        echo "${2}" > "$i/hugepages/hugepages-${1}kB/nr_hugepages"    
    done
    echo "HugePages - ${1} - successfully enabled!"
}

# List huge pages info
list(){
    numastat -cm | egrep 'Node|Huge'
    grep Huge* /proc/meminfo
}

# Free allocated huge pages size
free_hugepages(){
    sysctl -w vm.nr_hugepages="0"

    #enable THP
    echo "always" > "/sys/kernel/mm/transparent_hugepage/enabled"
    echo "always" > "/sys/kernel/mm/transparent_hugepage/defrag"

    for i in $(find /sys/devices/system/node/node* -maxdepth 0 -type d);
    do
        echo 0 > "$i/hugepages/hugepages-${1}kB/nr_hugepages"
        echo 0 > "$i/hugepages/hugepages-${2}kB/nr_hugepages" 
    done
    echo "HugePages successfully disabled."
}

#hugeadm --explain

#------------------------------------------------------------------
#MAIN

#unmount directory if needed
#sudo umount /dev/hugepages

#list
#page_size
#list
#free_hugepages "${big_pages}" "${small_pages}"
#list