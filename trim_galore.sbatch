#!/bin/bash
#SBATCH --mem=8gb
#SBATCH --time=05:00:00
#SBATCH --cpus-per-task=15

prefix=$1 # sbatch filename without file extensions
indir=$2 # input directory
outdir=$3 # output directory
samples_file=$4
sample_id=`cat $samples_file | sed -n ${SLURM_ARRAY_TASK_ID}p`
samples_dir=$2
reads1=${samples_dir}/${sample_id}_R1.repaired.fastq.gz
reads2=${samples_dir}/${sample_id}_R2.repaired.fastq.gz
outdir=$3
trimmed_dir=$4

# Load trim_galore
source ~/bin/anaconda3/etc/profile.d/conda.sh
conda activate trimgalore
trim_galore --version
if [[ $? -ne 0 ]]
then
 	printf "Error - check Trim Galore! installation.\n"
fi

printf "Running Trim Galore! on 2 read files associated \
with ${sample_id}: \n\
$reads1 and ${reads2}.\n\n"

trim_galore --paired --phred33 --output_dir $outdir \
--length 36 --stringency 1 -e 0.1 -j 4 \
--fastqc_args "-t ${SLURM_CPUS_PER_TASK}" $reads1 $reads2

# Checkpoint
if [[ $? -eq 0 ]]
then
	if [[ ! -d $trimmed_dir ]]
	then
		mkdir $trimmed_dir
	fi
	if [[ `ls ${outdir}/${sample_id}*val* | wc -l` == 6 ]] && \
[[ -d $trimmed_dir ]]
	then
		printf "Trimming and FastQC run completed \
for ${sample_id}.\n"
		mv ${outdir}/${sample_id}*fq.gz $trimmed_dir
		if [[ ! -d checkpoints ]]
		then
			mkdir checkpoints
		fi
		touch \
checkpoints/${prefix}_${SLURM_ARRAY_TASK_ID}.checkpoint
		exit 0
	else
		printf "Error - not all reads trimmed \
for ${sample_id}.\n"
		exit 1
	fi
else
	printf "Error - non-zero exit code returned by Trim Galore!\n"
	exit 1
fi

