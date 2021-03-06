#Julian Ramirez-Villegas
#UoL / CCAFS / CIAT
#Aug 2013
stop("!")

#load packages
library(rgdal); library(raster); library(maptools); library(rasterVis); data(wrld_simpl)
library(ggplot2); library(plyr)

#source functions
src.dir <- "~/Repositories/dapa-climate-change/trunk/scaling-effect"
src.dir2 <- "~/Repositories/dapa-climate-change/trunk/PhD/0006-weather-data"
source(paste(src.dir,"/scripts/EcoCrop-model.R",sep=""))
source(paste(src.dir2,"/scripts/GHCND-GSOD-functions.R",sep=""))

#i/o directories and details
#bDir <- "/mnt/a102/eejarv/scaling-effect"
#bDir <- "/nfs/a102/eejarv/scaling-effect"
bDir <- "~/Leeds-work/scaling-effect"
clmDir <- paste(bDir,"/climate_data",sep="")
runDir <- paste(bDir,"/model-runs_gnut",sep="")
lsmDir <- paste(bDir,"/lsm",sep="")

#figure dir is local (on mbp)
figDir <- paste(bDir,"/figures_gnut",sep="")

#model run details
trial <- 3
crop_name <- "gnut"

#get mask from CASCADE output
msk <- raster(paste(lsmDir,"/Glam_12km_lsm.nc",sep=""))
msk[which(msk[] < 0)] <- NA
msk[which(msk[] > 0)] <- 1 #1:length(which(msk[] > 0))

#find other interesting points
if (!file.exists(paste(lsmDir,"/3deg_mask.tif",sep=""))) {
  msk2 <- msk
  msk2[which(!is.na(msk2[]))] <- rnorm(length(which(!is.na(msk2[]))),10,2)
  writeRaster(msk2,paste(lsmDir),format="GTiff")
} else {
  msk2 <- raster(paste(lsmDir,"/3deg_mask.tif",sep=""))
}

#new points
s1 <- extent(-16.5,-13.5,12,15)
s2 <- extent(7.5,10.5,12,15)

p00 <- extent(msk)
p00@ymax <- 15

#load harvested area and locations on top
ahar <- raster(paste(bDir,"/calendar/Groundnuts.crop.calendar/cascade_aharv.tif",sep=""))
ahar[which(ahar[]==0)] <- NA; ahar[which(ahar[]>1)] <- 1
ahar@crs <- wrld_simpl@proj4string


###############################################################################
###############################################################################
#make the scaling plots
#### 12 km explicit sites S4 and S5
scaleplotDir <- paste(figDir,"/scale_plots_12km_exp",sep="")
if (!file.exists(scaleplotDir)) {dir.create(scaleplotDir)}

resol <- "12km_exp"
cat("resolution:",resol,"\n")
trunDir <- paste(runDir,"/",resol,"/run_",trial,sep="")
srunDir <- paste(runDir,"/3deg/",resol,"-run_",trial,sep="")

#load suitability, rain and temp raster ---at high resolution
suit <- raster(paste(trunDir,"/",crop_name,"_suitability.tif",sep=""))
prec <- raster(paste(trunDir,"/",crop_name,"_gsrain.tif",sep=""))
tmen <- raster(paste(trunDir,"/",crop_name,"_gstmean.tif",sep=""))

#load suitability, rain and temp raster ---at low resolution
suit_sc <- raster(paste(srunDir,"/",crop_name,"_suitability.tif",sep=""))
prec_sc <- raster(paste(srunDir,"/",crop_name,"_gsrain.tif",sep=""))
tmen_sc <- raster(paste(srunDir,"/",crop_name,"_gstmean.tif",sep=""))

#matrix of sites, intervals and max/min values
plotinfo <- data.frame(SITE=paste("S",1:2,sep=""),P_int=c(10,10),
                       T_int=c(0.5,0.5),P_min=c(-90,-50),
                       P_max=c(100,100),T_min=c(-4.5,-3),T_max=c(3.5,2.0))

