#Julian Ramirez-Villegas
#UoL / CCAFS / CIAT
#Aug 2013
stop("!")

#load packages
library(rgdal); library(raster); library(maptools); library(rasterVis); data(wrld_simpl)

#source functions
src.dir <- "~/Repositories/dapa-climate-change/trunk/scaling-effect"
src.dir2 <- "~/Repositories/dapa-climate-change/trunk/PhD/0006-weather-data"
source(paste(src.dir,"/scripts/EcoCrop-model.R",sep=""))
source(paste(src.dir2,"/scripts/GHCND-GSOD-functions.R",sep=""))

#i/o directories and details
bDir <- "~/Leeds-work/scaling-effect"
clmDir <- paste(bDir,"/climate_data",sep="")
runDir <- paste(bDir,"/model-runs",sep="")
lsmDir <- paste(bDir,"/lsm",sep="")

#figure dir is local (on mbp)
figDir <- paste(bDir,"/paper_figures_v2",sep="")

#get mask from CASCADE output
msk <- raster(paste(lsmDir,"/Glam_12km_lsm.nc",sep=""))
msk[which(msk[] < 0)] <- NA
msk[which(msk[] > 0)] <- 1 #1:length(which(msk[] > 0))

text <- extent(msk); text@ymax <- 20

#maize points
m1 <- extent(1.5,4.5,6,9)
m2 <- extent(4.5,7.5,6,9)

#groundnut points
g1 <- extent(-16.5,-13.5,12,15)
g2 <- extent(7.5,10.5,12,15)


####
#### plotting functions
#functions to make plot
rs_levplot2 <- function(rsin,zn,zx,nb,brks=NA,scale="YlOrRd",ncol=9,col_i="#CCECE6",col_f="#00441B",rev=F,leg=T) {
  if (scale %in% row.names(brewer.pal.info)) {
    pal <- rev(brewer.pal(ncol, scale))
  } else {
    pal <- colorRampPalette(c(col_i,col_f))(ncol)
  }
  if (rev) {pal <- rev(pal)}
  
  if (is.na(brks[1])) {brks <- do.breaks(c(zn,zx),nb)}
  
  #set theme
  this_theme <- custom.theme(fill = pal,region = pal,
                             bg = "white", fg = "grey20", pch = 20)
  
  p <- rasterVis:::levelplot(rsin, margin=F, par.settings = this_theme, colorkey=leg,
                             at = brks, maxpixels=ncell(rsin)) + 
    layer(sp.lines(grat,lwd=0.5,lty=2,col="grey 50")) +
    layer(sp.polygons(wrld_simpl,lwd=0.8,col="black"))
  return(p)
}


rs_print <- function(p,pdfName) {
  pdf(pdfName,height=ht,width=wt,pointsize=14)
  print(p)
  dev.off()
}

#figure details
ht <- 6
rs <- msk
fct <- (rs@extent@xmin-rs@extent@xmax)/(rs@extent@ymin-rs@extent@ymax)
wt <- ht*(fct+.1)
grat <- gridlines(wrld_simpl, easts=seq(-180,180,by=5), norths=seq(-90,90,by=5))


###
resol <- "12km_exp"
trunDir <- paste(clmDir,"/cascade_",resol,sep="")
gsrain <- stack(paste(trunDir,"/prec_",6:10,".tif",sep=""))
rsx <- calc(gsrain,fun=function(x) {sum(x,na.rm=T)})
rsx <- resample(rsx, msk)
rsx[which(is.na(msk[]))] <- NA

rsx[which(rsx[] > 2500)] <- 2600
rbrks <- c(seq(0,2500,by=250),2600)
rsx <- crop(rsx, text)
minval <- 0; maxval <- 2600

pdf(paste(figDir,"/SI-Fig01b_precipitation.pdf",sep=""), height=4,width=6,pointsize=16,family="Helvetica")
tplot <- rs_levplot2(rsx,minval,maxval,nb=length(rbrks),brks=rbrks,scale=NA,
                     col_i="#DEEBF7",col_f="#08306B",ncol=9,rev=F,leg=T)
tplot <- tplot + layer(sp.polygons(as(m1,'SpatialPolygons'),lwd=1.25,col="blue"))
tplot <- tplot + layer(panel.text((m1@xmin+m1@xmax)*.5, (m1@ymin+m1@ymax)*.5, "M",cex=1.5))
tplot <- tplot + layer(sp.polygons(as(g2,'SpatialPolygons'),lwd=1.25,col="blue"))
tplot <- tplot + layer(panel.text((g2@xmin+g2@xmax)*.5, (g2@ymin+g2@ymax)*.5, "G",cex=1.5))
print(tplot)
dev.off()


#plot temperature data
gstemp <- stack(paste(trunDir,"/tmean_",6:10,".tif",sep=""))
rsx <- calc(gstemp,fun=function(x) {mean(x,na.rm=T)})
rsx <- rsx*0.1
minval <- min(gstemp[],na.rm=T)
maxval <- max(gstemp[],na.rm=T)

rsx <- resample(rsx, msk)
rsx[which(is.na(msk[]))] <- NA
rsx <- crop(rsx, text)
tbrks <- seq(10,45,by=2.5)

pdf(paste(figDir,"/SI-Fig01a_temperature.pdf",sep=""), height=4,width=6,pointsize=12,family="Helvetica")
tplot <- rs_levplot2(rsx,minval,maxval,nb=length(tbrks),brks=tbrks,scale="YlOrRd",ncol=9,rev=T,leg=T)
tplot <- tplot + layer(sp.polygons(as(m1,'SpatialPolygons'),lwd=1.25,col="blue"))
tplot <- tplot + layer(panel.text((m1@xmin+m1@xmax)*.5, (m1@ymin+m1@ymax)*.5, "M",cex=1.5))
tplot <- tplot + layer(sp.polygons(as(g2,'SpatialPolygons'),lwd=1.25,col="blue"))
tplot <- tplot + layer(panel.text((g2@xmin+g2@xmax)*.5, (g2@ymin+g2@ymax)*.5, "G",cex=1.5))
print(tplot)
dev.off()


