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

#1G = 1048576kB
big_pages="1048576"
small_pages="2048"

#verificar este numero afeta os valores listados
num_pages="16"

#------------------------------------------------------------------
# FUNCTIONS

# It is recommended to use the largest supported hugepage size for the best performance.
page_size(){
    
    #big pages
    if [ "$(cat /proc/cpuinfo | grep -oh pdpe1gb | uniq)" = "pdpe1gb" ]; then
        hugepages "${big_pages}" 

    else
        #smal pages
        if [ "$(cat /proc/cpuinfo | grep -oh pse | uniq)" = "pse" ]; then 
            hugepages "${small_pages}" "${num_pages}"
        else 
            print_error "HP_2 - ${small_pages} Not OK"
        fi
        print_error "HP_1 - ${big_pages} Not OK"
    fi
}

# Allocate huge pages size
# see if there is a better way to define the max number of huge pages
hugepages(){
    sysctl -w vm.nr_hugepages="${num_pages}"

    for i in $(find /sys/devices/system/node/node* -maxdepth 0 -type d);
    do
        echo "${num_pages}" > "$i/hugepages/hugepages-${1}kB/nr_hugepages";
    done
    echo "HugePages - ${1} - successfully enabled!"
}

# List huge pages info
list(){
    grep Huge* /proc/meminfo
}

# Free allocated huge pages size
free_hugepages(){

    sysctl -w vm.nr_hugepages="0"

    for i in $(find /sys/devices/system/node/node* -maxdepth 0 -type d);
    do
        echo 0 > "$i/hugepages/hugepages-${1}kB/nr_hugepages";
        echo 0 > "$i/hugepages/hugepages-${2}kB/nr_hugepages";
    done

    echo "HugePages successfully disabled."
}

#list
#page_size
#list
#free_hugepages "${big_pages}" "${small_pages}"
#list