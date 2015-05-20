#!/usr/bin/env bash

#
# run preprocessing for everyone (1* in MMClock/MR_Raw)
#  in parallel
#

## job control
MAXJOBS=5
sleeptime=050
function waitforjobs {
	while [ $(jobs -p | wc -l) -ge $MAXJOBS ]; do
		echo "@$MAXJOBS jobs, sleeping $sleeptime s"
		jobs | sed 's/^/\t/'
		sleep $sleeptime
	done
}

scriptdir=$(cd $(dirname $0);pwd)

## actual loop
for subjMMdir  in $scriptdir/../MMClock/MR_Raw/1*; do
	subjdate=$(basename $subjMMdir)
 $scriptdir/preprocSubj.bash $subjdate &
	waitforjobs
done

# wait for everything to finish before saying we're done
wait

