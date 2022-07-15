#!/bin/bash

# Default error handling
#set -euox pipefail
set -euo pipefail

# Traps
trap cmd_err ERR
trap cmd_err INT
trap cmd_exit EXIT

cmd_err() {
    exit 99
}

# Clean up on exit
cmd_exit() {
    if [ -z "${PRINT_HELP+x}" ] || ! "${PRINT_HELP}" ; then
        stop_vcar
        clean_network
        ! ${WITH_NO_ENG_MODE} && stop_install_eng_token
    fi
}

# We need this function very early to enable printing errors during script
# configuration. User-defined error messages are kept to aid on debugging.
print_error() {
    >&2 echo "ERROR: $1"
    exit 1
}

print_warning() {
    if [ "$#" -ne 1 ] && [ ${1} = "-n" ] ; then
        echo -n "WARNING: ${@:2}"
    else
        echo "WARNING: $@"
    fi
}

# Check we are really bash, since this script has many bashisms
if [ ! "$BASH_VERSINFO" ] ; then
    print_error "Script must run with bash"
fi

# check we have sourced the sdk environment needed for qemu, mkfs, and variables
# this needs to be run before anything else since variables etc can be affected by this
[ -z "${CONFIG_SITE}" ] && print_error "SDK environment needs to be initialised first."
[ -z "${SDKTARGETSYSROOT}" ] && print_error "SDK environment needs to be initialised first."

# VARS
QEMU_BIN=$(which qemu-system-aarch64)
QEMU_DIR=$(dirname "${CONFIG_SITE}")/vdt
MKFS_BIN=$(which mkfs.ext4)
if [ -z "$(which docker)" ] ; then
    print_warning "docker could not be found"
else
    DOCKER_BIN=$(which docker)
fi
if [ -z "$(which qemu-img)" ] ; then
    print_warning "qemu-img could not be found"
else
    QEMU_IMG_BIN=$(which qemu-img)
fi
USER_ID=$(id -u)
TMP_DIR="${HOME}/vdt_tmp"
KERNEL=$(2> /dev/null find "${QEMU_DIR}/kernel" -name "Image*.bin" | head -1)
ROOTFS_DIR=${QEMU_DIR}/rootfs
SNAPSHOTS_DIR=${ROOTFS_DIR}/snapshots
VCAR_DIR=${QEMU_DIR}/vcar
VCAR_BIN=${VCAR_DIR}/vcar
LSMF_TOOLS_PATH="${QEMU_DIR}/lsmf-tools"
TOKENS_PATH="${QEMU_DIR}/tokens"
QEMU_CONFIG_EXEC="${QEMU_DIR}/scripts/qemu_config.sh"
BOOT_LOGS_PATH="${QEMU_DIR}/boot_logs.txt"

WITH_NETWORK=true
WITH_SDK_ROOTFS=false
WITH_YOCTO_ROOTFS=true
WITH_STALE_ROOTFS=false
WITH_X11=false
WITH_VCAR_SERVER=false
WITH_VCAR_CLIENT=false
WITH_NO_ENG_MODE=false
WITH_TMP_SNAPSHOT=false
WITH_PERFORMANCE=false

PRINT_HELP=false

