#!/bin/bash

#vEr como sacar valores noutro script bash
# ao executarmso aqui o script do qemu temos de mandar os cpus, por defeito esta o 3 e 7
#Args for CPU isolation and pinning
ARG3="${3:-3}"
ARG4="${4:-7}"
# Pinned vCPU
vCPU_PINNED="${ARG3},${ARG4}"

#create cpu set
create_cset(){
    sudo cset shield --cpu=${vCPU_PINNED} --threads --kthread=on
}

#execute something inside the set
execute_in_cset(){
    #sudo cset shield -e gnome-terminal
    sudo cset shield -e qemu_kvm.sh
}

#list cpu sets
list_cset(){
    cset set -l
}

#delete_cset
delete_cset(){
    sudo cset shield -r
}

create_cset
list_cset
execute_in_cset