#!/bin/bash

#------------------------------------------------------------------
#FUNCTIONS

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

delete_cset