#!/bin/bash
#SBATCH --mem=500mb
#SBATCH --time=01:00:00

prefix=$1 # sbatch filename without file extensions
indir=$2 # input directory
outdir=$3 # output directory
logdir=${prefix}_logs # log directory
samples_file=$4
sample_id=`cat $samples_file | sort -u | sed -n ${SLURM_ARRAY_TASK_ID}p`
reads1=${indir}/${sample_id}_R1.fastq.gz
reads2=${indir}/${sample_id}_R2.fastq.gz

# Load repair.sh (in BBMap package)
source ~/bin/anaconda3/etc/profile.d/conda.sh
conda activate bbmap
repair.sh --version
if [[ $? -ne 0 ]]
then
	echo "Error - check BBMap installation."
fi

printf "Repairing 2 read files associated with \
${sample_id}:\n${reads1} and \n${reads2}.\n\n"

# Parse input FASTQs for naming output
reads1_prefix=`echo $(basename -- $reads1) | sed "s/\..*//"`
reads1_suffix=`echo $(basename -- $reads1) | sed "s/$reads1_prefix//"`
reads2_prefix=`echo $(basename -- $reads2) | sed "s/\..*//"`
reads2_suffix=`echo $(basename -- $reads2) | sed "s/$reads2_prefix//"`

# Run BBMap repair.sh
repair.sh in=$reads1 in2=$reads2 \
out=${outdir}/${reads1_prefix}.repaired${reads1_suffix} \
out2=${outdir}/${reads2_prefix}.repaired${reads2_suffix} \
outs=${outdir}/${sample_id}.singles${reads1_suffix}

# Checkpoint
if [[ $? -eq 0 ]]
then
	if [[ `ls ${outdir}/${sample_id}*repaired* | wc -l` == 2 ]]
	then
		if [[ ! -d checkpoints ]]
		then
			mkdir checkpoints
		fi
		touch \
checkpoints/trim_galore_${SLURM_ARRAY_TASK_ID}.checkpoint
		exit 0
	else
		printf "Error - not all reads repaired \
for ${sample_id}.\n"
		exit 1
	fi
else
	printf "Error - non-zero exit code returned by repair.sh.\n"
	exit 1
fi