#produce the scaling plot for each point
for (i in 1:2) {
  #i <- 1
  cat("...",i,"\n")
  text <- get(paste("s",i,sep=""))
  xy <- c(x=(text@xmin+text@xmax)*.5,y=(text@ymin+text@ymax)*.5)
  suit_p <- crop(suit,text); prec_p <- crop(prec,text); tmen_p <- crop(tmen,text) * 0.1
  ahar_p <- crop(ahar,text)
  
  #put all data in a single data frame
  tcells <- data.frame(CELL=1:ncell(prec_p))
  tcells$x <- xFromCell(prec_p,tcells$CELL); tcells$y <- yFromCell(prec_p,tcells$CELL)
  tcells$PREC <- extract(prec_p,tcells[,c("x","y")])
  tcells <- tcells[which(!is.na(tcells$PREC)),]
  
  tcells$TMEN <- extract(tmen_p,tcells[,c("x","y")])
  
  tcells$SUIT <- extract(suit_p,tcells[,c("x","y")])
  tcells <- tcells[which(!is.na(tcells$SUIT)),]
  
  tcells$AHAR <- extract(ahar_p,tcells[,c("x","y")])
  tcells <- tcells[which(!is.na(tcells$AHAR)),]
  
  tcells$PREC_DIF <- (tcells$PREC - mean(tcells$PREC)) / mean(tcells$PREC) * 100
  tcells$TMEN_DIF <- tcells$TMEN - mean(tcells$TMEN)
  
#   plot(density(tcells$SUIT))
#   abline(v=extract(suit_sc,text))
#   mean(tcells$SUIT)
#   mean(tcells$PREC)
#   mean(tcells$TMEN)
#   length(which(tcells$PREC < 176))/nrow(tcells)
#   length(which(tcells$PREC > 961))/nrow(tcells)
#   length(which(tcells$TMEN < 10))/nrow(tcells)
#   length(which(tcells$TMEN > 28.6))/nrow(tcells)
#   extract(suit_sc,text)
  
  tcells010 <- tcells[which(tcells$AHAR >= 0.1),]
  tcells010$PREC_DIF <- (tcells010$PREC - mean(tcells010$PREC)) / mean(tcells010$PREC) * 100
  tcells010$TMEN_DIF <- tcells010$TMEN - mean(tcells010$TMEN)
  
  #classes
  pr_seq <- seq(-100,100,by=plotinfo$P_int[i])
  pr_seq <- data.frame(INI=pr_seq[1:(length(pr_seq)-1)],FIN=pr_seq[2:length(pr_seq)])
  pr_seq <- cbind(CLASS=1:nrow(pr_seq),pr_seq)
  pr_seq$CENTER <- (pr_seq$INI + pr_seq$FIN) * 0.5
  
  tm_seq <- seq(-6,6,by=plotinfo$T_int[i])
  tm_seq <- data.frame(INI=tm_seq[1:(length(tm_seq)-1)],FIN=tm_seq[2:length(tm_seq)])
  tm_seq <- cbind(CLASS=1:nrow(tm_seq),tm_seq)
  tm_seq$CENTER <- (tm_seq$INI + tm_seq$FIN) * 0.5
  
  #calculate precip stuff
  pcurve <- data.frame()
  for (cl in 1:nrow(pr_seq)) {
    #cl <- 1
    #tcells <- which(prec_p[] >= pr_seq$INI[cl] & prec_p[] < pr_seq$FIN[cl])
    kcells <- tcells[which(tcells$PREC_DIF >= pr_seq$INI[cl] & tcells$PREC_DIF < pr_seq$FIN[cl]),]
    
    if (nrow(kcells) == 0) {
      smean <- NA; sstdv <- NA; pmean <- NA; pdmean <- NA
    } else {
      if (cl < nrow(pr_seq)) {
        smean <- mean(kcells$SUIT,na.rm=T)
        sstdv <- sd(kcells$SUIT,na.rm=T)
        pmean <- mean(kcells$PREC,na.rm=T)
        pdmean <- mean(kcells$PREC_DIF,na.rm=T)
      } else {
        smean <- mean(kcells$SUIT,na.rm=T)
        sstdv <- sd(kcells$SUIT,na.rm=T)
        pmean <- mean(kcells$PREC,na.rm=T)
        pdmean <- mean(kcells$PREC_DIF,na.rm=T)
      }
    }
    clout <- data.frame(CLASS=cl,MID=pr_seq$CENTER[cl],SUIT.ME=smean,SUIT.SD=sstdv,
                        PREC=pmean,PREC_DIF=pdmean,COUNT=nrow(kcells))
    pcurve <- rbind(pcurve,clout)
  }
  
  #remove NAs
  pcurve <- pcurve[which(!is.na(pcurve$SUIT.SD)),]
  pcurve$FREQ <- pcurve$COUNT / sum(pcurve$COUNT) * 100
  
  #ggplot plot
  p <- ggplot(pcurve, aes(x=MID,y=FREQ))
  p <- p + geom_bar(alpha=0.5, stat="identity")
  p <- p + geom_line(data=pcurve, aes(x=MID, y=SUIT.ME), colour="red")
  p <- p + geom_point(x=((extract(prec_sc,text)-mean(tcells$PREC)) / mean(tcells$PREC) * 100),
                      y=extract(suit_sc,text),colour="black",shape=8,size=3)
  p <- p + geom_point(x=mean(tcells$PREC_DIF,na.rm=T),y=mean(tcells$SUIT,na.rm=T),
                      colour="red",shape=8,size=3)
  p <- p + scale_x_continuous(breaks=seq(-100,100,by=plotinfo$P_int[i]),
                              limits=c(plotinfo$P_min[i],plotinfo$P_max[i]))
  p <- p + scale_y_continuous(breaks=seq(0,100,by=10),limits=c(0,100))
  p <- p + labs(x="Precipitation difference (%)",y="Suitability (%)")
  p <- p + theme(panel.background=element_rect(fill="white",colour="black"),
                 axis.ticks=element_line(colour="black"),axis.text=element_text(size=12,colour="black"),
                 axis.title=element_text(size=13,face="bold"))
  
  pdf(paste(scaleplotDir,"/",resol,"_S",i,"_prec.pdf",sep=""),width=10,height=7)
  print(p)
  dev.off()
  
  ##
  #produce the same plot but for 010 areas
  #calculate precip stuff
  pcurve010 <- data.frame()
  for (cl in 1:nrow(pr_seq)) {
    #cl <- 1
    kcells010 <- tcells010[which(tcells010$PREC_DIF >= pr_seq$INI[cl] & tcells010$PREC_DIF < pr_seq$FIN[cl]),]
    
    if (nrow(kcells010) == 0) {
      smean <- NA; sstdv <- NA; pmean <- NA; pdmean <- NA
    } else {
      if (cl < nrow(pr_seq)) {
        smean <- mean(kcells010$SUIT,na.rm=T)
        sstdv <- sd(kcells010$SUIT,na.rm=T)
        pmean <- mean(kcells010$PREC,na.rm=T)
        pdmean <- mean(kcells010$PREC_DIF,na.rm=T)
      } else {
        smean <- mean(kcells010$SUIT,na.rm=T)
        sstdv <- sd(kcells010$SUIT,na.rm=T)
        pmean <- mean(kcells010$PREC,na.rm=T)
        pdmean <- mean(kcells010$PREC_DIF,na.rm=T)
      }
    }
    clout <- data.frame(CLASS=cl,MID=pr_seq$CENTER[cl],SUIT.ME=smean,SUIT.SD=sstdv,
                        PREC=pmean,PREC_DIF=pdmean,COUNT=nrow(kcells010))
    pcurve010 <- rbind(pcurve010,clout)
  }
  
  #remove NAs
  pcurve010 <- pcurve010[which(!is.na(pcurve010$SUIT.SD)),]
  pcurve010$FREQ <- pcurve010$COUNT / sum(pcurve010$COUNT) * 100
  
  #ggplot plot
  p <- ggplot(pcurve010, aes(x=MID,y=FREQ))
  p <- p + geom_bar(alpha=0.5, stat="identity")
  p <- p + geom_line(data=pcurve010, aes(x=MID, y=SUIT.ME), colour="red")
  p <- p + geom_point(x=((extract(prec_sc,text)-mean(tcells010$PREC)) / mean(tcells010$PREC) * 100),
                      y=extract(suit_sc,text),colour="black",shape=8,size=3)
  p <- p + geom_point(x=mean(tcells010$PREC_DIF,na.rm=T),y=mean(tcells010$SUIT,na.rm=T),
                      colour="red",shape=8,size=3)
  p <- p + scale_x_continuous(breaks=seq(-100,100,by=plotinfo$P_int[i]),
                              limits=c(plotinfo$P_min[i],plotinfo$P_max[i]))
  p <- p + scale_y_continuous(breaks=seq(0,100,by=10),limits=c(0,100))
  p <- p + labs(x="Precipitation difference (%)",y="Suitability (%)")
  p <- p + theme(panel.background=element_rect(fill="white",colour="black"),
                 axis.ticks=element_line(colour="black"),axis.text=element_text(size=12,colour="black"),
                 axis.title=element_text(size=13,face="bold"))
  
  pdf(paste(scaleplotDir,"/",resol,"_S",i,"_prec_010.pdf",sep=""),width=10,height=7)
  print(p)
  dev.off()
  
  
  #calculate temperature stuff for all areas
  tcurve <- data.frame()
  for (cl in 1:nrow(tm_seq)) {
    kcells <- tcells[which(tcells$TMEN_DIF >= tm_seq$INI[cl] & tcells$TMEN_DIF < tm_seq$FIN[cl]),]
    if (length(kcells) == 0) {
      smean <- NA; sstdv <- NA; tmean <- NA; tmeand <- NA
    } else {
      if (cl < nrow(tm_seq)) {
        smean <- mean(kcells$SUIT,na.rm=T)
        sstdv <- sd(kcells$SUIT,na.rm=T)
        tmean <- mean(kcells$TMEN,na.rm=T)
        tmeand <- mean(kcells$TMEN_DIF,na.rm=T)
      } else {
        smean <- mean(kcells$SUIT,na.rm=T)
        sstdv <- sd(kcells$SUIT,na.rm=T)
        tmean <- mean(kcells$TMEN,na.rm=T)
        tmeand <- mean(kcells$TMEN_DIF,na.rm=T)
      }
    }
    clout <- data.frame(CLASS=cl,MID=tm_seq$CENTER[cl],SUIT.ME=smean,SUIT.SD=sstdv,TMEAN=tmean,
                        TMEAN_DIF=tmeand,COUNT=nrow(kcells))
    tcurve <- rbind(tcurve,clout)
  }
  
  #remove NAs
  tcurve <- tcurve[which(!is.na(tcurve$SUIT.SD)),]
  tcurve$FREQ <- tcurve$COUNT / sum(tcurve$COUNT) * 100
  
  #produce plot
  p <- ggplot(tcurve, aes(x=MID,y=FREQ))
  p <- p + geom_bar(alpha=0.5, stat="identity")
  p <- p + geom_line(data=tcurve, aes(x=MID, y=SUIT.ME), colour="red")
  p <- p + geom_point(x=(extract(tmen_sc,text)*.1-mean(tcells$TMEN)),
                      y=extract(suit_sc,text),colour="black",shape=8,size=3)
  p <- p + geom_point(x=mean(tcells$TMEN_DIF,na.rm=T),y=mean(tcells$SUIT,na.rm=T),
                      colour="red",shape=8,size=3)
  p <- p + scale_x_continuous(breaks=seq(-10,10,by=plotinfo$T_int[i]),
                              limits=c(plotinfo$T_min[i],plotinfo$T_max[i]))
  p <- p + scale_y_continuous(breaks=seq(0,100,by=10),limits=c(0,100))
  p <- p + labs(x="Mean temperature difference (K)",y="Suitability (%)")
  p <- p + theme(panel.background=element_rect(fill="white",colour="black"),
                 axis.ticks=element_line(colour="black"),axis.text=element_text(size=12,colour="black"),
                 axis.title=element_text(size=13,face="bold"))
  
  pdf(paste(scaleplotDir,"/",resol,"_S",i,"_tmean.pdf",sep=""),width=10,height=7)
  print(p)
  dev.off()
  
  #calculate temperature stuff for all areas
  tcurve010 <- data.frame()
  for (cl in 1:nrow(tm_seq)) {
    kcells010 <- tcells010[which(tcells010$TMEN_DIF >= tm_seq$INI[cl] & tcells010$TMEN_DIF < tm_seq$FIN[cl]),]
    if (length(kcells010) == 0) {
      smean <- NA; sstdv <- NA; tmean <- NA; tmeand <- NA
    } else {
      if (cl < nrow(tm_seq)) {
        smean <- mean(kcells010$SUIT,na.rm=T)
        sstdv <- sd(kcells010$SUIT,na.rm=T)
        tmean <- mean(kcells010$TMEN,na.rm=T)
        tmeand <- mean(kcells010$TMEN_DIF,na.rm=T)
      } else {
        smean <- mean(kcells010$SUIT,na.rm=T)
        sstdv <- sd(kcells010$SUIT,na.rm=T)
        tmean <- mean(kcells010$TMEN,na.rm=T)
        tmeand <- mean(kcells010$TMEN_DIF,na.rm=T)
      }
    }
    clout <- data.frame(CLASS=cl,MID=tm_seq$CENTER[cl],SUIT.ME=smean,SUIT.SD=sstdv,TMEAN=tmean,
                        TMEAN_DIF=tmeand,COUNT=nrow(kcells010))
    tcurve010 <- rbind(tcurve010,clout)
  }
  
  #remove NAs
  tcurve010 <- tcurve010[which(!is.na(tcurve010$SUIT.SD)),]
  tcurve010$FREQ <- tcurve010$COUNT / sum(tcurve010$COUNT) * 100
  
  #produce plot
  p <- ggplot(tcurve010, aes(x=MID,y=FREQ))
  p <- p + geom_bar(alpha=0.5, stat="identity")
  p <- p + geom_line(data=tcurve010, aes(x=MID, y=SUIT.ME), colour="red")
  p <- p + geom_point(x=(extract(tmen_sc,text)*.1-mean(tcells010$TMEN)),
                      y=extract(suit_sc,text),colour="black",shape=8,size=3)
  p <- p + geom_point(x=mean(tcells010$TMEN_DIF,na.rm=T),y=mean(tcells010$SUIT,na.rm=T),
                      colour="red",shape=8,size=3)
  p <- p + scale_x_continuous(breaks=seq(-10,10,by=plotinfo$T_int[i]),
                              limits=c(plotinfo$T_min[i],plotinfo$T_max[i]))
  p <- p + scale_y_continuous(breaks=seq(0,100,by=10),limits=c(0,100))
  p <- p + labs(x="Mean temperature difference (K)",y="Suitability (%)")
  p <- p + theme(panel.background=element_rect(fill="white",colour="black"),
                 axis.ticks=element_line(colour="black"),axis.text=element_text(size=12,colour="black"),
                 axis.title=element_text(size=13,face="bold"))
  
  pdf(paste(scaleplotDir,"/",resol,"_S",i,"_tmean_010.pdf",sep=""),width=10,height=7)
  print(p)
  dev.off()
}



