##### MR QC REPORT SCRIPT #####

#### CREATED BY ANIA HOLUBECKI ON NOVEMBER 30th, 2020 ####

### USE: GENERATE QC PDF FOR SINGLE MR SESSION ###

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
if (!require("EBImage")) {install.packages(c("EBImage")); require("EBImage")}
if (!require("BiocManager")) {install.packages(c("BiocManager")); require ("BiocManager")}
BiocManager::install(c("EBImage"))
library(EBImage)

message("Generating session QC report")
# SET UP VARIABLES #

args <-commandArgs(trailingOnly = TRUE)
str(args)
cat(args, sep = '\n')
PROJ <- args[1]
SUB <- args[2]
SESS <- args[3]

### CREATE QC REPORT FOR RUN ###

# READ IN .CSV FILE #

wd_boldqc <-paste("/projects/b1134/processed/boldqc/", PROJ, "/sub-", SUB, "/ses-", SESS, sep = "")
setwd(wd_boldqc)

sessdatacsv <- paste("sub-", SUB, "_ses-", SESS, "_bold_qcvals.csv", sep = "")
sessdata <-read.csv(sessdatacsv)
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


# CREATE QC GRAPHS

max <- sessdata[, "maxFD"]
barplot(max, 
        main="Max FD",
        cex.main=1.5, 
        ylab="mm",
        ylim=c(0, 1),
        cex.lab=1.5, 
        col=rgb(0.2,0.4,0.6,0.6), 
        border="#FFFFFF"
)
abline(h=0.6, col = "Red", lwd=2.5)

mean <- sessdata[, "meanFD"]
barplot(mean, 
        main="Mean FD",
        cex.main=1.5,   
        ylab="mm", 
        ylim=c(0, 1),
        cex.lab=1.5, 
        width=c(100,100), 
        col=rgb(0.2,0.4,0.6,0.6), 
        border="#FFFFFF"
)
abline(h=0.15, col = "Red", lwd=2)

motion <- sessdata[, "maxAbs"]
barplot(motion, 
        main="Max Absolute Motion",
        cex.main=1.5,   
        ylab="mm", 
        ylim=c(0, 2),
        cex.lab=1.5, 
        width=c(100,100), 
        col=rgb(0.2,0.4,0.6,0.6), 
        border="#FFFFFF"
)
abline(h=2.00, col = "Red", lwd=2)

thresh <- sessdata[, "FD_0.2"]
barplot(thresh, 
        main="FD > 0.2",
        cex.main=1.5,  
        ylab="#", 
        ylim=c(0, 120),
        cex.lab=1.5, 
        width=c(100,100), 
        col=rgb(0.2,0.4,0.6,0.6), 
        border="#FFFFFF"
)
abline(h=100, col = "Red", lwd=2)

thresh <- sessdata[, "v_tSNR"]
barplot(thresh, 
        main="Voxel tSNR",
        cex.main=1.5,  
        ylab="#", 
        ylim=c(0, 100),
        cex.lab=1.5, 
        width=c(100,100), 
        col=rgb(0.2,0.4,0.6,0.6), 
        border="#FFFFFF"
)
abline(h=20, col = "Red", lwd=2)

# TURN DATA FRAMES INTO TABLE GROBS THAT CAN BE ARRANGED ON SINGLE PAGE

tt2 <- ttheme_minimal(base_size = 9)

#gPARAMS
gTABLE <- tableGrob(rundata[1,1:16], rows = NULL, theme = tt2)

#titlegPARAMS <-textGrob("Acquisition Parameters",gp=gpar(fontsize=12))
gTABLE <- gtable_add_grob(gTABLE, grobs=rectGrob(gp=gpar(fill=NA, lwd = 1)), t = 2, b = nrow(gTABLE), l = 1, r = ncol(gTABLE))
#grid.draw(gTABLE)

# SET UP ADDITIONAL TEXT FOR PDF
headPROJ <- paste('Project: ', PROJ, sep = "")
headSUB <- paste('Subject ID: ', SUB, sep = "")
headSESS <- paste('Session ID: ', SESS, sep = "")
gTITLE <- textGrob(paste("QC REPORT", headSUB, headSESS, "", sep = '\n'), x = 0.0, just = "left", gp=gpar(fontsize=10))
gPROJ <- textGrob(paste(" ", headPROJ, "",  sep = '\n'), x = 0.05, just = "left", gp=gpar(fontsize=10))
### MAKE PDF OF QC REPORT ###

blank <- grid.rect(gp=gpar(fill="white", lwd = 0, col = "white"))

pdf(paste(FILENAME, "_qcreport.pdf", sep = ""), height = 8.5, width = 11, onefile = T)

QC.items <- grid.arrange(arrangeGrob(blank, ncol = 1),
                         arrangeGrob(blank, arrangeGrob(gTITLE, gPROJ, ncol = 2, widths = c(0.5, 0.5)), gTABLE, blank, gGRAPHS, blank, ncol = 1, heights = c(0.6, 0.55, 3.5, 0.1, 3.5, 0.25)),
                         arrangeGrob(blank, ncol = 1),
                         nrow = 1, ncol = 3, widths = c(0.33, 10.34, 0.33))
dev.off()
