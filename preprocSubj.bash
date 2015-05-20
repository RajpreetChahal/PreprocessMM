#!/usr/bin/env bash
#
# Give me a subject id (luna_date)
# and I'll give you rest preprocessed in a folder for that subject
#  (outside of the MB folder, so MH can do his magic)
#



set -xe
scriptdir=$(cd $(dirname $0);pwd)

## where to put the preproc data
ppdir=$scriptdir/Preprocess_Rest
[ ! -d $subjdir ] && mkdir $ppdir


## where to find the raw data
rawroot="$scriptdir/../MMClock/MR_Raw"
MBroot="$scriptdir/../MMClock/WPC-5640_MB"
slicetimingfile="/Volumes/Serena/SPECC/MR_Raw/speccMBTimings.1D"
[ ! -r $slicetimingfile ] && echo "cannot find slice timing file '$slicetimingfile'!" && exit 1

subjdate=$1
[ -z "$subjdate" ] && echo "give me a subj!" && exit 1

## did we already run this?
#  was it a successful run?

finaldir="$ppdir/$subjdate"
finaloutname="$finaldir/brnswudktm_rest_5.nii.gz"
[ -r $finaloutname ] &&  echo "$subjdate: already successful completed" && exit 0
[ -d $finaldir ] &&  echo -e "$subjdate: have $finaldir but not $finaloutname;\n to try again, remove $finaldir" && exit 1


# do we have rest MB
#  use symbolic link format (more consitant than folder names)
# find the hdr
submbdir="$MBroot/WPC5640_$subjdate"
[ ! -d $submbdir ] && echo "no MB dir for $subjdate!" && exit 1
mbhdr="$submbdir/meas_*_ep2d_MB_rest_*_MB.hdr"
[ ! -r $mbhdr ] && echo "no MB rest for $subjdate!" && exit 1

# do we have mprage (bet,warp)
subt1dir="$rawroot/$subjdate/mprage"
[ ! -d $subt1dir ] && echo "no mprage dir ($subt1dir) for $subjdate!" && exit 1
bet="$subt1dir/mprage_bet.nii.gz"
warp="$subt1dir/mprage_warpcoef.nii.gz"
[ ! -r $bet -o ! -r $warp ] && echo "cannot find mprage stuff ($bet, $warp)" && exit 1

# do we have grefield (phase,mag)
# always take the last, there should be 2 (first is phase, second mag)
# also make sure we are sorting by the run num (.xx)
gres=( $(find  "$rawroot/$subjdate/" -type d -name 'gre_field_mapping*' -maxdepth 1 |
  sort -t. -k2,2nr |
  tail -n 2) )
# first gre folder is mag, second is phase
[ -z "$gres" ] && echo "$subjdate: could not find any gre field map dirs!!" && exit 1
mag=${gres[0]}/
phase=${gres[1]}/
[ ! -d $phase -o ! -d $mag ] && echo "cannot find gre stuff ($bet, $warp)" && exit 1



# echo -e "
# WOOT WE HAVE EVERYTHING
# hdr:\t$mbhdr
# bet:\t$bet
# warp:\t$warp
# phase:\t$phase
# mag:\t$mag
# "


### HAVE EVERYTHING we need to preprocess

# create the preproc directory, and go there
[ ! -d $finaldir ] && mkdir $finaldir
cd $finaldir

# get mb rest as a nifti
3dcopy $mbhdr rest.nii.gz

# run MH's preprocesssFunctional for rest
preprocessFunctional -4d rest.nii.gz -tr 1.0 \
	-rescaling_method 100_voxelmean \
	-template_brain MNI_2.3mm \
	-func_struc_dof bbr -warp_interpolation spline \
	-constrain_to_template y -4d_slice_motion \
	-custom_slice_times $slicetimingfile \
	-wavelet_despike -wavelet_m1000 -wavelet_threshold 10 \
	-motion_censor fd=0.3,dvars=20 -smoothing_kernel 5 -bandpass_filter .009 .08 \
	-nuisance_regression 6motion,d6motion,csf,dcsf,wm,dwm \
      	-fm_cfg clock \
	-mprage_bet $bet \
	-warpcoef $warp \
	-fm_phase "$phase/MR*"\
       	-fm_magnitude "$mag/MR*"\


[ ! -r $finaloutname ] &&  echo "$subjdate: failed to create $finaloutname!" && exit 1
