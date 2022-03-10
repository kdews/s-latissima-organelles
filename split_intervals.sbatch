#!/bin/bash
#SBATCH --mem=1g
#SBATCH --time=01:00:00

prefix=$1 # sbatch filename without file extensions
indir=$2 # input directory
outdir=$3 # output directory
genome=$4
genome_basename=$(basename -- $genome)
genome_base=`echo $genome_basename | sed 's/\..*//g'`
genome_path=`dirname $genome`
scatter=$5

# Load GATK4
source ~/bin/anaconda3/etc/profile.d/conda.sh
conda activate gatk4
gatk --version
if [[ $? -ne 0 ]]
then
	echo "Error - check GATK4 installation."
	exit 1
fi

# Run GATK4's SplitIntervals
gatk SplitIntervals \
-R $genome --sequence-dictionary ${genome_path}/${genome_base}.dict \
-O $outdir --scatter-count $scatter \
--subdivision-mode BALANCING_WITHOUT_INTERVAL_SUBDIVISION

# Checkpoint
if [[ $? -eq 0 ]]
then
	if [[ -d $outdir ]]
	then
		total_chrs=`grep ">" $genome | sed 's/>//g'`
		num_total_chrs=`grep -c ">" $genome`
		num_split_chrs=$(for i in `echo $total_chrs`; \
do [[ `grep -v "@" ${outdir}/* | grep "$i"` ]] && echo $i; \
done | wc -l)
		if [[ $num_total_chrs -eq $num_split_chrs ]]
		then
			if [[ ! -d checkpoints ]]
			then
				mkdir checkpoints
			fi
			touch checkpoints/${prefix}.checkpoint
			exit 0
		fi
	else
		echo "Error - not all chromosomes found in split \
interval lists found in output directory ${outdir} after run."
		exit 1
	fi
else
	echo "Error - non-zero exit code returned by GATK4."
	exit 1
fi

