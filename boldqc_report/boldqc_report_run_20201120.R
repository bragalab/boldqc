##### MR QC REPORT SCRIPT #####

#### CREATED BY ANIA HOLUBECKI ON NOVEMBER 18th, 2020 ####

### USE: GENERATE QC PDF FOR SINGLE MR RUN ###

# USE WITH R/3.6.0 FOR ALL PACKAGES TO WORK #

### SET UP ###

# LOAD REQUIRED PACKAGES #

message("Loading required R packages")
if(!require(grDevices)) {install.packages(c("grDevices")); require(grDevices)}
#if(!require(car)) {install.packages(c("car")); require(car)}
if (!require(plyr)) {install.packages(c("plyr")); require(plyr)}
if (!require(lmPerm)) {install.packages(c("lmPerm")); require(lmPerm)}    
if (!require("coin")) {install.packages(c("coin")); require("coin")}  
if (!require("ggplot2")) {install.packages(c("ggplot2")); require("ggplot2")}  
if (!require("gridExtra")) {install.packages(c("gridExtra")); require("gridExtra")}  
if (!require("reshape2")) {install.packages(c("reshape2")); require("reshape2")}  
if (!require("plotrix")) {install.packages(c("plotrix")); require("plotrix")}  
if (!require("knitr")) {install.packages(c("knitr")); require("knitr")}  
if (!require("xtable")) {install.packages(c("xtable")); require("xtable")}  
if (!require("pander")) {install.packages(c("pander")); require("pander")}  
if (!require("stargazer")) {install.packages(c("stargazer")); require("stargazer")}  
if (!require("rhandsontable")) {install.packages(c("rhandsontable")); require("rhandsontable")}  
if (!require("gtable")) {install.packages(c("gtable")); require("gtable")}  
if (!require("grid")) {install.packages(c("grid")); require("grid")}  
if (!require("RGraphics")) {install.packages(c("RGraphics")); require("RGraphics")}  
if (!require("cowplot")) {install.packages(c("cowplot")); require("cowplot")}  
if (!require("stringi")) {install.packages(c("stringi")); require("stringi")}
if (!require("png")) {install.packages(c("png")); require("png")}
if (!require("BiocManager")) {install.packages(c("BiocManager")); require ("BiocManager")}
#if (!require("EBImage")) {install.packages(c("EBImage")); require ("EBImage")}
BiocManager::install(c("EBImage"))
library(EBImage)

message("Generating run QC report")
# SET UP VARIABLES #

args <-commandArgs(trailingOnly = TRUE)
str(args)
cat(args, sep = '\n')
PROJ <- args[1]
SUB <- args[2]
SESS <- args[3]
TASK <- args[4]
ACQ <- args[5]

### CREATE QC REPORT FOR RUN ###

# READ IN .CSV FILE #

wd_boldqc <-paste("/projects/b1134/processed/boldqc/", PROJ, "/sub-", SUB, "/ses-", SESS, "/", "task-", TASK, sep = "")
setwd(wd_boldqc)

FILENAME <-args[6]
rundatacsv <- paste(FILENAME, "_qcvals.csv", sep = "")
rundata <-read.csv(rundatacsv)
rundata$TR_s <- as.numeric(rundata$TR_s)
rundata$TE_ms <- as.numeric(rundata$TE_ms)
rundata$maxFD <- as.numeric(rundata$maxFD)
rundata$meanFD <- as.numeric(rundata$meanFD)
rundata$maxAbs <- as.numeric(rundata$maxAbs)
rundata$v_tSNR <- as.numeric(rundata$v_tSNR)
rundata$s_tSNR <- as.numeric(rundata$s_tSNR)
rundata$TR_s <- format(round(rundata$TR_s, digits = 1), nsmall = 1)
rundata$TE_ms <- format(round(rundata$TE_ms, digits = 1), nsmall = 1)
rundata$maxFD <- format(round(rundata$maxFD, digits = 3), nsmall = 3)
rundata$meanFD <- format(round(rundata$meanFD, digits = 3), nsmall = 3)
rundata$maxAbs <- format(round(rundata$maxAbs, digits = 3), nsmall = 3)
rundata$v_tSNR <- format(round(rundata$v_tSNR, digits = 1), nsmall = 1)
rundata$s_tSNR <- format(round(rundata$s_tSNR, digits = 1), nsmall = 1)

