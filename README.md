# s-latissima-organelles

# Organelle genome assembly of the brown macroalga *Saccharina latissima* (North American sugar kelp)
Scripts to score and compare the organelle genome assemblies (chloroplast and mitochondrion) of *S. latissima* to previous assemblies.

## 1. Assembly
### Subset reads that BLAST to organelle genomes
### Flye assembler

## 2. MUMmer assembly alignment
### Run MUMmer and generate dotplots to show sequence similarity and inversions
Fetch assemblies and annotations from [JGI PhycoCosm](https://phycocosm.jgi.doe.gov/phycocosm/home) and [ORCAE](https://bioinformatics.psb.ugent.be/orcae) given a list of JGI portal names and ORCAE links.
##### Usage
> sbatch mummer.sbatch \<ref.fasta\> \<query.fasta\>
##### Examples
```
sbatch s-latissima-organelles/mummer.sbatch NC_026108.1_sugar_kelp_mito.fasta putative_sugar_kelp_mito_flye_444.fasta
sbatch s-latissima-organelles/mummer.sbatch MT151382.1_Saccharina_latissima_strain_ye-c14_chloroplast_complete_genome.fasta putative_sugar_kelp_chloro.fasta
```

[alt text](mummer_dotplot_chloroplast.png)
[alt text](mummer_dotplot_mitochondrion.png)
