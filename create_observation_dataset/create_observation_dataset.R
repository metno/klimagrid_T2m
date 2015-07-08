# --~- Bspat_TEMP1h_v1_1.R  -~--
# Bayesian spatial interpolation of TA.
# TA = istantaneous air temperature (sampled with hourly frequency)
# Spatial Consistency Test (SCT) is included.
#
# Outputs: look for "@@@@@@@@@" in the code and you'll get the ouput formats
#
# History:
# 26.02.2015 - Cristian Lussana. original code from Bspat_TAMRR_v1_0.R
#  change log: 
#  - allow for the use of observations outside Norway
#  - revisied queries to KDVH
#  - geographical information on seNorge2_dem_UTM33.nc
#  - definition of TEMP1h
#  - definition of a new directory tree
# ==~==========================================================================
rm(list=ls())
# Libraries
library(raster)
library(rgdal)
library(ncdf)
#-------------------------------------------------------------------
# FUNCTIONS 
# manage fatal error
error_exit<-function(str=NULL) {
  print("Fatal Error:")
  if (!is.null(str)) print(str)
  quit(status=1)
}
#-------------------------------------------------------------------
# CRS strings
proj4.wgs84<-"+proj=longlat +datum=WGS84"
proj4.ETRS_LAEA<-"+proj=laea +lat_0=52 +lon_0=10 +x_0=4321000 +y_0=3210000 +ellps=GRS80 +units=m +no_defs"
proj4.utm33<-"+proj=utm +zone=33 +datum=WGS84 +units=m +no_defs +ellps=WGS84 +towgs84=0,0,0"
#
max.Km.stnINdomain<-300
#-------------------------------------------------------------------
# [] Setup OI parameters
sig2o<-1.3
eps2<-0.5
Dh<-60
Dz<-600
T2<-15
# Background - parameters
Dh.b<-70.
eps2.b<-0.5
Lsubsample<-50
Lsubsample.max<-50
Lsubsample.DHmax<-200
Lsubsample.vec<-vector()
#
print("ANALYSIS and DQC parameters")
print(paste("EPS2 Dh[Km] Dz[m] > ", round(eps2,3),
                                    round(Dh,3),
                                    round(Dz,3),
                                    sep=" "))
print(paste("VARobs[C^2] T^2 = ", round(sig2o,3), round(T2,3),sep=" "))
# MAIN ========================================================================
# Read command line arguments
arguments <- commandArgs()
arguments
date.string<-arguments[3]
config_file<-arguments[4]
config_par<-arguments[5]
if (length(arguments)!=5) 
  ext<-error_exit(paste("Error in command line arguments: \n",
  " R --vanilla yyyy.mm.dd.hh configFILE configPAR \n",
  sep=""))
# [] define/check paths
if (!file.exists(config_file)) 
  ext<-error_exit("Fatal Error: configuration file not found")
source(config_file)
for (p in 1:length(config_list)) {
  if (config_list[[p]]$pname==config_par) break
}
if (p==length(config_list) & (config_list[[p]]$pname!=config_par) )  
  ext<-error_exit("Fatal Error: configuration parameter not in configuration file")
main.path<-config_list[[p]]$opt$main.path
main.path.output<-config_list[[p]]$opt$main.path.output
testmode<-config_list[[p]]$opt$testmode
if ( !(file.exists(main.path)) | !(file.exists(main.path.output)) ) 
  ext<-error_exit("Fatal Error: path not found")
# common libs and etcetera
path2lib.com<-paste(main.path,"/lib",sep="")
path2etc.com<-paste(main.path,"/etc",sep="")
if (!file.exists(paste(path2lib.com,"/getStationData.R",sep=""))) 
  ext<-error_exit(paste("File not found:",path2lib.com,"/getStationData.R"))
