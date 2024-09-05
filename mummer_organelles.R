## Initialization
rm(list = ls())
# Load required packages
suppressPackageStartupMessages(library(tidyverse, quietly = T))
suppressPackageStartupMessages(library(ggpubr, quietly = T))
if (require(showtext, quietly = T)) {
  showtext_auto()
  if (interactive())
    showtext_opts(dpi = 100)
  else
    showtext_opts(dpi = 300)
}

## Input
arg_len <- 3
if (interactive()) {
  setwd("/project/noujdine_61/kdeweese/latissima/organelles")
  mums_file1 <-
    "MT151382.1_Saccharina_latissima_strain_ye-c14_chloroplast_complete_genome_vs_putative_sugar_kelp_chloro_revcomp_shift_94650.mums"
  mums_file2 <-
    "NC_026108.1_sugar_kelp_mito_vs_putative_sugar_kelp_mito_flye_444_revcomp_shift_27818.mums"
  outdir <- "/home1/kdeweese/scripts/s-latissima-organelles/"
} else if (length(commandArgs(trailingOnly = T)) == arg_len) {
  line_args <- commandArgs(trailingOnly = T)
  mums_file1 <- line_args[1]
  mums_file2 <- line_args[2]
  outdir <- line_args[3]
} else {
  stop(paste(arg_len, "positional arguments expected."))
}

## Output
mum_dotplot_file <- "FS7_mummer_organelles_dotplot.tiff"
# Prepend output directory to plot filenames (if it exists)
if (dir.exists(outdir)) {
  mum_dotplot_file <- paste0(outdir, mum_dotplot_file)
}

# Get organelle type and assembly names from MUMs filename
organelles <- c("mitochondrion" = "mito", "chloroplast" = "chloro")
assembly_refs <- c("mitochondrion" = "2020", "chloroplast" = "2017")
mum_header <- c("Reference", "Our", "Length")

## Functions
# Plot dotplot from MUMmer file
plotMums <- function(mums_file) {
  mums_file <- unlist(sapply(organelles, grep, mums_file, value = T))
  # Convert all spacing to tabs for read.table
  # mums_raw <- gsub("[[:space:]]+", "\t", readLines(mums_file))
  mums_raw <- readLines(mums_file)
  # Find row where reverse (-) strand coordinates start
  rev_row <- grep("Reverse", mums_raw)
  # Shift to account for filtering out ">" lines
  shft <- length(grep(">", mums_raw))
  rev_row <- rev_row - shft
  mums <- read.table(
    text = mums_raw,
    header = F,
    fill = NA,
    comment.char = ">",
    col.names = mum_header
  )
  mums <- mums %>%
    mutate(
      Strand = if_else(row_number() <= rev_row, "+", "-"),
      Strand = factor(Strand, levels = c("+", "-")),
      Our_end = case_when(Strand == "-" ~ Our-Length,
                          .default = Our+Length)
    )
  x_lab <-
    paste("Reference",
          assembly_refs[names(mums_file)],
          names(mums_file),
          "assembly (kb)")
  y_lab <-
    paste(2024, names(mums_file), "assembly (kb)")
  p <- ggplot(mums,
              aes(
                x = Reference,
                xend = Reference + Length,
                y = Our,
                yend = Our_end,
                color = Strand
              )) +
    geom_segment(linewidth = 2, lineend = "round") +
    scale_x_continuous(labels = scales::label_number(scale = 1e-3),
                       n.breaks = 10, expand = c(0.01, 0)) +
    scale_y_continuous(labels = scales::label_number(scale = 1e-3),
                       n.breaks = 10, expand = c(0.01, 0)) +
    scale_color_discrete(type = c("+"="blue", "-"="orange")) +
    theme_bw() +
    theme(
      legend.position = "inside",
      legend.position.inside = c(0.9, 0.1),
      legend.text = element_text(size = rel(1.2)),
      legend.key = element_blank(),
      legend.background = element_rect(color = "grey")
    ) +
    xlab(x_lab) +
    ylab(y_lab) +
    coord_cartesian(clip = "off")
  return(p)
}

## Analysis
# Generate and combines plots
plist <- sapply(c(mums_file1, mums_file2), plotMums, simplify = F)
p2 <- ggarrange(plotlist = plist, labels = "AUTO")
# Save plots
print(paste("MUMmer dotplot saved to:", mum_dotplot_file))
ggsave(filename = mum_dotplot_file, plot = p2, bg = "white",
       width = 14, height = 7)

