#!/bin/bash

#create cpu set
create_cset(){
    sudo cset shield --cpu=${vCPU_PINNED} --threads --kthread=on
}

#delete_cset
delete_cset(){
    sudo cset shield -r
}

