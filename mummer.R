## Initialization
rm(list = ls())
# Load required packages
suppressPackageStartupMessages(library(tidyverse, quietly = T))
if (require(showtext, quietly = T)) {
  showtext_auto()
  if (interactive())
    showtext_opts(dpi = 100)
  else
    showtext_opts(dpi = 300)
}

## Input
if (interactive()) {
  setwd("/project/noujdine_61/kdeweese/latissima/organelles")
  mums_file <-
    "MT151382.1_Saccharina_latissima_strain_ye-c14_chloroplast_complete_genome_vs_putative_sugar_kelp_chloro_revcomp_shift_94650.mums"
  outdir <- "/home1/kdeweese/scripts/s-latissima-organelles/"
} else if (length(commandArgs(trailingOnly = T)) == 2) {
  line_args <- commandArgs(trailingOnly = T)
  mums_file <- line_args[1]
  outdir <- line_args[2]
} else {
  stop("2 positional arguments expected.")
}
organelles <- c("mitochondrion" = "mito", "chloroplast" = "chloro")
assembly_refs <- c("mitochondrion" = "2020", "chloroplast" = "2017")
mum_header <- c("Reference", "Our", "Length")

## Output
# Get organelle type and assembly names from MUMs filename
mums_file <- unlist(sapply(organelles, grep, mums_file, value = T))
mum_dotplot_file <-
  paste0("mummer_dotplot_", names(mums_file), ".tiff")
# Prepend output directory to plot filenames (if it exists)
if (dir.exists(outdir)) {
  mum_dotplot_file <- paste0(outdir, mum_dotplot_file)
}

## Analysis
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
# Save plot
print(paste("MUMmer dotplot saved to:", mum_dotplot_file))
ggsave(filename = mum_dotplot_file, plot = p, bg = "white")

