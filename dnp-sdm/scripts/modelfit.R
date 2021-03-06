#JRV May 2013
#process Andean occurrence data
stop("dont run")

##############################
#Procedure to follow
##############################
#
#1. species name
#2. load species data
#3. load background data.frame (create from shapefile if doesn't exist)
#4. using seed select training species data AND training pseudo absences
#   number of PA = a given number (100, 250, 500, 1000, 2500, 5000, 7500, 10000)
#5. select particular combination of variables
#   a. subset climate
#   b. subset climate + soils
#   c. subset climate + topography
#   d. subset climate + soils + topography
#   e. full climate
#   f. full climate + soils
#   g. full climate + topography
#   h. full climate + soils + topography

#loop cross-val 1:10 (with specified seed)
#5. run without cross-validation (but do the cross validation independently so as
#   to be able to use Hijmans 2012 Ecology ssb AUC correction)
#6. run a particular algorithm, evaluate, store eval output
#   configuration in Maxent: probably 10k PA)
#end loop cross-val

##############################
##############################

#load relevant package(s)
library(biomod2); library(raster); library(rgdal); library(maptools); library(dismo)

#base dir
bDir <- "/nfs/a102/eejarv/DNP-biodiversity"
#bDir <- "/mnt/a102/eejarv/DNP-biodiversity"
setwd(bDir)

#source functions
src.dir <- "~/PhD-work/_tools/dapa-climate-change/trunk/dnp-sdm"
#src.dir <- "~/Repositories/dapa-climate-change/trunk/dnp-sdm"
source(paste(src.dir,"/scripts/modelfit-fun.R",sep=""))

#lists of variables
varList <- data.frame(SET_ID=1:8,CLIM=c(rep("full",times=4),rep("subset",times=4)),
                      SOIL=c(F,T,F,T,F,T,F,T),TOPO=c(F,F,T,T,F,F,T,T))

#seeds to draw presences and pseudo absences (bootstraps)
seedList <- c(3379, 5728, 3781, 3590, 3266, 9121, 3441, 11667, 4484, 9559)

#list of number of PA selections
npaList <- c(3829, 1922, 1945, 5484, 2125, 8746, 2187, 1521, 9623, 1561)

#list of models
modList <- c('GLM','GAM','GBM','RF','ANN','MAXENT')

#experimental matrix
all_runs <- expand.grid(ALG=modList,NPA=npaList,VSET=varList$SET_ID,SEED=seedList)
null_runs <- expand.grid(ALG=modList,NPA=npaList,SEED=seedList)

#species name and configuration of run

this_sppName <- "Mint_moll" #species name

##### above this load for all


# #### the below loop is not needed once the null models are done
# #null model fits
# for (run_i in 1:nrow(null_runs)) {
#   #run_i <- 1 #23
#   this_seed <- as.numeric(paste(null_runs$SEED[run_i])) #seed for the cross validation
#   this_alg <- paste(null_runs$ALG[run_i]) #modelling algorithm
#   this_npa <- as.numeric(paste(null_runs$NPA[run_i])) #number of pseudo absences (from list)
#   odir <- run_null_model(bDir,sppName=this_sppName,alg=this_alg,seed=this_seed,npa=this_npa)
# }
# #### only for null models



####################################################################################################
####################################################################################################
### after this point you need to change both Species and Model

#### from here for actual fits
mod <- "GBM" #change!
truns <- which(all_runs$ALG == mod)

#actual model runs
for (run_i in truns) {
  #run_i <- 1 #23
  this_seed <- as.numeric(paste(all_runs$SEED[run_i])) #seed for the cross validation
  this_npa <- as.numeric(paste(all_runs$NPA[run_i])) #number of pseudo absences (from list)
  this_alg <- paste(all_runs$ALG[run_i]) #modelling algorithm
  this_vset <- as.numeric(paste(all_runs$VSET[run_i])) #set of variables to use
  odir <- run_model(bDir,sppName=this_sppName,seed=this_seed,npa=this_npa,alg=this_alg,vset=this_vset)
}

#changes introduced:
#------------------
#threshold in pwdSampling() to .33 #from Hijmans 2012 Ecology #done
#sp_mOpt@GLM$control$maxit <- 100 #because sometimes it shows warning of not-convergence #done
#sp_mOpt@GBM$n.trees <- 2000 #Braunisch et al. 2013 #done
#70/30 instead of 75/25 for training/testing #done
#background size of 14285 so that training background is 10000 (Maxent's default) #done
#------------------

#########################################################################
#########################################################################
#########################################################################
# #get some metrics
# out_runs <- all_runs[1:100,]
# out_metr <- data.frame()
# for (run_i in 1:100) {
#   #run_i <- 1
#   cat("run:",run_i,"\n")
#   this_seed <- as.numeric(paste(all_runs$SEED[run_i])) #seed for the cross validation
#   this_npa <- as.numeric(paste(all_runs$NPA[run_i])) #number of pseudo absences (from list)
#   this_alg <- paste(all_runs$ALG[run_i]) #modelling algorithm
#   this_vset <- as.numeric(paste(all_runs$VSET[run_i])) #set of variables to use
#   
#   modDir <- paste(bDir,"/models",sep="")
#   outDir <- paste(modDir,"/",this_alg,"/PA-",this_npa,"_SD-",this_seed,"_VARSET-",this_vset,sep="")
#   load(file=paste(outDir,"/",gsub("\\_","\\.",this_sppName),"/fitting.RData",sep=""))
#   out_metr <- rbind(out_metr,cbind(RUN=run_i,sp_mEval))
#   rm(sp_mEval); rm(sp_bData); rm(sp_mOut); g=gc(); rm(g)
# }
# 
# out_runs <- cbind(RUN=1:100,out_runs)
# out_runs <- merge(out_runs,out_metr,by="RUN")
# write.csv(out_runs,paste(modDir,"/eval_1_100.csv",sep=""),quote=T,row.names=F)
# 
# #plot the auc
# cols <- c("red","blue","black","orange","green")
# for (i in 1:length(modList)) {
#   tmod <- modList[i]
#   tplot <- out_runs[which(out_runs$ALG == tmod),]
#   if (i == 1) {
#     png(paste(modDir,"/eval_1_100.png",sep=""),width=1500,height=1500,
#         units="px",res=300,pointsize=10)
#     par(mar=c(5,5,1,1))
#     plot(tplot$AUC_TST,tplot$AUC_SSB,xlim=c(0.5,1),ylim=c(0.5,1),col=cols[i],pch=20,cex=1,
#          xlab="AUC (test)",ylab="AUC (bias corrected)")
#   } else {
#     points(tplot$AUC_TST,tplot$AUC_SSB,col=cols[i],pch=20,cex=1)
#   }
# }
# grid()
# legend(x=0.5,y=1,legend=modList,col=cols,cex=1,pch=20)
# dev.off()



