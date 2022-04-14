#!/bin/bash

#------------------------------------------------------------------
#Defaults 
#default error handeling
set -euo pipefail
#set -euox pipefail

#------------------------------------------------------------------
#FUNCTIONS
#print_error -- Error handler function
print_error()
{
    echo "Error: $1"; exit 1
}

#------------------------------------------------------------------
#MAIN
#Allocate resources of the host
./host_resources_allocation.sh

#Fine tune QEMU
#Benchmark/Tracing