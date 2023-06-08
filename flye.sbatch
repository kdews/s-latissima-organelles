#!/bin/bash
#SBATCH --mem=50gb
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=8
#SBATCH -J flye
#SBATCH -o logs/%x_%j.log

# Define variables
fastq="chloro_blast_PBproductionSequel781_2_B01_PBXF_30hours\
_29kbV2PDCLRrunningCCS_70pM.fastq"
outdir="flye_chloro_PBproductionSequel781_2_B01_PBXF_30hours\
_29kbV2PDCLRrunningCCS_70pM"
thr="$SLURM_CPUS_PER_TASK"
g_size=130000

# Create output directory (if needed)
mkdir -p $outdir

# Load conda environment
cond=~/.conda_for_sbatch.sh
[[ -a "$cond" ]] && source "$cond" || \
{ echo "Error on source of $cond"; exit 1; }
conda activate flye
# Verify program installation
flye --version

# Run canu
cmd="flye --pacbio-corr $fastq -d $outdir --genome-size $g_size --threads $thr"
echo "Running flye on $fastq"
echo "$cmd"
$cmd

# Checkpoint
if [[ $? -ne 0 ]]
then
	echo "Error - non-zero exit code returned by flye on $fastq"
	exit 1
fi
