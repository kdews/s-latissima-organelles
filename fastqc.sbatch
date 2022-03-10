#!/bin/bash
#SBATCH --mem=5gb
#SBATCH --time=08:00:00
#SBATCH --cpus-per-task=12

prefix=$1 # sbatch filename without file extensions
indir=$2 # input directory
outdir=$3 # output directory
samples_file=$4
sample_id=`cat $samples_file | sed -n ${SLURM_ARRAY_TASK_ID}p`
reads1=${samples_dir}/${sample_id}_R1.fastq.gz
reads2=${samples_dir}/${sample_id}_R2.fastq.gz

# Create output directory (if needed)
if [[ ! -d $outdir ]]
then
	printf "Creating output directory ${outdir}.\n\n"
	mkdir $outdir 
fi

# Load fastqc
source ~/bin/anaconda3/etc/profile.d/conda.sh
conda activate fastqc
fastqc --version
if [[ $? -ne 0 ]]
then
	printf "Error - check FASTQC installation.\n"
	exit 1
fi

printf "Running FASTQC on 2 read files associated \
with ${sample_id}: \n $reads1 and ${reads2}.\n\n"

fastqc -t $SLURM_CPUS_PER_TASK -o $outdir $reads1 $reads2


# Checkpoint
if [[ $? -eq 0 ]]
then
	if [[ -f ${outdir}/${sample_id}_R1_fastqc.zip ]] \
&& [[ -f ${outdir}/${sample_id}_R2_fastqc.zip ]] \
&& [[ -f ${outdir}/${sample_id}_R1_fastqc.html ]] \
&& [[ -f ${outdir}/${sample_id}_R2_fastqc.html ]]
	then
		if [[ ! -d checkpoints ]]
		then
			mkdir checkpoints
		fi
		touch \
checkpoints/${prefix}_${SLURM_ARRAY_TASK_ID}.checkpoint
		exit 0
	else
		printf "Error - not all FastQC files \
created for ${sample_id}.\n"
		exit 1
	fi
else
	printf "Error - non-zero exit code returned by FastQC.\n"
	exit 1
fi