# FUNCTIONS
set_vars() {
    # Avoid having to re-set permissions
    run_sudo chown -R "${USER}":"${USER}" "${QEMU_DIR}"

    DISTRO=$(cat "${ROOTFS_DIR}/DISTRO")
    MACHINE=$(cat "${ROOTFS_DIR}/MACHINE")
    TARBALL_ROOTFS=$(find "${ROOTFS_DIR}" -name "${DISTRO}-*-bmw-image-bmt-${MACHINE}.rootfs.tar.bz2" | head -1)
    TARBALL_HMI=$(find "${ROOTFS_DIR}" -name "${DISTRO}-*-hmi-${MACHINE}.rootfs.tar.bz2" | head -1)
    TARBALL_VARSYS=$(find "${ROOTFS_DIR}" -name "${DISTRO}-*-bmw-image-bmt-varsys-${MACHINE}.rootfs.tar.bz2" | head -1)
    TARBALL_USERDATA=$(find "${ROOTFS_DIR}" -name "${DISTRO}-*-bmw-image-bmt-userdata-${MACHINE}.rootfs.tar.bz2" | head -1)

    GPT_LAYOUT_SCHEMA=$(find "${ROOTFS_DIR}" -name "${DISTRO}-*-bmw-image-bmt-gpt-${MACHINE}-layout.txt" | head -1)
    IMAGE_ROOTFS=${ROOTFS_DIR}/rootfs.ext4
    IMAGE_HMI=${ROOTFS_DIR}/hmi.ext4
    IMAGE_VARSYS=${ROOTFS_DIR}/varsys.ext4
    IMAGE_USERDATA=${ROOTFS_DIR}/userdata.ext4
    RAW_IMAGE_CONTAINER=${ROOTFS_DIR}/emmc.raw
    QCOW2_IMAGE_CONTAINER=${ROOTFS_DIR}/emmc.qcow2
    if [ -z "${SNAPSHOT_IMG+x}" ] ; then
        if [ "${WITH_PERFORMANCE}" ] ; then
            IMAGE_CONTAINER="${QCOW2_IMAGE_CONTAINER}"
        else
            IMAGE_CONTAINER="${RAW_IMAGE_CONTAINER}"
        fi
    else
        IMAGE_CONTAINER="${SNAPSHOTS_DIR}/${SNAPSHOT_IMG}"
    fi
    IMAGE_FORMAT="${IMAGE_CONTAINER##*.}"

    # image size is in gigabytes
    IMAGE_SIZE=4
    IMAGE_SIZE_MULTIPLIER=1

    KERNEL_PARAMS="root=/dev/vda1 ro mem=4G console=ttyAMA0,115200 console=tty loglevel=7 audit=0"

    QEMU_ARGS_ORIGINAL=( \
                "-monitor" "null" \
                "-object" "rng-random,filename=/dev/random,id=rng0" \
                "-device" "virtio-rng-pci,rng=rng0" \
                "-cpu" "cortex-a57" \
                "-smp" "3" \
                "-machine" "type=virt" \
                "-m" "4G" \
                "-nodefaults" \
                "-serial" "mon:stdio" \
                "-kernel" "${KERNEL}" \
                "-drive" "file=${IMAGE_CONTAINER},id=disk0,format=${IMAGE_FORMAT},if=none,cache=none" \
                "-device" "virtio-blk-pci,drive=disk0" \
                )
    QEMU_ARGS=( \
                "-monitor" "null" \
                "-object" "rng-random,filename=/dev/random,id=rng0" \
                "-device" "virtio-rng-pci,rng=rng0" \
                "-cpu" "max,pdpe1gb,kvm=off,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time" \
                "-smp" "3" \
                "-machine" "accel=kvm,kernel_irqchip=on" \
                "-m" "4G" \
                "-nodefaults" \
                "-serial" "mon:stdio" \
                "-kernel" "${KERNEL}" \
                "-drive" "file=${IMAGE_CONTAINER},id=disk0,format=${IMAGE_FORMAT},if=none,cache=none" \
                "-device" "virtio-blk-pci,drive=disk0" \
                "-mem-path" "/dev/hugepages" \
                "-mem-prealloc" \
                "-rtc" "base=localtime,clock=host" \
                ) # check problems using different archs because kvm is being used

    VCAR_ARGS=( \
                "--telnet" "2000" \
                "--debug" "0" \
                "setup.scp" \
                )
}

print_help() {
    cat <<EOF
Usage: $(basename $0) [OPTION]..."
Run BMT VDT emulator.

    -h, --help            See this help
        --no-network      Disable network setup attempt for QEMU
        --sdk-rootfs      Use the rootfs from your SDK sysroots
        --stale-rootfs    Do not reconstruct filesystem (use last launched image)
        --x11             Boot QEMU using a X11 window
        --no-eng-mode     Do not install engineering mode token
        --tmp-snapshot    No changes are saved to the VDT image
        --snapshot-img    Create and run QCOW2/QED snapshot of original image
        --loadvm          Load VM snapshot in QCOW2 image
        --aarch64         Run VDT on an ARM machine (adaptations made to QEMU arguments)

    Notes:
        - Temporary snapshots       It is not possible to save a VM snapshot;
        - Using snapshot image      Rootfs generation is skipped;
        - VM snapshots              Only possible in QCOW2 images;
        - VM snapshots management   After running VDT press CTRL+A C to use QEMU monitor. Stop
                                    emulation before save/load a VM snapshot. After loading you
                                    can resume VDT execution. Use the same keybinds to exit QEMU
                                    monitor.

EOF
}

request_input() {
    while true; do
        read -p "$* [y/n]: " yn
        case $yn in
            [Yy]*) return 0  ;;
            [Nn]*) echo "Skipped" ; return  1 ;;
        esac
    done
}

process_requirements() {
    # test for root or sudo
    if cat /proc/1/cgroup | grep -q "docker\|lxc" ; then
        echo "Container environment detected. Unsetting sudo.."
        CMD_SUDO=""
    elif [ "$(id -u)" -ne "0" ] && [ -z "$(command -v sudo)" ]; then
        print_error "\"sudo\" command not found, need root permissions to run this script."
    elif [ "$(id -u)" -ne "0" ]; then
        CMD_SUDO=("$(command -v sudo)" -E)
    else
        unset CMD_SUDO
    fi
}

