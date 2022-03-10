#!/bin/bash
#SBATCH --time=02:00:00
#SBATCH --mem=15gb

prefix=$1 # sbatch filename without file extensions
indir=$2 # input directory
outdir=$3 # output directory
genome=$4
genome_basename=$(basename -- $genome)
genome_base=`echo $genome_basename | sed 's/\..*//g'`
samples_file=$5
sample_id=`cat $samples_file | sed -n ${SLURM_ARRAY_TASK_ID}p`
qc_dir=$6

# Load GATK4
source ~/bin/anaconda3/etc/profile.d/conda.sh
conda activate gatk4
gatk --version
if [[ $? -ne 0 ]]
then
	echo "Error - check GATK4 installation."
	exit 1
fi

# Create output and QC directory (if needed)
if [[ ! -d $outdir ]]
then    
	mkdir $outdir
fi
if [[ ! -d $qc_dir ]]
then    
	mkdir $qc_dir
fi


# GATK4's MarkDuplicates
gatk MarkDuplicates \
-I ${indir}/${sample_id}_${genome_base}.sorted.bam \
-O ${outdir}/${sample_id}_${genome_base}.sorted.marked.bam \
-M ${qc_dir}/${sample_id}_${genome_base}.mark_dupes.metrics \
--VALIDATION_STRINGENCY LENIENT

if [[ $? -eq 0 ]]
then
	if [[ -f ${outdir}/${sample_id}_${genome_base}.sorted.marked.bam ]]
	then
		if [[ ! -d checkpoints ]]
		then
			mkdir checkpoints
		fi
		touch \
checkpoints/${prefix}_${SLURM_ARRAY_TASK_ID}.checkpoint
		exit 0
	else
		echo "Error - duplicate-marked BAM not created \
for ${sample_id}."
		exit 1
	fi
else
	echo "Error - non-zero exit code returned by GATK4."
	exit 1
fi
