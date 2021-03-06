![Logo of the project](https://user-images.githubusercontent.com/91340451/167094022-ef4cf8fc-a67c-4b1f-b8e0-5034d4a531ce.svg)

# Improving the performance of VDT (Virtual Development Targets)
> By fine tuning the Host and Guest.

The project consists on using QEMU together with KVM to improve the performance of a VDT.
It is a setup to allow the user to launch a tuned virtual machine based on the Host Hardware.

## Installing / Getting started

This solution is built for Linux OS.
If any package is missing, during execute it will prompt you to install them.
This script has the purpose of beeing used together with a "config.json" file.
So you must run it as 'sudo' because it is modifying some Kernel options.

## What actually happens when you execute the code above?

### Initial Configuration

By default the ```./launcher.sh``` launches the settings presented in the "config.json" file. 

## Developing

Here's a brief intro about what a developer must do in order to start developing
the project further:

```shell
git clone https://github.com/fmbfs/Tunned_QEMU_VM
```
```shell
cd your_project_folder/
./launcher.sh
```

## Features

This project can perform?

* Set cpu as performance
* It enables HugePages (with the max size provided by the Host Architecture)
* Set sched_rt_runtime_us to 98%
* It enables CPU Isolation via cset (it runs in parallel)
* It changes the qemu process priority to 99

## Configuration

To launch with 1Gib Huge Pages or Default.

#### Argument 1

"Name":"name of your VM. It must match the VSD that you want to run."

#### Argument 2

"RAM":"Total amount of RAM in GiB for your VM."

#### Argument 3

"VSD Cluster":"Set the value in KiB for the cluster size. ("64","128","256","512","1024","2048")."
Note that VSD is for Virtual Storage Device (the hard drive associated for the VM to use.)

#### Argument 4

"Cache Clean":"Time interval in seconds to clear the cache."

#### Argument 5

"Update Grub":"Enable 1GiB HugePages and isolation. yes/no"

## Contributing

If you'd like to contribute, please fork the repository and use a feature
branch. Pull requests are warmly welcome.
This was a project made for the last year report of the bachelor Degree in Electrical and Computer Engineering
from Polytechnic Institute of Porto (ISEP) together with CriticalTechworks (CTW).

## Links

- Project homepage: https://github.com/fmbfs/Tunned_QEMU_VM
- Repository: https://github.com/fmbfs/Tunned_QEMU_VM
- Issues:
  - In case of sensitive bugs like security vulnerabilities, please contact
    ctw02046@criticaltechworks.com directly. We value your effort
    to improve the security and privacy of this project!

## Licensing

License: https://choosealicense.com/licenses/gpl-3.0/
"The code in this project is licensed under GNU General Public License v3.0."
