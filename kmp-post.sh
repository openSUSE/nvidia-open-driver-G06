# get rid of broken weak-updates symlinks created in some %post apparently;
# either by kmp itself or by kernel package update
for i in $(find /lib/modules/*/weak-updates -type l 2> /dev/null); do
  test -e $i || rm $i
done
dirprefix=linux
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
#export CONCURRENCY_LEVEL=nproc && \ 
#export JOBS=${CONCURRENCY_LEVEL} && \
#export __JOBS=${JOBS} && \ 
#export MAKEFLAGS="-j ${JOBS}"
if [ "$flavor" == "azure" ]; then
dir=$(pushd /usr/src &> /dev/null; ls -d linux-*-azure-obj|sort -n|tail -n 1; popd &> /dev/null)
kver=$(make -j$(nproc) -sC /usr/src/${dir}/$arch/$flavor kernelrelease)
else
kver=$(make -j$(nproc) -sC /usr/src/${dirprefix}-obj/$arch/$flavor kernelrelease)
fi
RES=0

# mold is not supported (boo#1223344)
export LD=ld.bfd

if [ "$flavor" == "azure" ]; then
    export SYSSRC=/usr/src/${dirprefix}-azure
    dir=$(pushd /usr/src &> /dev/null; ls -d linux-*-azure-obj|sort -n|tail -n 1; popd &> /dev/null)
    export SYSOUT=/usr/src/${dir}/$arch/$flavor
else
    export SYSSRC=/usr/src/${dirprefix}
    export SYSOUT=/usr/src/${dirprefix}-obj/$arch/$flavor
fi

pushd /usr/src/kernel-modules/nvidia-%{version}-$flavor
make -j$(nproc) modules || RES=1

# remove still existing old kernel modules (boo#1174204)
rm -f /lib/modules/$kver/updates/nvidia*.ko

export INSTALL_MOD_DIR=updates
make modules_install

tw="false"
cat /etc/os-release | grep ^NAME | grep -q Tumbleweed && tw=true

# move kernel modules where they belong and can be found by weak-modules2 script
kver_build=$(cat kernel_version)
if [ "$kver" != "$kver_build" -a "$flavor" != "azure" -a "$tw" != "true" ]; then
  mkdir -p %{kernel_module_directory}/$kver_build/updates
  mv %{kernel_module_directory}/$kver/updates/nvidia*.ko \
     %{kernel_module_directory}/$kver_build/updates
fi

# create initrd
/usr/lib/module-init-tools/weak-modules2 --add-kernel $kver

popd

depmod $kver

# cleanup (boo#1200310)
pushd /usr/src/kernel-modules/nvidia-%{version}-$flavor || true
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
    pubkey=$pubkeydir/MOK-%{name}-%{version}-$flavor.der

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
                -subj "/CN=Local build for %{name} %{version} on $(date +"%Y-%m-%d")/" \
                -addext "extendedKeyUsage=codeSigning" \
                -nodes

    # Install the public key to MOK
    mokutil --import $pubkey --root-pw

    # Sign the Nvidia modules (weak-updates appears to be broken)
    if [ "$kver" != "$kver_build" -a "$flavor" != "azure" -a "$tw" != "true" ]; then
      for i in /lib/modules/$kver_build/updates/nvidia*.ko; do
        /lib/modules/$kver/build/scripts/sign-file sha256 $privkey $pubkey $i
      done
    else
      for i in /lib/modules/$kver/updates/nvidia*.ko; do
        /lib/modules/$kver/build/scripts/sign-file sha256 $privkey $pubkey $i
      done
    fi

    # cleanup: private key no longer needed
    rm -f $privkey
  fi
fi

# groups are now dynamic
if [ -f %{_sysconfdir}/modprobe.d/50-nvidia.conf ]; then
  VIDEOGID=`getent group video | cut -d: -f3`
  sed -i "s/33/$VIDEOGID/" %{_sysconfdir}/modprobe.d/50-nvidia.conf
fi

#needed to move this to specfile after running posttrans
#exit $RES
