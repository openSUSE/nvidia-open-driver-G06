if [ "$1" = 0 ] ; then
    # get rid of *all* nvidia kernel modules when uninstalling package (boo#1180010)
    # Don't do it if there is still an nvidia kmp package installed, or we end up
    # removing the freshly built modules from the other package (ex. switching between
    # open and closed modules).
    rpm -qa nvidia-driver-G06-kmp\* | grep -q nvidia-driver-G06-kmp
    if [ $? -eq 1 ]; then
        for dir in $(find /lib/modules  -mindepth 1 -maxdepth 1 -type d -name "*-${flavor}"); do
            test -d $dir/updates && rm -f $dir/updates/nvidia*.ko
        done
    fi
    # get rid of broken weak-updates symlinks created in %post / %trigger
    # either by kmp itself or by kernel package update
    for i in $(find /lib/modules/*-${flavor}/weak-updates -type l 2> /dev/null); do 
            test -e $i || rm $i
    done
    # cleanup of bnc# 1000625
    rm -f /usr/lib/tmpfiles.d/nvidia-logind-acl-trick-G06.conf
fi
