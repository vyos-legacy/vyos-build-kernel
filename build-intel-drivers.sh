#!/bin/sh
CWD=$(pwd)
KERNEL_VAR_FILE=${CWD}/kernel-vars

if [ ! -f ${KERNEL_VAR_FILE} ]; then
    echo "Kernel variable file '${KERNEL_VAR_FILE}' does not exist, run ./build_kernel.sh first"
    exit 1
fi

. ${KERNEL_VAR_FILE}

declare -a intel=(
    "https://astuteinternet.dl.sourceforge.net/project/e1000/ixgbe%20stable/5.6.5/ixgbe-5.6.5.tar.gz"
    "https://astuteinternet.dl.sourceforge.net/project/e1000/igb%20stable/5.3.5.42/igb-5.3.5.42.tar.gz"
    "https://astuteinternet.dl.sourceforge.net/project/e1000/i40e%20stable/2.11.21/i40e-2.11.21.tar.gz"
    "https://astuteinternet.dl.sourceforge.net/project/e1000/ixgbevf%20stable/4.6.3/ixgbevf-4.6.3.tar.gz"
    "https://astuteinternet.dl.sourceforge.net/project/e1000/i40evf%20stable/3.6.15/i40evf-3.6.15.tar.gz"
    "https://astuteinternet.dl.sourceforge.net/project/e1000/iavf%20stable/3.9.3/iavf-3.9.3.tar.gz"
)

for url in "${intel[@]}"
do
    cd ${CWD}

    DRIVER_FILE="$(basename ${url})"
    DRIVER_DIR="${DRIVER_FILE%.tar.gz}"
    DRIVER_NAME="${DRIVER_DIR%-*}"
    DRIVER_VERSION="${DRIVER_DIR##*-}"
    DRIVER_VERSION_EXTRA="-0"

    # Build up Debian related variables required for packaging
    DEBIAN_ARCH=$(dpkg --print-architecture)
    DEBIAN_DIR="${CWD}/vyos-intel-${DRIVER_NAME}_${DRIVER_VERSION}${DRIVER_VERSION_EXTRA}_${DEBIAN_ARCH}"
    DEBIAN_CONTROL="${DEBIAN_DIR}/DEBIAN/control"

    # Fetch Intel driver source from SourceForge
    if [ -e ${DRIVER_FILE} ]; then
        rm -f ${DRIVER_FILE}
    fi
    curl -L -o ${DRIVER_FILE} ${url}
    if [ "$?" -ne "0" ]; then
        exit 1
    fi

    # Unpack archive
    if [ -d ${DRIVER_DIR} ]; then
        rm -rf ${DRIVER_DIR}
    fi
    tar xf ${DRIVER_FILE}


    cd ${DRIVER_DIR}/src
    if [ -z $KERNEL_DIR ]; then
        echo "KERNEL_DIR not defined"
        exit 1
    fi
    echo "I: Compile Kernel module for Intel ${DRIVER_NAME} driver"
    KSRC=${KERNEL_DIR} \
        INSTALL_MOD_PATH=${DEBIAN_DIR} \
        make -j $(getconf _NPROCESSORS_ONLN) install

    mkdir -p $(dirname "${DEBIAN_CONTROL}")
    cat << EOF >${DEBIAN_CONTROL}
Package: vyos-intel-${DRIVER_NAME}
Version: ${DRIVER_VERSION}-${DRIVER_VERSION_EXTRA}
Section: kernel
Priority: extra
Architecture: ${DEBIAN_ARCH}
Maintainer: VyOS Package Maintainers <maintainers@vyos.net>
Description: Vendor based driver for Intel ${DRIVER_NAME}
Depends: linux-image-${KERNEL_VERSION}${KERNEL_SUFFIX}
EOF

    # delete non required files which are also present in the kernel package
    # und thus lead to duplicated files
    find ${DEBIAN_DIR} -name "modules.*" | xargs rm -f

    # build Debian package
    echo "I: Building Debian package vyos-intel-${DRIVER_NAME}"
    dpkg-deb --build ${DEBIAN_DIR}


    echo "I: Cleanup ${DRIVER_NAME} source"
    cd ${CWD}
    if [ -e ${DRIVER_FILE} ]; then
        rm -f ${DRIVER_FILE}
    fi
    if [ -d ${DRIVER_DIR} ]; then
        rm -rf ${DRIVER_DIR}
    fi
    if [ -d ${DEBIAN_DIR} ]; then
        rm -rf ${DEBIAN_DIR}
    fi
done
