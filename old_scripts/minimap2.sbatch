#!/bin/bash
#SBATCH --mem=70g
#SBATCH --cpus-per-task=4
#SBATCH --time=07:00:00
#SBATCH -J minimap2
#SBATCH -o logs/%x_%j.log

ref="$1"
query="$2"
r_base="$(basename $ref | sed 's/\..*//g')"
q_base="$(basename $query | sed 's/\..*//g')"
base_name="${r_base}_vs_${q_base}"
thr="$((SLURM_CPUS_PER_TASK - 1))"

# Load conda environment
cond=~/.conda_for_sbatch.sh
[[ -a "$cond" ]] && source "$cond" || \
{ echo "Error on source of $cond"; exit 1; }
conda activate minimap2
# Verify program installation
minimap2 --version


cmd="minimap2 -t $thr -ax map-hifi $ref $query > ${base_name}.sam"
echo "$cmd"
$cmd