run_sudo() {
    if [ -z ${CMD_SUDO} ] ; then
        "$@"
    else
        "${CMD_SUDO[@]}" "$@"
    fi
}

process_args() {
    # process all input arguments
    for i in "$@"; do
        case "$i" in
        "-h"|"--help")
            PRINT_HELP=true
            print_help
            exit 0
            ;;
        "--sdk-rootfs")
            WITH_SDK_ROOTFS=true
            shift
            ;;
        "--stale-rootfs")
            WITH_STALE_ROOTFS=true
            shift
            ;;
        "--no-network")
            WITH_NETWORK=false
            shift
            ;;
        "--x11")
            WITH_X11=true
            shift
            ;;
        "--with-vcar-server")
            WITH_VCAR_SERVER=true
            shift
            ;;
        "--with-vcar-client")
            WITH_VCAR_CLIENT=true
            shift
            ;;
        "--no-eng-mode")
            WITH_NO_ENG_MODE=true
            shift
            ;;
        "--tmp-snapshot")
            WITH_TMP_SNAPSHOT=true
            shift
            ;;
        --snapshot-img=*)
            SNAPSHOT_IMG="${i#*=}"
            shift
            ;;
        --loadvm=*)
            LOADVM="${i#*=}"
            shift
            ;;
        "--aarch64")
            IN_AARCH64=true
            shift
            ;;
        "--performance")
            WITH_PERFORMANCE=true
            shift
            ;;
        *)
            print_error "Unrecognised option: $i"
            shift
            ;;
        esac
    done
}

process_post_args() {
    if ${WITH_NETWORK}; then
        QEMU_ARGS=( "-device" "virtio-net-pci,netdev=net0,mac=CA:FE:BA:BE:BE:EF" \
                    "-netdev" "type=tap,id=net0,ifname=qemu_tap0,script=no,downscript=no" \
                    "${QEMU_ARGS[@]}");
    fi

    if ! ${WITH_X11}; then
        QEMU_ARGS=("-display" "none" "${QEMU_ARGS[@]}");
    fi

    if ${WITH_SDK_ROOTFS}; then
        IMAGE_SIZE_MULTIPLIER=2
        WITH_YOCTO_ROOTFS=false
    else
        IMAGE_SIZE_MULTIPLIER=1
        WITH_YOCTO_ROOTFS=true
    fi

    if [ ! -z "${SNAPSHOT_IMG+x}" ] || "${WITH_PERFORMANCE}" ; then
        [ ! -f "${RAW_IMAGE_CONTAINER}" ] || WITH_STALE_ROOTFS=true
    fi

    if "${WITH_TMP_SNAPSHOT}" ; then
        QEMU_ARGS+=("-snapshot")
    fi

    if [ -z "${SNAPSHOT_IMG+x}" ] ; then
        QEMU_ARGS+=("-device" "virtio-keyboard-pci")
    fi

    if [ ! -z "${LOADVM+x}" ] ; then
        QEMU_ARGS+=("-loadvm" "${LOADVM}")
    fi

    if [ ! -z "${IN_AARCH64+x}" ] ; then
        size_args="${#QEMU_ARGS[@]}"
        for ((i=0;i<size_args;i++)) ; do
            [[ "${QEMU_ARGS[${i}]}" == "-cpu" ]] && QEMU_ARGS[((i+1))]="host" && break
        done
        QEMU_ARGS+=("-enable-kvm")
    fi

    if "${WITH_PERFORMANCE}" ; then
        [ -f "${QEMU_CONFIG_EXEC}" ] || print_error "${QEMU_CONFIG_EXEC} does not exist!"
    fi
}

create_image_container() {
    emmc_size=$(expr "${IMAGE_SIZE}" \* "${IMAGE_SIZE_MULTIPLIER}")

    # skip if a container already exists with the right size (in MB)
    B2MB_div=$((1024**2))
    G2MB_mul=$((1024**1))
    if [ -e "${RAW_IMAGE_CONTAINER}" ]; then
        container_size=$(stat -c '%s' ${RAW_IMAGE_CONTAINER})
        if [ "$(expr "${container_size}" / ${B2MB_div})" == "$(expr "${emmc_size}" \* ${G2MB_mul})" ]; then
            echo "Skipping container (${emmc_size}G) generation."
            return
        fi
    fi

    # generate the block storage with the gpt layout similar to the target
    echo "Creating image container of size ${emmc_size}G"
    dd if=/dev/zero "of=${RAW_IMAGE_CONTAINER}" bs=1G "count=${emmc_size}"
    generate-gpt-layout.sh "${RAW_IMAGE_CONTAINER}" "${GPT_LAYOUT_SCHEMA}" "${IMAGE_SIZE_MULTIPLIER}" \
        || print_error "Failed to generate GPT Layout"
}

