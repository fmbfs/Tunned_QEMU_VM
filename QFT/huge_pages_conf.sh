#!/bin/bash

#It is recommended to use the largest supported hugepage size for the best performance.
page_size(){
    if [ "$(cat /proc/cpuinfo | grep -oh pse | uniq)" = "pse" ]; then 
        #echo "2048K = OK"
        :
    else 
        #echo "2048K = NO"
        print_error
    fi

    #1G = 1048576kB
    if [ "$(cat /proc/cpuinfo | grep -oh pdpe1gb | uniq)" = "pdpe1gb" ]; then
        #echo "1G = OK"
        :
    else 
        #echo "1G = NO"
        print_error
    fi
}

#allocate huge pages size
allocate_hugepages(){
    sysctl -w vm.nr_hugepages=$(nproc)

    for i in $(find /sys/devices/system/node/node* -maxdepth 0 -type d);
    do
        #16 means 16G os ram allocated to huge pages. 8 is enough for our laptop
        echo 8 > "$i/hugepages/hugepages-1048576kB/nr_hugepages";
    done

    echo "1GB pages successfully enabled"
}

list(){
    grep Huge /proc/meminfo
}

#free allocated huge pages size
free_hugepages(){
    
    sysctl -w vm.nr_hugepages=$(nproc)

    for i in $(find /sys/devices/system/node/node* -maxdepth 0 -type d);
    do
        echo 0 > "$i/hugepages/hugepages-1048576kB/nr_hugepages";
    done

    echo "1GB pages successfully disabled"
}
