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

You have to create two directories in the first run.
Just uncomment in the main part of the script the lines 236-239:
```shell
CHECK STRUCTURE
check_dir ${ISO_DIR}
check_dir ${QEMU_VD}
check_file ${OS_IMG}
```

## What actually happens when you execute the code above?

### Initial Configuration

By default the ```./qemu_kvm.sh``` launches tuned. 
Type ```./qemu_kvm.sh -h``` to see the options.

An personalized example:
```./qemu_kvm.sh -l disk ```
It will launch an untuned qemu script using the virtual hard drive named "disk"


## Developing

Here's a brief intro about what a developer must do in order to start developing
the project further:

```shell
git clone https://github.com/your/awesome-project.git
cd your_project_folder/
./qemu_kvm.sh
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
`-i -----> Install the OS via CDROM`
#### Argument 2
`-c -----> Creates a qcow2 image for OS`
#### Argument 3
`-l -----> Launch qemu OS machine.`
#### Argument 4
`-lt ----> Launch qemu OS machine with Pinned CPU.`
#### Argument 5
`-a -----> Show QEMU args that are currently beeing deployed.`
#### Argument 6
`-h -----> Show this help.`

## Contributing

If you'd like to contribute, please fork the repository and use a feature
branch. Pull requests are warmly welcome.
This was a project made for the last year report of the bachelor Degree in Electrical and Computer Engineering
from Polytechnic Institute of Porto (ISEP) together with CriticalTechworks (CTW).

## Links

Even though this information can be found inside the project on machine-readable
format like in a .json file, it's good to include a summary of most useful
links to humans using your project. You can include links like:

- Project homepage: https://your.github.com/awesome-project/
- Repository: https://github.com/your/awesome-project/
- Issue tracker: https://github.com/your/awesome-project/issues
  - In case of sensitive bugs like security vulnerabilities, please contact
    my@email.com directly instead of using issue tracker. We value your effort
    to improve the security and privacy of this project!
- Related projects:
  - Your other project: https://github.com/your/other-project/
  - Someone else's project: https://github.com/someones/awesome-project/


## Licensing

One really important part: Give your project a proper license. Here you should
state what the license is and how to find the text version of the license.
Something like:

"The code in this project is licensed under MIT license."