update_image_container() {
    # inject the ext4 images into the partition spaces
    # can only operate on a container with a sector size of 512
    # calculate offsets from container depending on the 512 sector size
    set -x
    sgdisk "${RAW_IMAGE_CONTAINER}" -p | grep "Sector size (logical): 512 bytes" || \
        print_error "Cannot operate on image container with sector size not equal to 512 bytes"

    inject_err_msg() { print_error "Failed to inject $1 into the partition space"; }

    # inject rootfs
    write-partition.sh "${RAW_IMAGE_CONTAINER}" "root_a" "${IMAGE_ROOTFS}" || inject_err_msg 'root_a'
    write-partition.sh "${RAW_IMAGE_CONTAINER}" "root_b" "${IMAGE_ROOTFS}" || inject_err_msg 'root_b'

    # inject varsys
    write-partition.sh "${RAW_IMAGE_CONTAINER}" "varsys" "${IMAGE_VARSYS}" || inject_err_msg 'varsys'

    # inject hmi container
    write-partition.sh "${RAW_IMAGE_CONTAINER}" "cont_a" "${IMAGE_HMI}" || inject_err_msg 'cont_a'
    write-partition.sh "${RAW_IMAGE_CONTAINER}" "cont_b" "${IMAGE_HMI}" || inject_err_msg 'cont_b'

    # inject userdata
    write-partition.sh "${RAW_IMAGE_CONTAINER}" "userdata" "${IMAGE_USERDATA}" || inject_err_msg 'userdata'
    set +x
}

create_ext4_img() {
    p_name=${1}
    img_name=${2}
    img_path=${3}
    img_tar=${4}

    size=$(grep "^${p_name} " "${GPT_LAYOUT_SCHEMA}" | awk '{print $5}')
    size=$(get-bytes.py "${size}")
    size=$(expr "${size}" / 1024 / 1024 \* ${IMAGE_SIZE_MULTIPLIER})
    echo "Generating ${img_name} ext4 image (${size}M)"
    dd if=/dev/zero "of=${img_path}" bs=1M "count=${size}"
    unpacked_dir=${ROOTFS_DIR}/unpacked-$(basename "${img_path}")
    rm -rf "${unpacked_dir}"
    mkdir -p "${unpacked_dir}"
    echo "Unpacking ${img_tar} to ${unpacked_dir}"
    run_sudo tar xf "${img_tar}" -C "${unpacked_dir}"
    echo "Creating ext4 image for ${img_name}"
    run_sudo "${MKFS_BIN}" "${img_path}" -d "${unpacked_dir}"
    echo "Done!"
}

install_block_coldplug() {
    # Make sure that vdt block devices exist before mounting
    f_rule="${1}/etc/systemd/system/${2}"
    if [ -f "${f_rule}" ] ; then
        run_sudo sed -i "s/rt.slice/rt.slice\nExecStart=\/bin\/udevadm trigger --type=devices --subsystem-match=block/" "${f_rule}"
    fi
}

rem_wdg_tmr() {
    for arg in "$@"; do
        if [[ "${arg}" = *"service" ]] ; then
            service_file="${unpacked_dir}/etc/systemd/system/${arg}"
            if [ -f "${service_file}" ] ; then
                run_sudo sed -Ei "s/WatchdogSec=[0-9]+/WatchdogSec=0/" "${service_file}"
            else
                print_warning "rem_wdg_tmr: Could not find ${arg} in ${unpacked_dir}."
            fi
        fi
    done
}

rem_timeout() {
    for arg in "$@"; do
        if [[ "${arg}" = *"service" ]] ; then
            service_file="${unpacked_dir}/etc/systemd/system/${arg}"
            if [ -f "${service_file}" ] ; then
                run_sudo sed -i '/Timeout/d' "${service_file}"
                run_sudo sed -i "s/\[Service\]/\[Service\]\nTimeoutSec=infinity/" "${service_file}"
            else
                print_warning "rem_timeout: Could not find ${arg} in ${unpacked_dir}."
            fi
        fi
    done
}

convert_raw_2_format() {
    [ -f "${RAW_IMAGE_CONTAINER}" ] || print_error "VDT raw image does not exist"
    run_sudo ${QEMU_IMG_BIN} create -F raw -f "${IMAGE_FORMAT}" -b "${RAW_IMAGE_CONTAINER}" "${IMAGE_CONTAINER}"
    run_sudo chown ${USER} "${IMAGE_CONTAINER}"
}

