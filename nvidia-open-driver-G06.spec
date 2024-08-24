#
# spec file for package nvidia-open-driver-G06
#
# Copyright (c) 2022 SUSE LLC
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via https://bugs.opensuse.org/
#

%define kernel_flavors default
%ifnarch aarch64
%if !0%{?is_opensuse}
%define kernel_flavors azure default
%endif
%else
%define kernel_flavors 64kb default
%endif

%if %{undefined kernel_module_directory}
%if 0%{?usrmerged}
%define kernel_module_directory /usr/lib/modules
%else
%define kernel_module_directory /lib/modules
%endif
%endif

%define compress_modules xz
Name:           nvidia-open-driver-G06
Version:        550.107.02
Release:        0
Summary:        NVIDIA open kernel module driver for Turing GPUs and later
License:        GPL-2.0 and MIT
Group:          System/Kernel
URL:            https://github.com/NVIDIA/open-gpu-kernel-modules/
Source0:        open-gpu-kernel-modules-%{version}.tar.gz
Source2:        pci_ids-%{version}
Source4:        kmp-post.sh
Source5:        kmp-postun.sh
Source6:        modprobe.nvidia.install
Source8:        json-to-pci-id-list.py
Source9:        kmp-preun.sh
Source11:       nvidia-open-driver-G06.rpmlintrc
Source13:       supplements.inc
Source14:       create-supplements.sh
Source15:       supplements-azure.inc
Source20:       supplements-64kb.inc
Patch0:         persistent-nvidia-id-string.patch
BuildRequires:  %{kernel_module_package_buildreqs}
BuildRequires:  gcc-c++
BuildRequires:  kernel-source
BuildRequires:  kernel-syms
BuildRequires:  kernel-devel
BuildRequires:  kernel-default-devel
BuildRequires:  kmod
BuildRequires:  zstd
%ifnarch aarch64
%if !0%{?is_opensuse} 
BuildRequires:  kernel-azure-devel
BuildRequires:  kernel-syms-azure
%endif
%endif
ExclusiveArch:  x86_64 aarch64

%description
This package provides the open-source NVIDIA kernel module driver
for Turing GPUs and later.

%package kmp-default
Summary:        NVIDIA open kernel module driver for Turing GPUs and later (default kernel flavor)
BuildRequires: kernel-syms
BuildRequires: kmod
PreReq: kernel-default
PreReq: kernel-default-devel make gcc gcc-c++
Requires: kernel-firmware-nvidia-gspx-G06 = %{version}
Requires: openssl
Requires: mokutil
Conflicts: nvidia-gfxG06-kmp nvidia-driver-G06-kmp nvidia-open-driver-G06-signed-kmp nvidia-gfxG05-kmp
Provides: %name
Supplements: (kernel-default and %name)
%include %{S:13}

%description kmp-default
This package provides the open-source NVIDIA kernel module driver
for Turing GPUs and later. This is for default kernel flavor.

%ifnarch aarch64

%if !0%{?is_opensuse}

%package kmp-azure
Summary:        NVIDIA open kernel module driver for Turing GPUs and later (azure kernel flavor)
BuildRequires: kernel-syms
BuildRequires: kmod
PreReq: kernel-azure
PreReq: kernel-azure-devel make gcc gcc-c++
Requires: kernel-firmware-nvidia-gspx-G06 = %{version}
Requires: openssl
Requires: mokutil
Conflicts: nvidia-gfxG06-kmp nvidia-driver-G06-kmp nvidia-open-driver-G06-signed-kmp nvidia-gfxG05-kmp
Provides: %name
Supplements: (kernel-azure and %name)
%include %{S:15}

%description kmp-azure
This package provides the open-source NVIDIA kernel module driver
for Turing GPUs and later. This is for azure kernel flavor.

%endif

%else

%package kmp-64kb
Summary:        NVIDIA open kernel module driver for Turing GPUs and later (64kb kernel flavor)
BuildRequires: kernel-syms
BuildRequires: kmod
PreReq: kernel-64kb
PreReq: kernel-64kb-devel make gcc gcc-c++
Requires: kernel-firmware-nvidia-gspx-G06 = %{version}
Requires: openssl
Requires: mokutil
Conflicts: nvidia-gfxG06-kmp nvidia-driver-G06-kmp nvidia-open-driver-G06-signed-kmp nvidia-gfxG05-kmp
Provides: %name
Supplements: (kernel-64kb and %name)
%include %{S:20}