####
#### obs sites S1 through S2

#######################################################################
#produce 3deg data by aggregation from (04km_exp, 12kmexp, 12km, and 40km)
msk_3d <- raster(paste(bDir,"/lsm/Glam_3deg_lsm.nc",sep=""))
msk_3d[which(msk_3d[] > 0)] <- 1
msk_3d[which(msk_3d[] < 0)] <- NA

cat("aggregating",resol,"\n")
odataDir <- paste(clmDir,"/global_5min",sep="")

toutDir <- paste(clmDir,"/cascade_3deg-",resol,sep="")
if (!file.exists(toutDir)) {dir.create(toutDir)}

tmsk <- raster(paste(bDir,"/lsm/Glam_12km_lsm.nc",sep=""))
tmsk[which(tmsk[] > 0)] <- 1
tmsk[which(tmsk[] < 0)] <- NA

for (vn in c("prec","tmin","tmax","tmean")) {
  #vn <- "prec"
  cat("...",vn,"\n")
  for (m in 1:12) {
    #m <- 1
    cat("...",m,"\n")
    if (!file.exists(paste(toutDir,"/",vn,"_",m,".tif",sep=""))) {
      rs <- raster(paste(odataDir,"/",vn,"_",m,sep=""))
      rs <- crop(rs, tmsk)
      fac <- xres(msk_3d) / xres(rs)
      rs <- aggregate(rs, fact=fac, fun=mean, na.rm=T)
      rs <- resample(rs, msk_3d, method="ngb")
      rs <- mask(rs, msk_3d)
      rs <- writeRaster(rs,paste(toutDir,"/",vn,"_",m,".tif",sep=""),format="GTiff")
    }
  }
}

