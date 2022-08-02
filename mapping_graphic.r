# Script to make plots of two output files of "samtools depth" program

# Remove everything from memory
rm(list=ls())

# Set variables
args <- commandArgs(trailingOnly=TRUE)
depthfile1 <- args[1]
depthfile2 <- args[2]
plot_title <- args[3]
leg1 <- args[4]
leg2 <- args[5]
cov_thresh <- args[6]

# Load in depth data
depth1 <- read.table(depthfile1, sep="\t", header=FALSE, strip.white=TRUE)
depth2 <- read.table(depthfile2, sep="\t", header=FALSE, strip.white=TRUE)

# Calculate statistics of each assembly
depth1_mean <- mean(depth1[,3])
depth2_mean <- mean(depth2[,3])
depth1_stdv <- sqrt(var(depth1[,3]))
depth2_stdv <- sqrt(var(depth2[,3]))
depth_stats <- data.frame(mean_cov=c(depth1_mean, depth2_mean),
                          stdv=c(depth1_stdv, depth2_stdv))
write.table(format(depth_stats, digits=3), "depth_stats.txt", quote=F, row.names=F)

# Plot of coverage on both assemblies with set coverage threshold line
png("depth_plot.png", width = 900, height = 700)
plot(depth1[,2], depth1[,3], xlab="Postion (bp)", 
     ylab="Coverage", main=plot_title, 
     cex.main=2.5, cex.lab=1.5, cex.axis=1.5)
points(depth2[,2], depth2[,3], col="darkgrey")
abline(h=cov_thresh, col="red")
legend("top", legend=c(leg1, leg2, paste(cov_thresh, "reads")),
       col=c("black", "darkgrey", "red"), pch=c(15,15,NA), lty=c(0, 0, 1), 
       lwd=c(0, 0, 1), bg="skyblue", cex=1.7)
dev.off()