%description kmp-64kb
This package provides the open-source NVIDIA kernel module driver
for Turing GPUs and later. This is for 64kb kernel flavor.

%endif

%prep
%setup -q -n open-gpu-kernel-modules-%{version}
%patch -P 0 -p1
set -- *
mkdir source
mv "$@" source/
mkdir obj

%build
%ifarch aarch64
# -Wall is upstream default
export CFLAGS="-Wall -mno-outline-atomics"
%endif
# kernel was compiled using a different compiler
export CC=gcc
# no longer needed and never worked anyway (it was only a stub) [boo#1211892]
export NV_EXCLUDE_KERNEL_MODULES=nvidia-peermem
for flavor in %kernel_flavors; do
        rm -rf obj/$flavor
        cp -r source obj/$flavor
	pushd obj/$flavor
	if [ -d /usr/src/linux-$flavor ]; then
	  export SYSSRC=/usr/src/linux-$flavor
	else
	  export SYSSRC=/usr/src/linux
	fi
	export SYSOUT=/usr/src/linux-obj/%_target_cpu/$flavor
        make %{?_smp_mflags} %{?linux_make_arch} modules
        popd
done

%install
### do not sign the ghost .ko file, it is generated on target system anyway
export BRP_PESIGN_FILES=""
export INSTALL_MOD_PATH=%{buildroot}
export INSTALL_MOD_DIR=updates
for flavor in %kernel_flavors; do
	pushd obj/$flavor
	if [ -d /usr/src/linux-$flavor ]; then
	  export SYSSRC=/usr/src/linux-$flavor
	else
	  export SYSSRC=/usr/src/linux
	fi
	export SYSOUT=/usr/src/linux-obj/%_target_cpu/$flavor
        make %{?linux_make_arch} modules_install
	popd
%ifarch x86_64
	arch=x86_64
%endif
%ifarch aarch64
	arch=aarch64
