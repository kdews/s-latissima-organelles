#!/bin/bash
#SBATCH --mem=1g
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=5

prefix=$1 # sbatch filename without file extensions
indir=$2 # input directory
outdir=$3 # output directory
genome=$4
genome_basename=$(basename -- $genome)
genome_base=`echo $genome_basename | sed 's/\..*//g'`
indiv_file=$5
indiv_id=`cat $indiv_file | sed -n ${SLURM_ARRAY_TASK_ID}p`

# Load samtools
source ~/bin/anaconda3/etc/profile.d/conda.sh
conda activate samtools
samtools --version
if [[ $? -ne 0 ]]
then
	printf "Error - check samtools installation.\n"
	exit 1
fi

# samtools index bam
samtools index -@ ${SLURM_CPUS_PER_TASK} \
${indir}/${indiv_id}_${genome_base}.sorted.marked.merged.bam

# Checkpoint
if [[ $? -eq 0 ]]
then
	if [[ -f \
${indir}/${indiv_id}_${genome_base}.sorted.marked.merged.bam.bai ]]
	then
		if [[ ! -d checkpoints ]]
		then
			mkdir checkpoints
		fi
		touch \
checkpoints/${prefix}_${SLURM_ARRAY_TASK_ID}.checkpoint
		exit 0
	else
		printf "Error - merged BAM file \
${indir}/${indiv_id}_${genome_base}.sorted.marked.merged.bam \
not indexed.\n"
		exit 1
	fi
else
	printf "Error - non-zero exit code returned by samtools.\n"
	exit 1
fi

