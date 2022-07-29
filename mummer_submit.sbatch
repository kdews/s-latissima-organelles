#!/bin/bash
#SBATCH -J mummer
#SBATCH --mem=1g
#SBATCH --time=00:10:00
#SBATCH -o logs/%x_%j.log

ref=$1
query=$2
r_base=$(basename $ref | sed 's/\..*//g')
q_base=$(basename $query | sed 's/\..*//g')
base_mum=${r_base}_vs_${q_base}

source ~/bin/anaconda3/etc/profile.d/conda.sh
conda activate mummer
module load gcc gnuplot
mummer -mum -L -b -c $ref $query > ${base_mum}.mums
mummerplot --postscript --prefix=$base_mum ${base_mum}.mums
mkdir -p mummer_${base_mum}
mv ${base_mum}* mummer_${base_mum}

