%ifarch %ix86
arch=i386
%endif
%ifarch x86_64
arch=x86_64
%endif
%ifarch aarch64
arch=aarch64
# -Wall is upstream default
export CFLAGS="-Wall -mno-outline-atomics"
%endif
flavor=%1
#export CONCURRENCY_LEVEL=nproc && \ 
#export JOBS=${CONCURRENCY_LEVEL} && \
#export __JOBS=${JOBS} && \ 
#export MAKEFLAGS="-j ${JOBS}"
if [ "$flavor" == "azure" ]; then
kver=$(make -j$(nproc) -sC /usr/src/linux-%{2}-azure-obj/$arch/$flavor kernelrelease)
else
kver=$(make -j$(nproc) -sC /usr/src/linux-%{2}-obj/$arch/$flavor kernelrelease)
fi
RES=0

if [ "$flavor" == "azure" ]; then
    export SYSSRC=/usr/src/linux-%{2}-azure
    export SYSOUT=/usr/src/linux-%{2}-azure-obj/$arch/$flavor
else
    export SYSSRC=/usr/src/linux-%{2}
    export SYSOUT=/usr/src/linux-%{2}-obj/$arch/$flavor
fi

pushd /usr/src/kernel-modules/nvidia-%{-v*}-$flavor
make -j$(nproc) modules || RES=1

# remove still existing old kernel modules (boo#1174204)
rm -f /lib/modules/$kver/updates/nvidia*.ko

export INSTALL_MOD_DIR=updates
make modules_install
popd

depmod $kver

# cleanup (boo#1200310)
pushd /usr/src/kernel-modules/nvidia-%{-v*}-$flavor || true
cp -a Makefile{,.tmp} || true
make clean || true
# NVIDIA's "make clean" not being perfect (boo#1201937)
rm -f conftest*.c nv_compiler.h
mv Makefile{.tmp,} || true
popd || true

# Sign modules on secureboot systems
if [ -x /usr/bin/mokutil ]; then
  mokutil --sb-state | grep -q "SecureBoot enabled"
  if [ $? -eq 0 ]; then
    privkey=$(mktemp /tmp/MOK.priv.XXXXXX)
    pubkeydir=/var/lib/nvidia-pubkeys
    pubkey=$pubkeydir/MOK-%{name}-%{-v*}-%{-r*}-$flavor.der

    # make sure creation of pubkey doesn't fail later
    test -d pubkeydir || mkdir -p $pubkeydir
    if [ $1 -eq 2 ] && [ -e $pubkey ]; then
        # Special case: reinstall of the same pkg version
        # ($pubkey file name includes version and release)
        # Run mokutil --delete here, because we can't be sure preun
        # will be run (bsc#1176146)
        mv -f $pubkey $pubkey.delete
        mokutil --delete $pubkey.delete --root-pw
        # We can't remove $pubkey.delete, the preun script
        # uses it as indicator not to delete $pubkey
    else
        rm -f $pubkey $pubkey.delete
    fi

    # Create a key pair (private key, public key)
    openssl req -new -x509 -newkey rsa:2048 \
                -keyout $privkey \
                -outform DER -out $pubkey -days 1000 \
                -subj "/CN=Local build for %{name} %{-v*} on $(date +"%Y-%m-%d")/" \
                -addext "extendedKeyUsage=codeSigning" \
                -nodes

    # Install the public key to MOK
    mokutil --import $pubkey --root-pw

    # Sign the Nvidia modules (weak-updates appears to be broken)
    for i in /lib/modules/$kver/updates/nvidia*.ko; do
      /lib/modules/$kver/build/scripts/sign-file sha256 $privkey $pubkey $i
    done

    # cleanup: private key no longer needed
    rm -f $privkey
  fi
fi

# Create symlinks for udev so these devices will get user ACLs by logind later (bnc#1000625)
mkdir -p /run/udev/static_node-tags/uaccess
mkdir -p /usr/lib/tmpfiles.d
ln -snf /dev/nvidiactl /run/udev/static_node-tags/uaccess/nvidiactl 
ln -snf /dev/nvidia-uvm /run/udev/static_node-tags/uaccess/nvidia-uvm
ln -snf /dev/nvidia-uvm-tools /run/udev/static_node-tags/uaccess/nvidia-uvm-tools
ln -snf /dev/nvidia-modeset /run/udev/static_node-tags/uaccess/nvidia-modeset
cat >  /usr/lib/tmpfiles.d/nvidia-logind-acl-trick-G06.conf << EOF
L /run/udev/static_node-tags/uaccess/nvidiactl - - - - /dev/nvidiactl
L /run/udev/static_node-tags/uaccess/nvidia-uvm - - - - /dev/nvidia-uvm
L /run/udev/static_node-tags/uaccess/nvidia-uvm-tools - - - - /dev/nvidia-uvm-tools
L /run/udev/static_node-tags/uaccess/nvidia-modeset - - - - /dev/nvidia-modeset
EOF
devid=-1
for dev in $(ls -d /sys/bus/pci/devices/*); do 
  vendorid=$(cat $dev/vendor)
  if [ "$vendorid" == "0x10de" ]; then 
    class=$(cat $dev/class)
    classid=${class%%00}
    if [ "$classid" == "0x0300" -o "$classid" == "0x0302" ]; then 
      devid=$((devid+1))
      ln -snf /dev/nvidia${devid} /run/udev/static_node-tags/uaccess/nvidia${devid}
      echo "L /run/udev/static_node-tags/uaccess/nvidia${devid} - - - - /dev/nvidia${devid}" >> /usr/lib/tmpfiles.d/nvidia-logind-acl-trick-G06.conf
    fi
  fi
done

# groups are now dynamic
%if 0%{?suse_version} >= 1550
if [ -f /usr/lib/modprobe.d/50-nvidia-$flavor.conf ]; then
%else
if [ -f /etc/modprobe.d/50-nvidia-$flavor.conf ]; then
%endif
  VIDEOGID=`getent group video | cut -d: -f3`
%if 0%{?suse_version} >= 1550
  sed -i "s/33/$VIDEOGID/" /usr/lib/modprobe.d/50-nvidia-$flavor.conf
%else
  sed -i "s/33/$VIDEOGID/" /etc/modprobe.d/50-nvidia-$flavor.conf
%endif
fi

# Workaround needed on TW for simpledrm (boo#1201392)
%if 0%{?suse_version} >= 1550
pbl --add-option nosimplefb=1 --config
%endif

#needed to move this to specfile after running weak-modules2 (boo#1145316)
#exit $RES