create_filesystem() {
    # auto-generate the ext filesystem image from the SDK rootfs

    if ${WITH_STALE_ROOTFS}; then
        echo "Skipping rootfs generation because --stale-rootfs is set"
        [ -f "${RAW_IMAGE_CONTAINER}" ] || print_error "VDT image does not exist"
    else
        echo "Generating image container"
        create_image_container

        size=$(grep "^root_a " "${GPT_LAYOUT_SCHEMA}" | awk '{print $5}')
        size=$(get-bytes.py "${size}")
        size=$(expr "${size}" / 1024 / 1024 \* ${IMAGE_SIZE_MULTIPLIER})
        echo "Generating rootfs ext4 image (${size}M)"
        [[ -n "${CMD_SUDO}" ]] && print_warning "sudo rights will be requested to generate the ext4 filesystem image."
        dd if=/dev/zero "of=${IMAGE_ROOTFS}" bs=1M "count=${size}"
        if ${WITH_YOCTO_ROOTFS}; then
            unpacked_dir=${ROOTFS_DIR}/unpacked-$(basename "${IMAGE_ROOTFS}")
            rm -rf "${unpacked_dir}"
            mkdir -p "${unpacked_dir}"
            echo "Unpacking ${TARBALL_ROOTFS} to ${unpacked_dir}"
            run_sudo tar xf "${TARBALL_ROOTFS}" -C "${unpacked_dir}"

            # Remove Watchdog & Timeout timers from node0 services to avoid them
            # from failing due to decreased performance wrt HW target
            rem_wdg_tmr "nodestatemanager.service" "partman.service" "sysfunc.service" "recovery-manager.service" \
                        "dlt-system.service" "firewalldz.service" "log-trace-manager.service" "kostalcapi.service" \
                        "system-telemetry.service" "secure-datetime-client.service"

            rem_timeout "partman.service" "recovery-manager.service" "firewalldz.service"

            # set nodestatemanager.service type to simple because the notify
            # procedure does not work on the VDT and causes a systemd timeout
            # during boot.
            run_sudo sed -i "s/Type=notify/Type=simple/" "${unpacked_dir}/etc/systemd/system/nodestatemanager.service"

            # Avoid loading HW-specific kernel modules
            run_sudo rm -f "${unpacked_dir}/etc/modules-load.d/caamrng.conf"

            # Avoid hmi from running since we don't support graphics on the BMT VDT
            run_sudo sed -i "s/\[Unit\]/\[Unit\]\nConditionVirtualization=no/" "${unpacked_dir}/etc/systemd/system/container-hmi.service"

            # Remove hw-specific devices from early-target
            run_sudo sed -i "s/mmcblk0p3/vda3/" "${unpacked_dir}/etc/systemd/system/udev-early-trigger.service"
            run_sudo sed -i "s/mmcblk0p6/vda7/" "${unpacked_dir}/etc/systemd/system/udev-early-trigger.service"
            run_sudo sed -i '/mmc.*/d' "${unpacked_dir}/etc/systemd/system/udev-early-trigger.service"
            run_sudo sed -i '/5b040000/d' "${unpacked_dir}/etc/systemd/system/udev-early-trigger.service"
            run_sudo sed -i '/kostal.*/d' "${unpacked_dir}/etc/systemd/system/udev-early-trigger.service"

            # Remove this early-target dependency because it's not compatible with the VDT.
            # socnet0 is created afterwards and this creates a timeout.
            run_sudo sed  -i 's/sys-subsystem-net-devices-socnet0.device//g' "${unpacked_dir}/lib/systemd/system/systemd-networkd.service"

            # Moves service to getty.target.wants and renames it to serial-getty@ttyAMA0.service,
            # ttyAMA0 is the serial device used by the VDT for user I/O.
            run_sudo mv -f "${unpacked_dir}/etc/systemd/system/debug.target.wants/serial-getty@ttymxc0.service" "${unpacked_dir}/etc/systemd/system/getty.target.wants/serial-getty@ttyAMA0.service"

            # Disable EnhancedTestability for now. Request a fix if ever needed.
            run_sudo sed -Ei "s/\[Unit\]/\[Unit\]\nConditionVirtualization=no/" "${unpacked_dir}/etc/systemd/system/enhanced-testability.service"

            # Set PasswordAuthentication as yes to protect ssh connections.
            run_sudo sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" "${unpacked_dir}/etc/ssh/sshd_config"

            # Move sshd.socket to early.target.wants to enable ssh connections.
            run_sudo mv -f "${unpacked_dir}/etc/systemd/system/debug.target.wants/sshd.socket" "${unpacked_dir}/etc/systemd/system/early.target.wants/"

            # Install IOC Mock
            run_sudo sed -i "s/ExecStart=\/usr\/bin\/kostalcapi/ExecStart=\/usr\/bin\/ioclifecycle/" "${unpacked_dir}/etc/systemd/system/kostalcapi.service"
            run_sudo sed -i '/Slice/d' "${unpacked_dir}/etc/systemd/system/kostalcapi.service"
            run_sudo sed -i '/AmbientCapabilities/d' "${unpacked_dir}/etc/systemd/system/kostalcapi.service"
            run_sudo sed -i "s/Type=notify/Type=simple/" "${unpacked_dir}/etc/systemd/system/kostalcapi.service"
            run_sudo sed -i "s/base_capi/root/" "${unpacked_dir}/etc/systemd/system/kostalcapi.service"
            run_sudo cp -rf "${SDKTARGETSYSROOT}/usr/bin/ioclifecycle" "${unpacked_dir}/usr/bin/"

            # Disable unnecessary service and remove its devices dependencies that are reaching time out
            run_sudo sed -i "s/\[Unit\]/\[Unit\]\nConditionVirtualization=no/" "${unpacked_dir}/lib/systemd/system/weston@.service"
            run_sudo sed -i "/dev-dri-card0.device/d" "${unpacked_dir}/lib/systemd/system/weston@.service"
            run_sudo sed -i  's/sys-devices-platform-bus\\x4053100000-80000000.imx8_gpu0_ss.device\ dev-galcore.device//g' "${unpacked_dir}/lib/systemd/system/weston@.service"

            # Remove dependencies that are timing out
            run_sudo sed -i  's/sys-devices-platform-bus\\x4053100000-80000000.imx8_gpu0_ss.device\ dev-galcore.device//g' "${unpacked_dir}/etc/systemd/system/container-hmi.service"

            # Add systemd-udev-trigger.service to sysinit.target, so network devices can be triggered
            run_sudo ln -s "${unpacked_dir}/lib/systemd/system/systemd-udev-trigger.service" "${unpacked_dir}/lib/systemd/system/sysinit.target.wants/systemd-udev-trigger.service"

            echo "Creating ext4 image for rootfs"
            install_block_coldplug "${unpacked_dir}" "udev-early-trigger.service"
            run_sudo "${MKFS_BIN}" "${IMAGE_ROOTFS}" -d "${unpacked_dir}"
        else
            echo "Creating ext4 image for rootfs"
            run_sudo "${MKFS_BIN}" "${IMAGE_ROOTFS}" -d "${SDKTARGETSYSROOT}"
        fi
        echo "Done!"

        create_ext4_img "cont_a"    "hmi"       "${IMAGE_HMI}"      "${TARBALL_HMI}"
        create_ext4_img "varsys"    "varsys"    "${IMAGE_VARSYS}"   "${TARBALL_VARSYS}"
        create_ext4_img "userdata"  "userdata"  "${IMAGE_USERDATA}" "${TARBALL_USERDATA}"

        echo "Updating image container"
        update_image_container
    fi

    # PERFORMANCE
    if [ "${WITH_PERFORMANCE}" ] && [ ! -d "${IMAGE_CONTAINER}" ] ; then
        convert_raw_2_format
    fi

    # SNAPSHOTS
    if [ ! -z "${SNAPSHOT_IMG+x}" ] ; then
        [ ! -d "${SNAPSHOTS_DIR}" ] && run_sudo mkdir -p "${SNAPSHOTS_DIR}"
        if [ ! -f "${IMAGE_CONTAINER}" ] ; then
            convert_raw_2_format
        fi
    fi
}

