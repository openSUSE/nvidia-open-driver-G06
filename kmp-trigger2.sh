# get rid of broken weak-updates symlinks created in some %post apparently;
# either by kmp itself or by kernel package update
for i in $(find /lib/modules/*/weak-updates -type l 2> /dev/null); do 
  test -e $i || rm $i
done
