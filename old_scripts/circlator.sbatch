#!/bin/bash
#SBATCH --mem=50gb
#SBATCH --time=12:00:00
#SBATCH --job-name=circlator
#SBATCH --output=logs/%x.log
#SBATCH -c 12

# Define variables
fastq=chloro_blast_PBproductionSequel781_1_A01_PBXF_30hours\
_29kbV2PDCLRrunningCCS_70pM.fastq
assembly=chloro_PBproductionSequel781_1_A01_PBXF_30hours\
_29kbV2PDCLRrunningCCS_70pM.tig00000001.fasta
outdir=circlator_chloro # output directory

# Load conda env
source ~/bin/anaconda3/etc/profile.d/conda.sh
conda activate circlator
circlator progcheck
if [[ $? -ne 0 ]]
then
	echo "Error - check circlator installation."
	exit 1
fi

# Run circlator
echo "Circularizing $assembly using reads: $fastq"
circlator all --verbose --threads 12 --data_type pacbio-corrected \
$assembly $fastq $outdir

# Checkpoint
if [[ $? -ne 0 ]]
then
	echo "Error - non-zero exit code returned by circlator run on $assembly"
	exit 1
fi
