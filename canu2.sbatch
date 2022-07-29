#!/bin/bash
#SBATCH --mem=50gb
#SBATCH --time=12:00:00
#SBATCH --job-name=canu
#SBATCH --output=logs/%x_%j.log

# Define variables
fastq=chloro_blast_PBproductionSequel781_2_B01_PBXF_30hours\
_29kbV2PDCLRrunningCCS_70pM.fastq
prefix=chloro_PBproductionSequel781_2_B01_PBXF_30hours\
_29kbV2PDCLRrunningCCS_70pM
outdir=canu_chloro_PBproductionSequel781_2_B01_PBXF_30hours\
_29kbV2PDCLRrunningCCS_70pM # output directory

# Create output directory (if needed)
mkdir -p $outdir

# Load dependencies and check canu install
module load openjdk gnuplot
canu --version
if [[ $? -ne 0 ]]
then
	echo "Error - check canu installation."
	exit 1
fi

# Run canu
echo "Running canu on $fastq"
canu -p $prefix -d $outdir -pacbio-hifi genomeSize=130000 $fastq

# Checkpoint
if [[ $? -ne 0 ]]
then
	echo "Error - non-zero exit code returned by canu run on $fastq"
	exit 1
fi
