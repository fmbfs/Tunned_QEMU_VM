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
cd awesome-project/
packagemanager install
```

And state what happens step-by-step.

### Building

If your project needs some additional steps for the developer to build the
project after some code changes, state them here:

```shell
./configure
make
make install
```

Here again you should state what actually happens when the code above gets
executed.

### Deploying / Publishing

In case there's some step you have to take that publishes this project to a
server, this is the right time to state it.

```shell
packagemanager deploy awesome-project -s server.com -u username -p password
```

And again you'd need to tell what the previous code actually does.

## Features

What's all the bells and whistles this project can perform?
* Allocate hardware resources to be used by the virtual machine, and not be disturbed by any other processes running.
* It enables CPU Isolation
* It enables HugePages (with the max size provided by the Host Architecture)
* If you get really randy, you can even fine tune the virtual hard drive.

## Configuration

Here you should write what are all of the configurations a user can enter when
using the project.

#### Argument 1
Type: `String`  
Default: `'default value'`

State what an argument does and how you can use it. If needed, you can provide
an example below.

Example:
```bash
awesome-project "Some other value"  # Prints "You're nailing this readme!"
```

#### Argument 2
Type: `Number|Boolean`  
Default: 100

Copy-paste as many of these as you need.

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
