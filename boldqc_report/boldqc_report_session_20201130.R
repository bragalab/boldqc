##### MR QC REPORT SCRIPT #####

#### CREATED BY ANIA HOLUBECKI ON NOVEMBER 30th, 2020 ####

### USE: GENERATE QC PDF FOR SINGLE MR SESSION ###

# USE WITH R/3.6.0 FOR ALL PACKAGES TO WORK #

### SET UP ### 

# LOAD REQUIRED PACKAGES #

message("Loading required R packages")
if(!require(grDevices)) {install.packages(c("grDevices")); require(grDevices)}
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

sessdatacsv <- paste("sub-", SUB, "_ses-", SESS, "_qcvals.csv", sep = "")
sessdata <-read.csv(sessdatacsv)
sessdata$TR_s <- as.numeric(sessdata$TR_s)
sessdata$TE_ms <- as.numeric(sessdata$TE_ms)
sessdata$maxFD <- as.numeric(sessdata$maxFD)
sessdata$meanFD <- as.numeric(sessdata$meanFD)
sessdata$maxAbs <- as.numeric(sessdata$maxAbs)
sessdata$v_tSNR <- as.numeric(sessdata$v_tSNR)
sessdata$s_tSNR <- as.numeric(sessdata$s_tSNR)

# CREATE QC GRAPHS

gMAX <- ggplot(sessdata, aes(Task, maxFD)) + geom_col(fill = "gray", color = "gray") +
  theme(panel.border = element_blank(), panel.grid.major = element_blank(), panel.grid.minor = element_blank(), axis.line = element_line(colour = "black"), panel.background = element_rect(fill = "white")) +
  ggtitle("Max FD") + labs(y = "mm") + scale_y_continuous(limits = c(0,1), expand = c(0,0), labels = scales::number_format(accuracy = 0.001)) + geom_hline(yintercept = 0.6, color = "red", linetype = "dashed") +
  theme(plot.title = element_text(hjust = 0.5))
gMEAN <- ggplot(sessdata, aes(Task, meanFD)) + geom_col(fill = "gray", color = "gray") +
  theme(panel.border = element_blank(), panel.grid.major = element_blank(), panel.grid.minor = element_blank(), axis.line = element_line(colour = "black"), panel.background = element_rect(fill = "white")) +
  ggtitle("Mean FD") + labs(y = "mm") + scale_y_continuous(limits = c(0,1), expand = c(0,0), labels = scales::number_format(accuracy = 0.001)) + geom_hline(yintercept = 0.15, color = "red", linetype = "dashed") +
  theme(plot.title = element_text(hjust = 0.5))
gABS <- ggplot(sessdata, aes(Task, maxAbs)) + geom_col(fill = "gray", color = "gray") +
  theme(panel.border = element_blank(), panel.grid.major = element_blank(), panel.grid.minor = element_blank(), axis.line = element_line(colour = "black"), panel.background = element_rect(fill = "white")) +
  ggtitle("Max Absolute Motion") + labs(y = "mm") + scale_y_continuous(limits = c(0,3), expand = c(0,0), labels = scales::number_format(accuracy = 0.001)) + geom_hline(yintercept = 2.0, color = "red", linetype = "dashed") +
  theme(plot.title = element_text(hjust = 0.5))
gstSNR <- ggplot(sessdata, aes(Task, s_tSNR)) + geom_col(fill = "gray", color = "gray") +
  theme(panel.border = element_blank(), panel.grid.major = element_blank(), panel.grid.minor = element_blank(), axis.line = element_line(colour = "black"), panel.background = element_rect(fill = "white")) +
  ggtitle("Slice tSNR") + labs(y = "") + scale_y_continuous(limits = c(0,100), expand = c(0,0), labels = scales::number_format(accuracy = 0.1)) + geom_hline(yintercept = 20, color = "red", linetype = "dashed") +
  theme(plot.title = element_text(hjust = 0.5))

# ROUND NUMBERS PROPERLY FOR TABLE

sessdata$TR_s <- format(round(sessdata$TR_s, digits = 1), nsmall = 1)
sessdata$TE_ms <- format(round(sessdata$TE_ms, digits = 1), nsmall = 1)
sessdata$maxFD <- format(round(sessdata$maxFD, digits = 3), nsmall = 3)
sessdata$meanFD <- format(round(sessdata$meanFD, digits = 3), nsmall = 3)
sessdata$maxAbs <- format(round(sessdata$maxAbs, digits = 3), nsmall = 3)
sessdata$v_tSNR <- format(round(sessdata$v_tSNR, digits = 1), nsmall = 1)
sessdata$s_tSNR <- format(round(sessdata$s_tSNR, digits = 1), nsmall = 1)

# TURN DATA FRAMES INTO TABLE GROBS THAT CAN BE ARRANGED ON SINGLE PAGE

tt2 <- ttheme_minimal(base_size = 9)

gTABLE <- tableGrob(sessdata[,1:16], rows = NULL, theme = tt2)
gTABLE <- gtable_add_grob(gTABLE, grobs=rectGrob(gp=gpar(fill=NA, lwd = 1)), t = 2, b = nrow(gTABLE), l = 1, r = ncol(gTABLE))
gTABLE <- gtable_add_grob(gTABLE, grobs=rectGrob(gp=gpar(fill=NA, lwd = 1)), t = 2, b = nrow(gTABLE), l = 9, r = 12)
#grid.draw(gTABLE)

# SET UP ADDITIONAL TEXT FOR PDF
headPROJ <- paste('Project: ', PROJ, sep = "")
headSUB <- paste('Subject ID: ', SUB, sep = "")
headSESS <- paste('Session ID: ', SESS, sep = "")
gTITLE <- textGrob(paste("QC REPORT", headSUB, headSESS, "", sep = '\n'), x = 0.0, just = "left", gp=gpar(fontsize=10))
gPROJ <- textGrob(paste(" ", headPROJ, "", "",  sep = '\n'), x = 0.05, just = "left", gp=gpar(fontsize=10))

### MAKE PDF OF QC REPORT ###

blank <- grid.rect(gp=gpar(fill="white", lwd = 0, col = "white"))

pdf(paste("sub-", SUB, "_ses-", SESS, "_qcreport.pdf", sep = ""), height = 8.5, width = 11, onefile = T)

QC.items <- grid.arrange(arrangeGrob(blank, ncol = 1),
                         arrangeGrob(blank, 
                                     arrangeGrob(gTITLE, gPROJ, blank, ncol = 3, widths = c(0.25, 0.25, 0.5)), 
                                     gTABLE, 
                                     blank, 
                                     arrangeGrob(gMAX, gMEAN, gABS, gstSNR, ncol = 2, nrow = 2, widths = c(0.5, 0.5), heights = c(0.5, 0.5)), 
                                     blank, 
                                     ncol = 1, heights = c(0.6, 0.55, 2, 0.1, 5.0, 0.25)),
                         arrangeGrob(blank, ncol = 1),
                         nrow = 1, ncol = 3, widths = c(0.70, 9.6, 0.70))
dev.off()
