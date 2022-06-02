#!/bin/bash

#------------------------------------------------------------------
#FUNCTIONS
#trap for debug
trap(){
	echo "trap trap trap!!!!!!"
}

#vCPU_PINNED="3,7"

# Create cpu set
create_cset(){
    sudo cset shield --cpu=${vCPU_PINNED} --threads --kthread=on >/dev/null
}

# Delete_cset
#while not cset: done keep trying...needs to be done
delete_cset(){
    sudo cset set -d system
    while [[ $(sudo cset set -d system) =~ "done" ]] 
    do 
        sudo cset set -d system
    done

    sudo cset set -d user
}

#------------------------------------------------------------------
#MAIN

#create_cset
#cset set -l
#sleep 2
#delete_cset
#cset set -l