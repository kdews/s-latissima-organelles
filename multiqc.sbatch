#!/bin/bash
#SBATCH --mem=15gb
#SBATCH --time=12:00:00
#SBATCH --job-name=multiqc
#SBATCH --output=logs/%x.log

# Define variables
indir=fastqc # input directory
outdir=fastqc # output directory

# Create output directory (if needed)
mkdir -p $outdir

# Load fastqc
source ~/bin/anaconda3/etc/profile.d/conda.sh
conda activate multiqc
multiqc --version
if [[ $? -ne 0 ]]
then
	echo "Error - check MultiQC installation."
	exit 1
fi

# Run MultiQC
echo "Running MultiQC on $indir"
multiqc -o $outdir $indir

# Checkpoint
if [[ $? -ne 0 ]]
then
	echo "Error - non-zero exit code returned by MultiQC run on $indir"
	exit 1
fi
