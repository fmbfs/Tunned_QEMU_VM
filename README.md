![Logo of the project](https://user-images.githubusercontent.com/91340451/167094022-ef4cf8fc-a67c-4b1f-b8e0-5034d4a531ce.svg)

# Improving the performance of VDT (Virtual Development Targets)
> By fine tuning the Host and Guest.

The project consists on using QEMU together with KVM to improve the performance of a VDT.
It is a setup to allow the user to launch a tuned virtual machine based on the Host Hardware.

## Installing / Getting started

This solution is built for Linux OS.
If any package is missing, during execute it will prompt you to install it.
This script has the purpose of beeing used to dynamically allocate resources,
so you must run it as 'sudo su' because it is modifying some Kernel options.

## What actually happens when you execute the code above?

### Initial Configuration

By default the ```./launcher.sh``` launches tuned. 
Type ```./launcher.sh -h``` to see the options.

## Developing

Here's a brief intro about what a developer must do in order to start developing
the project further:

```shell
git clone https://github.com/fmbfs/ctw.git
```
```shell
cd your_project_folder/
./launcher.sh
```

This will run a tuned qemu with isolated CPU's (the last group available in your host);
It will change the Kernel scheduler runtime to 98%;
After 20 seconds it will change the priority of all qemu processes to be the first in kernel.

## Features

This project can perform?

* Set cpu as performance
* It enables HugePages (with the max size provided by the Host Architecture)
* Set sched_rt_runtime_us to 98%
* It enables CPU Isolation via cset (it runs in parallel)
* After 20seconds from execute it changes the qemu process priority to 99

## Configuration

Here you should write what are all of the configurations a user can enter when
using the project.

#### Argument 1
`No args, just launched tunned by default`

## Contributing

If you'd like to contribute, please fork the repository and use a feature
branch. Pull requests are warmly welcome.
This was a project made for the last year report of the bachelor Degree in Electrical and Computer Engineering
from Polytechnic Institute of Porto (ISEP) together with CriticalTechworks (CTW).

## Links

- Project homepage: https://github.com/fmbfs/ctw.git
- Repository: https://github.com/fmbfs/ctw.git
- Issues:
  - In case of sensitive bugs like security vulnerabilities, please contact
    ctw02046@criticaltechworks.com directly. We value your effort
    to improve the security and privacy of this project!

## Licensing

License: https://choosealicense.com/licenses/gpl-3.0/
"The code in this project is licensed under GNU General Public License v3.0."
