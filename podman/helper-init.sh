#!/bin/bash

set -x
set -e

# Ensure KVM acceleration is available — required to run the QEMU VM.
# On bare-metal Linux this is present by default. Inside a hypervisor
# (VMware, VirtualBox, QEMU/KVM, etc.) nested virtualization must be
# enabled in the hypervisor settings first.
if ! kvm-ok > /dev/null 2>&1; then
	echo "Error: KVM acceleration is not available." >&2
	kvm-ok >&2
	echo "If running inside a hypervisor, enable nested virtualization" >&2
	echo "in your hypervisor settings and retry." >&2
	exit 1
fi

pushd ../

# Init all submodules
for module in $(git submodule status | awk '{print $2}'); do
	# If the submodule directory exists but has no .git (e.g. from a failed
	# previous clone), remove it so git can clone cleanly.
	if [ -d "${module}" ] && [ ! -e "${module}/.git" ]; then
		rm -rf "${module}"
	fi
	if [ "${module}" == "kernel/linux" ]; then
		# A shallow clone with depth 1 fetches only the latest code
		#snapshot of the Linux kernel repository, reducing download
		#size and time, which is helpful for limited resources.
		#However, it omits the full commit history, limiting access to
		#historical data and some Git functionalities that rely on
		#complete history.
		git submodule update --init --recursive --depth 1 "${module}"
	else
		git submodule update --init --recursive "${module}"
	fi
done

# Setup the VM
#
# This builds a minimal rootfs to be used by the VM
#
if [ ! -f "tests/.vm_initialized" ]; then
	# Select the fastest Debian mirror automatically, unless DEBIAN_MIRROR is
	# already set by the caller. A list of mirrors is available at:
	# https://www.debian.org/mirror/list
	if [ -z "${DEBIAN_MIRROR:-}" ]; then
		MIRROR_CANDIDATES=(
			"https://deb.debian.org/debian"
			"http://giano.com.dist.unige.it/debian"
			"http://ftp.fr.debian.org/debian"
			"http://ftp.de.debian.org/debian"
			"http://mirror.units.it/debian"
			"http://debian.mirror.garr.it/debian"
		)

		# Use Packages.gz as test file: always present on any mirror and large
		# enough to give a reliable speed measurement.
		TEST_PATH="/dists/bookworm/main/binary-amd64/Packages.gz"

		BEST_MIRROR=""
		BEST_SPEED=0
		BEST_SPEED_HUMAN=""

		echo "Selecting fastest Debian mirror..."
		for mirror in "${MIRROR_CANDIDATES[@]}"; do
			speed=$(curl -w "%{speed_download}" -o /dev/null -s --max-time 5 "${mirror}${TEST_PATH}") || speed=0
			speed=${speed%.*}
			if [ "${speed}" -ge 1000000 ]; then
				speed_human=$(awk "BEGIN { printf \"%.1f MB/s\", ${speed}/1000000 }")
			else
				speed_human=$(awk "BEGIN { printf \"%.1f KB/s\", ${speed}/1000 }")
			fi
			echo "  ${mirror} -> ${speed_human}"
			if [ "${speed}" -gt "${BEST_SPEED}" ]; then
				BEST_SPEED=${speed}
				BEST_MIRROR=${mirror}
				BEST_SPEED_HUMAN=${speed_human}
			fi
		done

		export DEBIAN_MIRROR="${BEST_MIRROR}"
		echo "Selected mirror: ${DEBIAN_MIRROR} (${BEST_SPEED_HUMAN})"
	fi

	pushd tests/vm
	./create-image.sh
	popd
	touch tests/.vm_initialized
else
	echo "VM rootfs already initialized, skipping create-image.sh"
fi

# Kernel setup
#
# 1) Copy the pre-shipped linux config file into the `kernel/linux` directory
#    containing the kernel source code;
# 2) Build the kernel;
# 3) Build the out-of-tree (OOT) kernel module, and then copy the resulting
#    module into the VM subproject's shared folder. Specifically, place the
#    module inside a directory shared with the VM instance at `/mnt/shared`.
#    This allows the module to be loaded directly from the running guest OS by
#    accessing this shared folder;
# 4) For installation, create a symbolic link to the compiled `bzImage` (built
#    for the current architecture, only x86_64 has been tested so far) within
#    the VM subproject. This ensures the VM will boot using this specific
#    kernel version. Note that the kernel configuration provided results in a
#    statically built kernel, so no external modules are required at runtime.
pushd kernel
make all
popd

# pushd bpftool/src && \ make clean && make -j$(nproc); popd
#
# pushd src/c && \ make clean && make -j$(nproc); popd
