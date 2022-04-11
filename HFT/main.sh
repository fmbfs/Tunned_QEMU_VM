#!/bin/bash

#Host fine tune

#This part runs before the flutter app
#to check if the host has everything
#able to run the tunned

#default error handeling
#ver se acrescent x a frente do o
set -euo pipefail

#trap cmd_exit EXIT
#cmd_exit()
##{
#    echo "qjajadhkjs"
#}

#error handler function
print_error()
{
    echo "Error: $1"; exit 1
}

#To link other files
#./ to run independent if needed
./iommu_vdt_check.sh
echo " "
./iommu_on.sh
echo " "
./valid_groups.sh
echo " "
./L3_cache_number.sh

    
