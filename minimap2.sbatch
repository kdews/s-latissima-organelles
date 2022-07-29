#!/bin/bash
#SBATCH -J minimap2
#SBATCH --mem=70g
#SBATCH -c 4
#SBATCH --time=07:00:00
#SBATCH -o logs/%x_%j.log

ref=$1
query=$2
r_base=$(basename $ref | sed 's/\..*//g')
q_base=$(basename $query | sed 's/\..*//g')
base_name=${r_base}_vs_${q_base}

source ~/bin/anaconda3/etc/profile.d/conda.sh
conda activate minimap2
minimap2 -t 3 -ax map-hifi $ref $query > ${base_name}.sam

