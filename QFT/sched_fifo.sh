#!/bin/bash

# NOTE:
# "$NAME" is a variable we set to differentiate VMs from each other on the host system. It should be identical to the "-name" qemu argument
# it is necessary to wait until QEMU has finished booting an OS before changing to a real-time process priority or it will halt virtual disk access

sched(){
    # get parent PID of QEMU VM                                
    PARENT_PID=$(pstree -pa $(pidof qemu-system-x86_64) | grep ${ARG2} | cut -d','  -f2 | cut -d' ' -f1)
    # set all threads of parent PID to SCHED_FIFO 99 priority
    pstree -pa $PARENT_PID | cut -d','  -f2 | cut -d' ' -f1 | xargs -L1 echo "chrt -f -p 99" | bash
    echo "Changing to highest priority (99) done!"
}