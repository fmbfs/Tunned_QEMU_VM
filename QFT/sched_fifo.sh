#!/bin/bash

#------------------------------------------------------------------
#FUNCTIONS

# NOTE:
# "$NAME" is a variable we set to differentiate VMs from each other on the host system. It should be identical to the "-name" qemu argument
# it is necessary to wait until QEMU has finished booting an OS before changing to a real-time process priority or it will halt virtual disk access

sched(){
    while :; do
       if [ -f  ${boot_logs_path} ]; then
            while IFS= read -r line; do
                cur_bytes=$(echo ${line} | awk '{print $5}')
                if [[ ${cur_bytes} != '512' ]]; then
                    # get parent PID of QEMU VM                                
                    PARENT_PID=$(pstree -pa $(pidof qemu-system-x86_64) | grep ${ARG2} | cut -d','  -f2 | cut -d' ' -f1)
                    # set all threads of parent PID to SCHED_FIFO 99 priority
                    pstree -pa $PARENT_PID | cut -d','  -f2 | cut -d' ' -f1 | xargs -L1 echo "chrt -f -p 99" | bash
                    #echo "Changing to highest priority (99) done!"
                    exit 0
                fi
            done < ${boot_logs_path}
        fi
    done 
}

#------------------------------------------------------------------
#MAIN

#sched