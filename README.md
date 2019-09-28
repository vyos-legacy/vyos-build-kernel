# vyos-ci

This repository should serve as a Demo on how to build the VyOS Linux Kernel
with out-of-tree modules as a Jenkins Pipeline job. The build is performed
utilizing a Docker conainer which is automatically retrieved from Dockerhub.

## Kernel

Kernel is build from the Vanilla Kernel source (git.kernel.org) with some patches
included (see patches folder). Those patched unfortunately did not make it into
mainline but are required for VyOS.

### Config

VyOS Kernel configuration ([x86_64_vyos_defconfig](x86_64_vyos_defconfig)) will
be copied on demand to the Kernel source tree during build time and will generate
the appropriate packages.

### Modules

VyOS utilizes several Out-of-Tree modules (e.g. WireGuard, Accel-PPP and Intel
network interface card drivers). Module source code is retrieved from the
upstream repository and - when needed - patched so it can be build using this
pipeline.

In the past VyOS maintainers had a fork of the Linux Kernel, WireGuard and
Accel-PPP. This is fine but increases maintenance effort. By utilizing vanilla
repositories upgrading to new versions is very easy - only the branch/commit/tag
used when cloning the repository via [Jenkinsfile](Jenkinsfile) needs to be
adjusted.