# Call vCar with bmt-vdt configuration
launch_vcar() {
    echo "Checking vcan.."
    check_vcan
    if [ "${WITH_VCAR_SERVER}" = true ] ; then
        mkdir -p "${TMP_DIR}"
        cd "${TMP_DIR}"
        if [ -z "${DOCKER_BIN}" ] ; then
            print_error "docker could not be found"
        fi
        echo "Launching vCar Server docker image in ${PWD}.."
        "${DOCKER_BIN}" run --rm -d -it -e LOCAL_USER_ID="${USER_ID}" \
            -e VCAR_VIN=H011632 \
            -e VCAR_CONFIG=bmt-vdt \
            --network host \
            -v "${TMP_DIR}":/vcar/logs \
            --init artifactory.cc.bmwgroup.net/testandvalidation-docker/vcar/vcar:latest
        CONTAINER_ID=$(docker ps | grep 'vcar' | awk '{ print $1 }')
        SRV_CONTAINER_ID="${CONTAINER_ID[0]}"
        if [ -z "${SRV_CONTAINER_ID}" ] ; then
            print_error "vCar Server could not be launched."
        fi
        cd -
    else
        echo "Launching vCar.."
        cd "${VCAR_DIR}"/configurations/bmt-vdt
        "${VCAR_BIN}" "${VCAR_ARGS[@]}" > /dev/null &
        VCAR_PID=$!
        if [ -z "${VCAR_PID}" ]; then
            print_error "Failed to launch vCar"
        fi
        cd -
    fi

    if [ "${WITH_VCAR_CLIENT}" = true ] ; then
        [ "${WITH_VCAR_SERVER}" = false ] && print_error "Please pass --with-vcar-server in order to use the client"

        cd "${TMP_DIR}"
        if [ -z "${DOCKER_BIN}" ] ; then
            print_error "docker could not be found"
        fi
        echo "Launching vCar Client docker image in ${PWD}.."
        "${DOCKER_BIN}" run --rm -d -it -e LOCAL_USER_ID="${USER_ID}" \
            -e VCAR_VIN=H011632 \
            -e VCAR_CONFIG=bmt-vdt \
            --network host \
            -v "${TMP_DIR}":/vcar/logs \
            --init artifactory.cc.bmwgroup.net/testandvalidation-docker/vcar/vcar:latest \
            --client
        CONTAINER_ID=($(docker ps | grep 'vcar' | awk '{ print $1 }'))
        CLI_CONTAINER_ID=${CONTAINER_ID[0]}
        if [ -z "${CLI_CONTAINER_ID}" ] ; then
            print_error "vCar Client could not be launched."
        fi
        cd -
    fi
}