%endif
        if [ "$flavor" == "azure" ]; then
          dir=$(pushd /usr/src &> /dev/null; ls -d linux-*-azure-obj|sort -n|tail -n 1; popd &> /dev/null)
          kver_build=$(make -j$(nproc) -sC /usr/src/${dir}/${arch}/$flavor kernelrelease)
        else
          kver_build=$(make -j$(nproc) -sC /usr/src/linux-obj/${arch}/$flavor kernelrelease)
        fi
        mkdir -p %{buildroot}/usr/src/kernel-modules/nvidia-%{version}-${flavor}
        cp -r source/* %{buildroot}/usr/src/kernel-modules/nvidia-%{version}-${flavor}
        # save kernel version for later
        echo $kver_build > %{buildroot}/usr/src/kernel-modules/nvidia-%{version}-${flavor}/kernel_version
        # zero fake kernel modules to prevent generation of ksyms in package
        for i in %{buildroot}/%{kernel_module_directory}/${kver_build}/updates/*.ko; do
          rm -f $i; touch $i; chmod 644 $i
        done
done

MODPROBE_DIR=%{buildroot}%{_sysconfdir}/modprobe.d

mkdir -p $MODPROBE_DIR
for flavor in %kernel_flavors; do
    cat > $MODPROBE_DIR/50-nvidia-$flavor.conf << EOF
blacklist nouveau
options nvidia NVreg_DeviceFileUID=0 NVreg_DeviceFileGID=33 NVreg_DeviceFileMode=0660 NVreg_PreserveVideoMemoryAllocations=1
options nvidia-drm modeset=1 fbdev=1
EOF
    echo -n "install nvidia " >> $MODPROBE_DIR/50-nvidia-$flavor.conf
    tail -n +3 %_sourcedir/modprobe.nvidia.install | awk '{ printf "%s ", $0 }' >> $MODPROBE_DIR/50-nvidia-$flavor.conf
# otherwise nvidia-uvm is missing in initrd and won't get loaded when nvidia
# module is loaded in initrd; so better let's load all the nvidia modules
# later ...
  mkdir -p %{buildroot}/etc/dracut.conf.d
  cat  > %{buildroot}/etc/dracut.conf.d/60-nvidia-$flavor.conf << EOF
omit_drivers+=" nvidia nvidia-drm nvidia-modeset nvidia-uvm "
EOF
done

%files kmp-default
%ghost %dir %{kernel_module_directory}/*-default/updates
%ghost %{kernel_module_directory}/*-default/updates/nvidia*.ko
%ghost %attr(755,root,root) %dir /var/lib/nvidia-pubkeys
%ghost %attr(644,root,root) /var/lib/nvidia-pubkeys/MOK-%{name}-%{version}.der
%dir /usr/src/kernel-modules
/usr/src/kernel-modules/nvidia-%{version}-default/
%dir %{_sysconfdir}/modprobe.d
%config %{_sysconfdir}/modprobe.d/50-nvidia-default.conf
%dir /etc/dracut.conf.d
/etc/dracut.conf.d/60-nvidia-default.conf

%post kmp-default
RES=0
tw="false"
cat /etc/os-release | grep ^NAME | grep -q Tumbleweed && tw=true
if [ "$tw" == "false" ]; then
#kmp-post.sh
flavor=default
%include %{S:4}
fi
exit $RES

%triggerin kmp-default -- kernel-default-devel
RES=0
tw="false"
cat /etc/os-release | grep ^NAME | grep -q Tumbleweed && tw=true
if [ "$tw" == "true" ]; then
#kmp-post.sh
flavor=default
%include %{S:4}
fi
exit $RES

%preun kmp-default
#kmp-preun.sh
flavor=default
%include %{S:9}

%postun kmp-default
#kmp-postun.sh
flavor=default
%include %{S:5}

%ifnarch aarch64

%if !0%{?is_opensuse}

%files kmp-azure
%exclude %{kernel_module_directory}/*-azure/updates/
%ghost %attr(755,root,root) %dir /var/lib/nvidia-pubkeys
%ghost %attr(644,root,root) /var/lib/nvidia-pubkeys/MOK-%{name}-%{version}.der
%dir /usr/src/kernel-modules
/usr/src/kernel-modules/nvidia-%{version}-azure/
%dir %{_sysconfdir}/modprobe.d
%config %{_sysconfdir}/modprobe.d/50-nvidia-azure.conf
%dir /etc/dracut.conf.d
/etc/dracut.conf.d/60-nvidia-azure.conf

%triggerin kmp-azure -- kernel-azure-devel
#kmp-post.sh
flavor=azure
%include %{S:4}
exit $RES

%preun kmp-azure
#kmp-preun.sh
flavor=azure
%include %{S:9}

%postun kmp-azure
#kmp-postun.sh
flavor=azure
%include %{S:5}

%endif

%else

%files kmp-64kb
%ghost %dir %{kernel_module_directory}/*-64kb/updates
%ghost %{kernel_module_directory}/*-64kb/updates/nvidia*.ko
%ghost %attr(755,root,root) %dir /var/lib/nvidia-pubkeys
%ghost %attr(644,root,root) /var/lib/nvidia-pubkeys/MOK-%{name}-%{version}.der
%dir /usr/src/kernel-modules
/usr/src/kernel-modules/nvidia-%{version}-64kb/
%dir %{_sysconfdir}/modprobe.d
%config %{_sysconfdir}/modprobe.d/50-nvidia-64kb.conf
%dir /etc/dracut.conf.d
/etc/dracut.conf.d/60-nvidia-64kb.conf

%post kmp-64kb
RES=0
tw="false"
cat /etc/os-release | grep ^NAME | grep -q Tumbleweed && tw=true
if [ "$tw" == "false" ]; then
#kmp-post.sh
flavor=64kb
%include %{S:4}
fi
exit $RES

%triggerin kmp-64kb -- kernel-64kb-devel
RES=0
tw="false"
cat /etc/os-release | grep ^NAME | grep -q Tumbleweed && tw=true
if [ "$tw" == "true" ]; then
#kmp-post.sh
flavor=64kb
%include %{S:4}
fi
exit $RES

%preun kmp-64kb
#kmp-preun.sh
%include %{S:9}

%postun kmp-64kb
#kmp-postun.sh
flavor=64kb
%include %{S:5}

%endif