###
#perform the 3deg runs
resol <- "obs"
cat("resolution:",resol,"\n")

trunDir <- paste(runDir,"/3deg",sep="")
if (!file.exists(trunDir)) {dir.create(trunDir)}

tcalDir <- paste(trunDir,"/calendar",sep="")

#three rasters
tpdate2 <- raster(paste(tcalDir,"/plant_3deg.tif",sep=""))
thdate2 <- raster(paste(tcalDir,"/harvest_3deg.tif",sep=""))

#resol <- resList[1]
odataDir <- paste(clmDir,"/cascade_3deg-",resol,sep="")

trial <- 3
outf <- paste(trunDir,"/",resol,"-run_",trial,sep="")

#model parameters
params <- read.csv(paste(runDir,"/parameter_sets.csv",sep=""))
selpar <- read.csv(paste(runDir,"/runs_discard.csv",sep=""))#[,c("RUN","SEL")]
maxauc <- selpar$RUN[which(selpar$HIGH.AUC == max(selpar$HIGH.AUC))]
params <- params[which(params$RUN == 7),]

rmin <- params$MIN[1]; ropmin <- params$OPMIN[1]; ropmax <- params$OPMAX[1]; rmax <- params$MAX[1] #trial 1
tkill <- params$KILL[2]; tmin <- 100; topmin <- params$OPMIN[2]; topmax <- params$OPMAX[2]; tmax <- 400 #trial 1

