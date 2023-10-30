if [ "$1" = 0 ] ; then
    # get rid of *all* nvidia kernel modules when uninstalling package (boo#1180010)
    for dir in $(find /lib/modules  -mindepth 1 -maxdepth 1 -type d); do
            test -d $dir/updates && rm -f  $dir/updates/nvidia*.ko
    done
    # cleanup of bnc# 1000625
    rm -f /usr/lib/tmpfiles.d/nvidia-logind-acl-trick-G06.conf
    # remove TW Workaround for simpledrm during uninstall (boo#1201392)
    %if 0%{?suse_version} >= 1550
    pbl --del-option nosimplefb=1 --config
    %endif
fi