stop_vcar() {
    echo "Stopping vCar.."
    #docker kill $(docker ps -q)
    [ -z "${CLI_CONTAINER_ID+x}" ] || "${DOCKER_BIN}" stop "${CLI_CONTAINER_ID}"
    [ -z "${SRV_CONTAINER_ID+x}" ] || "${DOCKER_BIN}" stop "${SRV_CONTAINER_ID}"
    [ -z "${VCAR_PID+x}" ] || run_sudo kill "${VCAR_PID}" || print_error "Failed to exit vCar"
    [ -d "${TMP_DIR}" ] && rm -rf "${TMP_DIR}"
    disable_vcan
    echo "Done."
}

check_vcan() {
    if [[ $(run_sudo ip link) != *"vcan0"* ]] ; then
        run_sudo modprobe vcan
        [ "$?" -eq 1 ] && print_error "Failed to load vcan module"
        run_sudo ip link add dev vcan0 type vcan
        run_sudo ip link set up vcan0
    fi
}

disable_vcan() {
    if [[ $(run_sudo ip link) = *"vcan0"* ]] ; then
        run_sudo ip link set vcan0 down
        run_sudo ip link del vcan0
    fi
}

performance_setup() {
    source "${QEMU_CONFIG_EXEC}" --disk-path="${IMAGE_CONTAINER}" --boot-logs="${BOOT_LOGS_PATH}"

    size_args="${#QEMU_ARGS[@]}"
    for ((i=0;i<size_args;i++)) ; do
        [[ "${QEMU_ARGS[${i}]}" == "-m" ]] && QEMU_ARGS[((i+1))]="${VD_RAM}G"
        if [[ "${QEMU_ARGS[${i}]}" == "-drive" ]] ; then
            QEMU_ARGS[((i+1))]=${QEMU_ARGS[((i+1))]}",l2-cache-size=${L2_CACHE_SIZE},cache-clean-interval=${CCLEAN_INTERVAL}"
            QEMU_ARGS[((i+1))]=${QEMU_ARGS[((i+1))]/,cache=none/,cache=writethrough}
        fi
    done
}

network_setup() {
    if ${WITH_NETWORK}; then
        echo "Launching TAP device setup.."
        run_sudo "${QEMU_DIR}/scripts/deinit-qnet.sh" || print_error "Failed to clean network configuration"
        run_sudo "${QEMU_DIR}/scripts/init-qnet.sh"   || print_error "Failed initialize network configuration"
    fi
}

