#!/bin/sh
CWD=$(pwd)
KERNEL_VAR_FILE=${CWD}/kernel-vars

if [ ! -f ${KERNEL_VAR_FILE} ]; then
    echo "Kernel variable file '${KERNEL_VAR_FILE}' does not exist, run ./build_kernel.sh first"
    exit 1
fi

. ${KERNEL_VAR_FILE}

declare -a intel=(
    "https://01.org/sites/default/files/downloads/qat1.7.l.4.9.0-00008.tar_0.gz"
)

for url in "${intel[@]}"
do
    cd ${CWD}

    # URL_SIMPLE does not contain the /download path
    URL_SIMPLE="${url%/*}"
    DRIVER_FILE=$(basename ${url} | sed -e s/tar_0/tar/)
    DRIVER_DIR="${DRIVER_FILE%.tar.gz}"
    DRIVER_NAME="qat"
    DRIVER_VERSION=$(echo ${DRIVER_DIR} | awk -F${DRIVER_NAME} '{print $2}')
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
    mkdir -p ${DRIVER_DIR}
    tar -C ${DRIVER_DIR} -xf ${DRIVER_FILE}

    cd ${DRIVER_DIR}
    if [ -z $KERNEL_DIR ]; then
        echo "KERNEL_DIR not defined"
        exit 1
    fi

    echo "I: Compile Kernel module for Intel ${DRIVER_NAME} driver"
    mkdir -p ${DEBIAN_DIR}/lib/firmware ${DEBIAN_DIR}/usr/bin ${DEBIAN_DIR}/usr/lib/x86_64-linux-gnu ${DEBIAN_DIR}/etc/init.d
    KERNEL_SOURCE_ROOT=${KERNEL_DIR} ./configure --enable-kapi
    make -j $(getconf _NPROCESSORS_ONLN) all
    make INSTALL_MOD_PATH=${DEBIAN_DIR} INSTALL_FW_PATH=${DEBIAN_DIR} \
        qat-driver-install

    cp build/*.bin ${DEBIAN_DIR}/lib/firmware
    cp build/*.so ${DEBIAN_DIR}/usr/lib/x86_64-linux-gnu
    cp build/qat_service ${DEBIAN_DIR}/etc/init.d
    cp build/adf_ctl ${DEBIAN_DIR}/usr/bin
    cp build/usdm_drv.ko ${DEBIAN_DIR}/lib/modules/${KERNEL_VERSION}${KERNEL_SUFFIX}/updates/drivers
    chmod 644 ${DEBIAN_DIR}/lib/firmware/*
    chmod 755 ${DEBIAN_DIR}/etc/init.d/*

    mkdir -p $(dirname "${DEBIAN_CONTROL}")
    cat << EOF >${DEBIAN_CONTROL}
Package: vyos-intel-${DRIVER_NAME}
Version: ${DRIVER_VERSION}${DRIVER_VERSION_EXTRA}
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
#    cd ${CWD}
#    if [ -e ${DRIVER_FILE} ]; then
#        rm -f ${DRIVER_FILE}
#    fi
#    if [ -d ${DRIVER_DIR} ]; then
#        rm -rf ${DRIVER_DIR}
#    fi
#    if [ -d ${DEBIAN_DIR} ]; then
#        rm -rf ${DEBIAN_DIR}
#    fi
done