# READ IN SLICERS #
meanSLICER <- paste("sub-", SUB, "_ses-", SESS, "_task-", TASK, "_acq-", ACQ, "_bold_skip_mc_mean_sag.png", sep = "")
meanSLICERimg <- readImage(meanSLICER)
gMEAN <- rasterGrob(meanSLICERimg)
stdSLICER <- paste("sub-", SUB, "_ses-", SESS, "_task-", TASK, "_acq-", ACQ, "_bold_skip_mc_std_sag.png", sep = "")
stdSLICERimg <- readImage(stdSLICER)
gSTD <- rasterGrob(stdSLICERimg)
tsnrSLICER <- paste("sub-", SUB, "_ses-", SESS, "_task-", TASK, "_acq-", ACQ, "_bold_skip_mc_tsnr_sag.png", sep = "")
tsnrSLICERimg <- readImage(tsnrSLICER)
gtSNR <- rasterGrob(tsnrSLICERimg)

# READ IN MCFLIRT PLOTS #
rotPLOT <- paste("sub-", SUB, "_ses-", SESS, "_task-", TASK, "_acq-", ACQ, "_bold_skip_mc_rot.png", sep = "")
rotPLOTimg <- readImage(rotPLOT)
gROT <- rasterGrob(rotPLOTimg)
transPLOT <- paste("sub-", SUB, "_ses-", SESS, "_task-", TASK, "_acq-", ACQ, "_bold_skip_mc_trans.png", sep = "")
transPLOTimg <- readImage(transPLOT)
gTRANS <- rasterGrob(transPLOTimg)
absdispPLOT <- paste("sub-", SUB, "_ses-", SESS, "_task-", TASK, "_acq-", ACQ, "_bold_skip_mc_disp_abs.png", sep = "")
absdispPLOTimg <- readImage(absdispPLOT)
gABSDISP <- rasterGrob(absdispPLOTimg)
reldispPLOT <- paste("sub-", SUB, "_ses-", SESS, "_task-", TASK, "_acq-", ACQ, "_bold_skip_mc_disp_rel.png", sep = "")
reldispPLOTimg <- readImage(reldispPLOT)
gRELDISP <- rasterGrob(reldispPLOTimg)

# TURN DATA FRAMES INTO TABLE GROBS THAT CAN BE ARRANGED ON SINGLE PAGE

tt2 <- ttheme_minimal(base_size = 9)

#gPARAMS
gPARAMS <- tableGrob(rundata[1,1:8], rows = NULL, theme = tt2)

#titlegPARAMS <-textGrob("Acquisition Parameters",gp=gpar(fontsize=12))
gPARAMS <- gtable_add_grob(gPARAMS, grobs=rectGrob(gp=gpar(fill=NA, lwd = 1)), t = 2, b = nrow(gPARAMS), l = 1, r = ncol(gPARAMS))
#grid.draw(gPARAMS)

#gDERIVED
gDERIVED <- tableGrob(rundata[1,9:16], rows = NULL, theme = tt2)
gDERIVED <- gtable_add_grob(gDERIVED, grobs=rectGrob(gp=gpar(fill=NA, lwd = 1)), t = 2, b = nrow(gDERIVED), l = 1, r = ncol(gDERIVED))
#grid.draw(gPARAMS)

# SET UP ADDITIONAL TEXT FOR PDF
headPROJ <- paste('Project: ', PROJ, sep = "")
headSUB <- paste('Subject ID: ', SUB, sep = "")
headSESS <- paste('Session ID: ', SESS, sep = "")
gTITLE <- textGrob(paste("QC REPORT", headSUB, headSESS, "", sep = '\n'), x = 0.0, just = "left", gp=gpar(fontsize=10))
gSLEEP <- textGrob(paste(" ", headPROJ, "Sleep Score:", "",  sep = '\n'), x = 0.05, just = "left", gp=gpar(fontsize=10))
### MAKE PDF OF QC REPORT ###

blank <- grid.rect(gp=gpar(fill="white", lwd = 0, col = "white"))

pdf(paste(FILENAME, "_qcreport.pdf", sep = ""), height = 8.5, width = 11, onefile = T)

QC.items <- grid.arrange(arrangeGrob(blank, ncol = 1),
                         arrangeGrob(blank, arrangeGrob(gTITLE, gSLEEP, ncol = 2, widths = c(0.5, 0.5)), gPARAMS, gDERIVED, blank, gROT, gTRANS, gABSDISP, gRELDISP, blank, ncol = 1, heights = c(0.6, 0.6, 0.75, 0.75, 0.1, 1.35, 1.35, 1.35, 1.35, 0.25)),
                         arrangeGrob(blank, gMEAN, blank, gSTD, blank, gtSNR, blank, ncol = 1, heights = c(0.50, 2.5, 0.10, 2.5, 0.10, 2.5, 0.30)),
                         arrangeGrob(blank, ncol = 1),
                         nrow = 1, heights=c(7), ncol = 4, widths = c(0.33, 5.17, 5.17, 0.33))
dev.off()

