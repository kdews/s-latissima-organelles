#!/bin/bash
#SBATCH --mem=15gb
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=12
#SBATCH --job-name=pacbio_fastqc
#SBATCH --output=logs/%x_%a.log

# Define variables
indir=ccs # input directory
outdir=fastqc # output directory
samples_file=ccs_samples.txt # file containing sample names
sample=${indir}/$(cat $samples_file | sed -n "${SLURM_ARRAY_TASK_ID}"p)

# Create output directory (if needed)
mkdir -p $outdir

# Load fastqc
source ~/bin/anaconda3/etc/profile.d/conda.sh
conda activate fastqc
fastqc --version
if [[ $? -ne 0 ]]
then
	echo "Error - check FASTQC installation."
	exit 1
fi

# Run FASTQC
echo "Running FASTQC on $sample"
fastqc -t "$SLURM_CPUS_PER_TASK" -o $outdir "$sample"

# Checkpoint
if [[ $? -ne 0 ]]
then
	echo "Error - non-zero exit code returned by FastQC run on $sample"
	exit 1
fi
