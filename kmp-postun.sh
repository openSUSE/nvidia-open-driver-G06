if [ "$1" = 0 ] ; then
    # get rid of *all* nvidia kernel modules when uninstalling package (boo#1180010)
    for dir in $(find /lib/modules  -mindepth 1 -maxdepth 1 -type d -name "*-${flavor}"); do
            test -d $dir/updates && rm -f  $dir/updates/nvidia*.ko
    done
    # get rid of broken weak-updates symlinks created in %post / %trigger
    # either by kmp itself or by kernel package update
    for i in $(find /lib/modules/*-${flavor}/weak-updates -type l 2> /dev/null); do 
            test -e $i || rm $i
    done
    # cleanup of bnc# 1000625
    rm -f /usr/lib/tmpfiles.d/nvidia-logind-acl-trick-G06.conf
fi