#run the model
if (!file.exists(paste(outf,"/out_suit.png",sep=""))) {
  eco <- suitCalc(climPath=odataDir, 
                  sowDat=tpdate2@file@name,
                  harDat=thdate2@file@name,
                  Gmin=NA,Gmax=NA,Tkmp=tkill,Tmin=tmin,Topmin=topmin,
                  Topmax=topmax,Tmax=tmax,Rmin=rmin,Ropmin=ropmin,
                  Ropmax=ropmax,Rmax=rmax, 
                  outfolder=outf,
                  cropname=crop_name,ext=".tif",cropClimate=F)
  
  png(paste(outf,"/out_suit.png",sep=""), height=1000,width=1500,units="px",pointsize=22)
  par(mar=c(3,3,1,2))
  rsx <- eco[[3]]; rsx[which(rsx[]==0)] <- NA; plot(rsx,col=rev(terrain.colors(20)))
  plot(wrld_simpl,add=T)
  grid(lwd=1.5)
  dev.off()
}


#### here plot
scaleplotDir <- paste(figDir,"/scale_plots_obs",sep="")
if (!file.exists(scaleplotDir)) {dir.create(scaleplotDir)}

trunDir <- paste(runDir,"/calib/run_",trial,sep="")
srunDir <- paste(runDir,"/3deg/",resol,"-run_",trial,sep="")

#load suitability, rain and temp raster ---at high resolution
suit <- raster(paste(trunDir,"/",crop_name,"_suitability.tif",sep=""))
prec <- raster(paste(trunDir,"/",crop_name,"_gsrain.tif",sep=""))
tmen <- raster(paste(trunDir,"/",crop_name,"_gstmean.tif",sep=""))

#load suitability, rain and temp raster ---at low resolution
suit_sc <- raster(paste(srunDir,"/",crop_name,"_suitability.tif",sep=""))
prec_sc <- raster(paste(srunDir,"/",crop_name,"_gsrain.tif",sep=""))
tmen_sc <- raster(paste(srunDir,"/",crop_name,"_gstmean.tif",sep=""))

#matrix of sites, intervals and max/min values
plotinfo <- data.frame(SITE=paste("S",1:2,sep=""),P_int=c(10,10),
                       T_int=c(0.25,0.5),P_min=c(-50,-70),
                       P_max=c(100,100),T_min=c(-1.5,-3),T_max=c(1.5,1.5))


