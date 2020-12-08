# make sure you install markdown into your home directory
install.packages(c("formattable"))
install.packages(c("webshot"))
# set working directory to root so that you can access projects/b1134
setwd("/")
qcvals = read.csv("projects/b1134/processed/boldqc/SeqDev/sub-fMRIPILOT1110/ses-fMRIPILOT1110/task-REST04/sub-fMRIPILOT1110_ses-fMRIPILOT1110_task-REST04_acq-CBS2p4_bold_qcvals.csv", header = TRUE)
library("formattable", lib.loc="home/amh409/R/x86_64-pc-linux-gnu-library/4.0")
library("htmltools")
library("webshot", lib.loc="home/amh409/R/x86_64-pc-linux-gnu-library/4.0")
table <- formattable(qcvals, align=c("l","r","r","r","r","r","r","r", "r", "r", "r", "r", "r", "r", "r", "r"))
w <- as.htmlwidget(table, width = "100%", height = NULL)
path <
webshot(url,
        file = )