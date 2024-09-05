#!/bin/bash
#SBATCH -p oneweek
#SBATCH -J getorg
#SBATCH --mem=250g
#SBATCH -c 4
#SBATCH --time=5-0
#SBATCH -o logs/%x_%j.log

reads=$1
r_base=$(basename $reads | sed 's/\..*//g')

# Load GetOrganelle
source ~/bin/anaconda3/etc/profile.d/conda.sh
conda activate getorg
get_organelle_from_reads.py --verbose -t 4 -o getorg_${r_base} -F embplant_pt \
-u $reads --fast