install_eng_token() {
    if ! ${WITH_NO_ENG_MODE} ; then
        # this runs in background in a separate process
        while :; do
            sleep 5
            ECU_MODE=$(2> /dev/null python3 ${LSMF_TOOLS_PATH}/read_ecu_mode.py --ip-addr 160.48.199.66 --diag-addr 0xA6 &)
            if [[ "${ECU_MODE}" =~ "Plant" ]] ; then
                while :; do
                    sleep 5
                    INST_TOKEN=$(2> /dev/null python3 ${LSMF_TOOLS_PATH}/sfa_write_token.py --ip-addr 160.48.199.66 --diag-addr 0xA6 --stk-file ${TOKENS_PATH}/token-809814-000001-000102030405060708090A0B0C0D0EEE.stk  2>&1 &)
                    if [[ "${INST_TOKEN}" =~ "Token installed" ]] ; then
                        exit 0
                    else
                        break
                    fi
                done
            elif [[ "${ECU_MODE}" =~ "Engineering" ]] ; then
                exit 0
            fi
        done &
        INSTALL_TOKEN_PID=$!
    fi
}

stop_install_eng_token(){
    if [ ! -z "${INSTALL_TOKEN_PID+x}" ] && [[ $(ps -p "${INSTALL_TOKEN_PID}") =~ "$(basename $0)" ]] ; then
        run_sudo kill "${INSTALL_TOKEN_PID}"
        [ "$?" != 0 ] && print_error "Failed to exit eng token installation"
    fi

    LSMF_TOOLS_PIDS=($(ps aux | grep "${LSMF_TOOLS_PATH}/.*\.py" | awk '{print $2}'))
    for PID in "${LSMF_TOOLS_PIDS[@]}"; do
        if [[ $(ps -p "${PID}") =~ "${LSMF_TOOLS_PATH}" ]] ; then
            run_sudo kill "${PID}"
        fi
    done
}

run_vdt() {
    # TODO: sched, check boot logs
    echo "${CMD_SUDO[@]} \"${QEMU_BIN}\" ${QEMU_ARGS[@]} -append \"${KERNEL_PARAMS}\""
    if [ ! "${WITH_PERFORMANCE}" ] ; then
        run_sudo "${QEMU_BIN}" "${QEMU_ARGS[@]}" "-append" "${KERNEL_PARAMS}"
    else
        run_sudo cset shield -e \
        "${QEMU_BIN}" -- ${QEMU_ARGS[@]} > ${BOOT_LOGS_PATH}
        # Test if isolation helps or not- TODO
        #"${QEMU_BIN}" ${QEMU_ARGS[@]} > ${BOOT_LOGS_PATH}
    fi
    echo "QEMU exited with $?"
}

clean_network() {
    if ${WITH_NETWORK}; then
        echo "Cleaning up network setup.."
        run_sudo "${QEMU_DIR}/scripts/deinit-qnet.sh" || print_error "Failed to clean network configuration"
        echo "Done."
    fi
}

print_vars() {
    echo "QEMU emulator     = ${QEMU_BIN}"
    echo "QEMU directory    = ${QEMU_DIR}"
    echo "MKFS tool         = ${MKFS_BIN}"
    echo "Kernel            = ${KERNEL}"
    echo "Rootfs Artefacts  = ${ROOTFS_DIR}"
    echo "Rootfs Tarball    = ${TARBALL_ROOTFS}"
    echo "HMI Tarball       = ${TARBALL_HMI}"
    echo "Varsys Tarball    = ${TARBALL_VARSYS}"
    echo "Userdata Tarball  = ${TARBALL_USERDATA}"
    echo "Rootfs Image      = ${IMAGE_ROOTFS}"
    echo "HMI Image         = ${IMAGE_HMI}"
    echo "Varsys Image      = ${IMAGE_VARSYS}"
    echo "Userdata Image    = ${IMAGE_USERDATA}"
    echo "Container Image   = ${IMAGE_CONTAINER}"
    echo "With Network      = ${WITH_NETWORK}"
    echo "With SDK Rootfs   = ${WITH_SDK_ROOTFS}"
    echo "With Yocto Rootfs = ${WITH_YOCTO_ROOTFS}"
    echo "With Stale Rootfs = ${WITH_STALE_ROOTFS}"
    echo "With X11          = ${WITH_X11}"
    echo "With vCar Server  = ${WITH_VCAR_SERVER}"
    echo "With vCar Client  = ${WITH_VCAR_CLIENT}"
    echo "With Tmp Snapshot = ${WITH_TMP_SNAPSHOT}"
    echo ""
}

# MAIN

# process script requirements
process_requirements

# process script arguments
process_args $@

# Set variables
set_vars

# process internal arguments
process_post_args

# echo important variables
print_vars

# create filesystem
create_filesystem
echo "Filesystem created!"

# Adapt QEMU to increase performance
! "${WITH_PERFORMANCE}" || performance_setup

# Check if tap device is set-up
network_setup

# Call vCar, either bare binary or dockerized srv/cli
launch_vcar

# Install eng mode token to VDT
install_eng_token

# Call qemu using the vdt kernel and the auto-generated filesystem image
run_vdt
