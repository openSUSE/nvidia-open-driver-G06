# get rid of broken weak-updates symlinks created in some %post apparently;
# either by kmp itself or by kernel package update
for i in $(find /lib/modules/*/weak-updates -type l 2> /dev/null); do
  test -e $(readlink -f $i) || rm $i
done
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
kver=$(make -j$(nproc) -sC /usr/src/linux-obj/$arch/$flavor kernelrelease)
RES=0

export SYSSRC=/usr/src/linux
export SYSOUT=/usr/src/linux-obj/$arch/$flavor

pushd /usr/src/kernel-modules/nvidia-%{-v*}-$flavor
make -j$(nproc) modules || RES=1

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

exit $RES
