#!/bin/bash

#------------------------------------------------------------------
#FUNTIONS

# Create cpu set
create_cset(){
    sudo cset shield --cpu=${vCPU_PINNED} --threads --kthread=on
}

# Delete_cset
delete_cset(){
    #the sleep may or maynot be needed
    sleep 5
    sudo cset shield -r
}