############################################################################
############################################################################
#produce the scaling plot for each point
for (i in 1:2) {
  #i <- 1
  cat("...",i,"\n")
  text <- get(paste("s",i,sep=""))
  xy <- c(x=(text@xmin+text@xmax)*.5,y=(text@ymin+text@ymax)*.5)
  suit_p <- crop(suit,text); prec_p <- crop(prec,text); tmen_p <- crop(tmen,text) * 0.1
  ahar_p <- crop(ahar,text)
  
  #put all data in a single data frame
  tcells <- data.frame(CELL=1:ncell(prec_p))
  tcells$x <- xFromCell(prec_p,tcells$CELL); tcells$y <- yFromCell(prec_p,tcells$CELL)
  tcells$PREC <- extract(prec_p,tcells[,c("x","y")])
  tcells <- tcells[which(!is.na(tcells$PREC)),]
  
  tcells$TMEN <- extract(tmen_p,tcells[,c("x","y")])
  
  tcells$SUIT <- extract(suit_p,tcells[,c("x","y")])
  tcells <- tcells[which(!is.na(tcells$SUIT)),]
  
  tcells$AHAR <- extract(ahar_p,tcells[,c("x","y")])
  tcells <- tcells[which(!is.na(tcells$AHAR)),]
  
  tcells$PREC_DIF <- (tcells$PREC - mean(tcells$PREC)) / mean(tcells$PREC) * 100
  tcells$TMEN_DIF <- tcells$TMEN - mean(tcells$TMEN)
  
  tcells010 <- tcells[which(tcells$AHAR >= 0.1),]
  tcells010$PREC_DIF <- (tcells010$PREC - mean(tcells010$PREC)) / mean(tcells010$PREC) * 100
  tcells010$TMEN_DIF <- tcells010$TMEN - mean(tcells010$TMEN)
  
  #determine classes
  pr_seq <- seq(-100,100,by=plotinfo$P_int[i])
  pr_seq <- data.frame(INI=pr_seq[1:(length(pr_seq)-1)],FIN=pr_seq[2:length(pr_seq)])
  pr_seq <- cbind(CLASS=1:nrow(pr_seq),pr_seq)
  pr_seq$CENTER <- (pr_seq$INI + pr_seq$FIN) * 0.5
  
  tm_seq <- seq(-6,6,by=plotinfo$T_int[i])
  tm_seq <- data.frame(INI=tm_seq[1:(length(tm_seq)-1)],FIN=tm_seq[2:length(tm_seq)])
  tm_seq <- cbind(CLASS=1:nrow(tm_seq),tm_seq)
  tm_seq$CENTER <- (tm_seq$INI + tm_seq$FIN) * 0.5
  
  #calculate precip stuff
  pcurve <- data.frame()
  for (cl in 1:nrow(pr_seq)) {
    #cl <- 1
    #tcells <- which(prec_p[] >= pr_seq$INI[cl] & prec_p[] < pr_seq$FIN[cl])
    kcells <- tcells[which(tcells$PREC_DIF >= pr_seq$INI[cl] & tcells$PREC_DIF < pr_seq$FIN[cl]),]
    
    if (nrow(kcells) == 0) {
      smean <- NA; sstdv <- NA; pmean <- NA; pdmean <- NA
    } else {
      if (cl < nrow(pr_seq)) {
        smean <- mean(kcells$SUIT,na.rm=T)
        sstdv <- sd(kcells$SUIT,na.rm=T)
        pmean <- mean(kcells$PREC,na.rm=T)
        pdmean <- mean(kcells$PREC_DIF,na.rm=T)
      } else {
        smean <- mean(kcells$SUIT,na.rm=T)
        sstdv <- sd(kcells$SUIT,na.rm=T)
        pmean <- mean(kcells$PREC,na.rm=T)
        pdmean <- mean(kcells$PREC_DIF,na.rm=T)
      }
    }
    clout <- data.frame(CLASS=cl,MID=pr_seq$CENTER[cl],SUIT.ME=smean,SUIT.SD=sstdv,
                        PREC=pmean,PREC_DIF=pdmean,COUNT=nrow(kcells))
    pcurve <- rbind(pcurve,clout)
  }
  
  #remove NAs
  pcurve <- pcurve[which(!is.na(pcurve$SUIT.SD)),]
  pcurve$FREQ <- pcurve$COUNT / sum(pcurve$COUNT) * 100
  
  #ggplot plot
  p <- ggplot(pcurve, aes(x=MID,y=FREQ))
  p <- p + geom_bar(alpha=0.5, stat="identity")
  p <- p + geom_line(data=pcurve, aes(x=MID, y=SUIT.ME), colour="red")
  p <- p + geom_point(x=((extract(prec_sc,text)-mean(tcells$PREC)) / mean(tcells$PREC) * 100),
                      y=extract(suit_sc,text),colour="black",shape=8,size=3)
  p <- p + geom_point(x=mean(tcells$PREC_DIF,na.rm=T),y=mean(tcells$SUIT,na.rm=T),
                      colour="red",shape=8,size=3)
  p <- p + scale_x_continuous(breaks=seq(-100,100,by=plotinfo$P_int[i]),
                              limits=c(plotinfo$P_min[i],plotinfo$P_max[i]))
  p <- p + scale_y_continuous(breaks=seq(0,100,by=10),limits=c(0,100))
  p <- p + labs(x="Precipitation difference (%)",y="Suitability (%)")
  p <- p + theme(panel.background=element_rect(fill="white",colour="black"),
                 axis.ticks=element_line(colour="black"),axis.text=element_text(size=12,colour="black"),
                 axis.title=element_text(size=13,face="bold"))
  
  pdf(paste(scaleplotDir,"/",resol,"_S",i,"_prec.pdf",sep=""),width=10,height=7)
  print(p)
  dev.off()
  
  ##
  #produce the same plot but for 010 areas
  #calculate precip stuff
  pcurve010 <- data.frame()
  for (cl in 1:nrow(pr_seq)) {
    #cl <- 1
    kcells010 <- tcells010[which(tcells010$PREC_DIF >= pr_seq$INI[cl] & tcells010$PREC_DIF < pr_seq$FIN[cl]),]
    
    if (nrow(kcells010) == 0) {
      smean <- NA; sstdv <- NA; pmean <- NA; pdmean <- NA
    } else {
      if (cl < nrow(pr_seq)) {
        smean <- mean(kcells010$SUIT,na.rm=T)
        sstdv <- sd(kcells010$SUIT,na.rm=T)
        pmean <- mean(kcells010$PREC,na.rm=T)
        pdmean <- mean(kcells010$PREC_DIF,na.rm=T)
      } else {
        smean <- mean(kcells010$SUIT,na.rm=T)
        sstdv <- sd(kcells010$SUIT,na.rm=T)
        pmean <- mean(kcells010$PREC,na.rm=T)
        pdmean <- mean(kcells010$PREC_DIF,na.rm=T)
      }
    }
    clout <- data.frame(CLASS=cl,MID=pr_seq$CENTER[cl],SUIT.ME=smean,SUIT.SD=sstdv,
                        PREC=pmean,PREC_DIF=pdmean,COUNT=nrow(kcells010))
    pcurve010 <- rbind(pcurve010,clout)
  }
  
  #remove NAs
  pcurve010 <- pcurve010[which(!is.na(pcurve010$SUIT.SD)),]
  pcurve010$FREQ <- pcurve010$COUNT / sum(pcurve010$COUNT) * 100
  
  #ggplot plot
  p <- ggplot(pcurve010, aes(x=MID,y=FREQ))
  p <- p + geom_bar(alpha=0.5, stat="identity")
  p <- p + geom_line(data=pcurve010, aes(x=MID, y=SUIT.ME), colour="red")
  p <- p + geom_point(x=((extract(prec_sc,text)-mean(tcells010$PREC)) / mean(tcells010$PREC) * 100),
                      y=extract(suit_sc,text),colour="black",shape=8,size=3)
  p <- p + geom_point(x=mean(tcells010$PREC_DIF,na.rm=T),y=mean(tcells010$SUIT,na.rm=T),
                      colour="red",shape=8,size=3)
  p <- p + scale_x_continuous(breaks=seq(-100,100,by=plotinfo$P_int[i]),
                              limits=c(plotinfo$P_min[i],plotinfo$P_max[i]))
  p <- p + scale_y_continuous(breaks=seq(0,100,by=10),limits=c(0,100))
  p <- p + labs(x="Precipitation difference (%)",y="Suitability (%)")
  p <- p + theme(panel.background=element_rect(fill="white",colour="black"),
                 axis.ticks=element_line(colour="black"),axis.text=element_text(size=12,colour="black"),
                 axis.title=element_text(size=13,face="bold"))
  
  pdf(paste(scaleplotDir,"/",resol,"_S",i,"_prec_010.pdf",sep=""),width=10,height=7)
  print(p)
  dev.off()
  
  
  #calculate temperature stuff
  tcurve <- data.frame()
  for (cl in 1:nrow(tm_seq)) {
    kcells <- tcells[which(tcells$TMEN_DIF >= tm_seq$INI[cl] & tcells$TMEN_DIF < tm_seq$FIN[cl]),]
    if (nrow(kcells) == 0) {
      smean <- NA; sstdv <- NA; tmean <- NA; tmeand <- NA
    } else {
      if (cl < nrow(tm_seq)) {
        smean <- mean(kcells$SUIT,na.rm=T)
        sstdv <- sd(kcells$SUIT,na.rm=T)
        tmean <- mean(kcells$TMEN,na.rm=T)
        tmeand <- mean(kcells$TMEN_DIF,na.rm=T)
      } else {
        smean <- mean(kcells$SUIT,na.rm=T)
        sstdv <- sd(kcells$SUIT,na.rm=T)
        tmean <- mean(kcells$TMEN,na.rm=T)
        tmeand <- mean(kcells$TMEN_DIF,na.rm=T)
      }
    }
    clout <- data.frame(CLASS=cl,MID=tm_seq$CENTER[cl],SUIT.ME=smean,SUIT.SD=sstdv,TMEAN=tmean,
                        TMEAN_DIF=tmeand,COUNT=nrow(kcells))
    tcurve <- rbind(tcurve,clout)
  }
  
  #remove NAs
  tcurve <- tcurve[which(!is.na(tcurve$SUIT.SD)),]
  tcurve$FREQ <- tcurve$COUNT / sum(tcurve$COUNT) * 100
  
  #produce plot
  p <- ggplot(tcurve, aes(x=MID,y=FREQ))
  p <- p + geom_bar(alpha=0.5, stat="identity")
  p <- p + geom_line(data=tcurve, aes(x=MID, y=SUIT.ME), colour="red")
  p <- p + geom_point(x=(extract(tmen_sc,text)*.1-mean(tcells$TMEN)),
                      y=extract(suit_sc,text),colour="black",shape=8,size=3)
  p <- p + geom_point(x=mean(tcells$TMEN_DIF,na.rm=T),y=mean(tcells$SUIT,na.rm=T),
                      colour="red",shape=8,size=3)
  p <- p + scale_x_continuous(breaks=seq(-10,10,by=plotinfo$T_int[i]),
                              limits=c(plotinfo$T_min[i],plotinfo$T_max[i]))
  p <- p + scale_y_continuous(breaks=seq(0,100,by=10),limits=c(0,100))
  p <- p + labs(x="Mean temperature difference (K)",y="Suitability (%)")
  p <- p + theme(panel.background=element_rect(fill="white",colour="black"),
                 axis.ticks=element_line(colour="black"),axis.text=element_text(size=12,colour="black"),
                 axis.title=element_text(size=13,face="bold"))
  
  pdf(paste(scaleplotDir,"/",resol,"_S",i,"_tmean.pdf",sep=""),width=10,height=7)
  print(p)
  dev.off()
  
  #calculate temperature stuff for all areas
  tcurve010 <- data.frame()
  for (cl in 1:nrow(tm_seq)) {
    kcells010 <- tcells010[which(tcells010$TMEN_DIF >= tm_seq$INI[cl] & tcells010$TMEN_DIF < tm_seq$FIN[cl]),]
    if (length(kcells010) == 0) {
      smean <- NA; sstdv <- NA; tmean <- NA; tmeand <- NA
    } else {
      if (cl < nrow(tm_seq)) {
        smean <- mean(kcells010$SUIT,na.rm=T)
        sstdv <- sd(kcells010$SUIT,na.rm=T)
        tmean <- mean(kcells010$TMEN,na.rm=T)
        tmeand <- mean(kcells010$TMEN_DIF,na.rm=T)
      } else {
        smean <- mean(kcells010$SUIT,na.rm=T)
        sstdv <- sd(kcells010$SUIT,na.rm=T)
        tmean <- mean(kcells010$TMEN,na.rm=T)
        tmeand <- mean(kcells010$TMEN_DIF,na.rm=T)
      }
    }
    clout <- data.frame(CLASS=cl,MID=tm_seq$CENTER[cl],SUIT.ME=smean,SUIT.SD=sstdv,TMEAN=tmean,
                        TMEAN_DIF=tmeand,COUNT=nrow(kcells010))
    tcurve010 <- rbind(tcurve010,clout)
  }
  
  #remove NAs
  tcurve010 <- tcurve010[which(!is.na(tcurve010$SUIT.SD)),]
  tcurve010$FREQ <- tcurve010$COUNT / sum(tcurve010$COUNT) * 100
  
  #produce plot
  p <- ggplot(tcurve010, aes(x=MID,y=FREQ))
  p <- p + geom_bar(alpha=0.5, stat="identity")
  p <- p + geom_line(data=tcurve010, aes(x=MID, y=SUIT.ME), colour="red")
  p <- p + geom_point(x=(extract(tmen_sc,text)*.1-mean(tcells010$TMEN)),
                      y=extract(suit_sc,text),colour="black",shape=8,size=3)
  p <- p + geom_point(x=mean(tcells010$TMEN_DIF,na.rm=T),y=mean(tcells010$SUIT,na.rm=T),
                      colour="red",shape=8,size=3)
  p <- p + scale_x_continuous(breaks=seq(-10,10,by=plotinfo$T_int[i]),
                              limits=c(plotinfo$T_min[i],plotinfo$T_max[i]))
  p <- p + scale_y_continuous(breaks=seq(0,100,by=10),limits=c(0,100))
  p <- p + labs(x="Mean temperature difference (K)",y="Suitability (%)")
  p <- p + theme(panel.background=element_rect(fill="white",colour="black"),
                 axis.ticks=element_line(colour="black"),axis.text=element_text(size=12,colour="black"),
                 axis.title=element_text(size=13,face="bold"))
  
  pdf(paste(scaleplotDir,"/",resol,"_S",i,"_tmean_010.pdf",sep=""),width=10,height=7)
  print(p)
  dev.off()
}