source(paste(path2lib.com,"/getStationData.R",sep=""))
# set Time-related variables
yyyy<-substr(date.string,1,4)
mm<-substr(date.string,6,7)
dd<-substr(date.string,9,10)
hh<-substr(date.string,12,13)
# useful only if nmt=1 in database query
#if (as.numeric(hh)==0) {
#  print(paste("Warning! Timestamp will be modified: from ",yyyy,".",mm,".",dd," ",hh,sep=""))
#  aux.date <- strptime(paste(yyyy,mm,dd,hh,sep="."),"%Y.%m.%d.%H","UTC")
#  date.minus.1h<-as.POSIXlt(seq(as.POSIXlt(aux.date),length.out=2,by="-1 hour"),"UTC")
#  aux.date<-date.minus.1h[2]
#  yyyy<-aux.date$year+1900
#  mm<-formatC(aux.date$mon+1,width=2,flag="0")
#  dd<-formatC(aux.date$mday,width=2,flag="0")
#  hh<-24
#  print(paste("to ",yyyy,".",mm,".",dd," ",hh," (UTC+1)",sep=""))
#}
date.dot<-paste(dd,".",mm,".",yyyy,sep="")
yyyymm<-paste(yyyy,mm,sep="")
yyyymmdd<-paste(yyyymm,dd,sep="")
yyyymmddhh<-paste(yyyymmdd,hh,sep="")
h<-as.numeric(hh)
# output directories
dir.create(file.path(main.path.output,"seNorge2"), showWarnings = FALSE)
path2output.main<-paste(main.path.output,"/seNorge2/TEMP1h",sep="")
path2output.main.stn<-paste(path2output.main,"/station_dataset",sep="")
if (!(file.exists(path2output.main)))     dir.create(path2output.main,showWarnings=F) 
if (!(file.exists(path2output.main.stn))) dir.create(path2output.main.stn,showWarnings=F) 
# Setup output files 
dir.create(paste(path2output.main.stn,"/",yyyymm,sep=""),showWarnings=F)
out.file.stn<- paste(path2output.main.stn,"/",yyyymm,
                "/seNorge_v2_0_TEMP1h_station_",yyyymmddhh,".txt",sep="")
#
print("Output files:")
print("station outputs (text)")
print(out.file.stn)
#------------------------------------------------------------------------------
# [] Read Station Information 
# conditions:
# 1. stations in KDVH having: lat, lon and elevation. Note that UTM33 is 
#    obtained from lat,lon. Furthermore, the location must be in Norway or on
#    the border (less than max.Km.stnINdomain)
# 2. stations in CG
if (!testmode) {
  stations<-getStationMetadata(from.year=yyyy,to.year=yyyy,
                               max.Km=max.Km.stnINdomain)
} else {
  stations<-read.csv(file=station.info)
}
LOBS<-length(stations$stnr)
print(LOBS)
# define Vectors and Matrices
VecX<-vector(mode="numeric",length=LOBS)
VecY<-vector(mode="numeric",length=LOBS)
VecZ<-vector(mode="numeric",length=LOBS)
VecS<-vector(mode="numeric",length=LOBS)
yo<-vector(mode="numeric",length=LOBS)
VecX<-as.numeric(as.vector(stations$x))
VecY<-as.numeric(as.vector(stations$y))
VecZ<-as.numeric(as.vector(stations$z))
VecS<-as.numeric(as.vector(stations$stnr))
# DEBUG
#print(stations)
#write.table(file="stations.txt",stations)
#stations<-read.table(file="stations.txt")
#print(stations[1,])
#stations<-read.table("stations.txt",header=TRUE)
#print(stations[1,])
#  stnr z      x       y fennomean fenno_min4 fenno_long fenno_lat
# number of days
#print(ndays)
#------------------------------------------------------------------------------
# Elaborations
# define header for the station data output file
cat(paste("year","month","day","hour","stid","x","y","z","yo","\n",sep=";"),
          file=out.file.stn,append=F)
# Station Points - Write output on file 
#
if (!testmode) {
  data<-getStationData(var="TA", from.yyyy=yyyy, from.mm=mm, from.dd=dd, h=h,
                       to.yyyy=yyyy, to.mm=mm, to.dd=dd,
                       qa=NULL, statlist=stations, outside.Norway=T,
                       verbose=T)
} else {
  data<-read.csv(file=observed.data)
}
print(data)
yo<-as.numeric(data$value)


cat(paste(yyyy,mm,dd,h,
          round(VecS,0),round(VecX,0),round(VecY,0),round(VecZ,0),
          round(yo,1),"\n",sep=";"),file=out.file.stn,append=T)
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# Exit - Success
q(status=0)

