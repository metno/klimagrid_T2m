#!/bin/bash
# << klimagrid_T2m.sh >>
# Description
# transform AROME_METCOOP 2.5Km files to 1Km UTM grid used for seNorge2
#
# set dates
DATESTART=2014.06.01
DATEEND=2015.06.01
# extract year/month/day
yyyy_b=${DATESTART:0:4}
mm_b=${DATESTART:5:2}
dd_b=${DATESTART:8:2}
#hh_b=${DATESTART:11:2}
hh_b=12
yyyy_e=${DATEEND:0:4}
mm_e=${DATEEND:5:2}
dd_e=${DATEEND:8:2}
#hh_e=${DATEEND:11:2}
hh_e=22
# transformation to seconds from 1970-01-01
ss_b=`date +%s -d "$yyyy_b-$mm_b-$dd_b $hh_b:00:00"`
ss_e=`date +%s -d "$yyyy_e-$mm_e-$dd_e $hh_e:00:00"`
ss=$ss_b
# time step
ss_add=$(( 3600*24 ))
# fixed variable
path_fixed="/vol/starc/DNMI_AROME_METCOOP"
# cycle over days
while [ "$ss" -lt "$ss_e" ] 
do
  yyyy=`date --date="1970-01-01 $ss sec UTC" +%Y`
  mm=`date --date="1970-01-01 $ss sec UTC" +%m`
  dd=`date --date="1970-01-01 $ss sec UTC" +%d`
  # 4 model runs every day: 00,06,12,18 UTC
  for hh in 00 06 12 18; do
    # set filename
    filename=$path_fixed/$yyyy/$mm/$dd"/AROME_MetCoOp_"$hh"_sfx.nc_"$yyyy$mm$dd
    if [ ! -f $filename ]; then
      echo "@@" $filename not found
    else
      echo $filename
#      gridpp ... -> output in /disk1/projects/klimagrid_T2m/AROME_MetCoOp_UTM
    fi
  done
# update day 
  ss=$(( ss+ss_add ))
done
#
exit 0
