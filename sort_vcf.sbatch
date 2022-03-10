#!/bin/bash
#SBATCH --mem=25g
#SBATCH --time=00:30:00

prefix=$1
genome=$2
infile_list=$3
infile=`cat $infile_list | sed -n ${SLURM_ARRAY_TASK_ID}p`
infile_base=`echo $infile | sed 's/\..*//g'`
tempdir=${prefix}_tmp

# Load GATK4
source ~/bin/anaconda3/etc/profile.d/conda.sh
conda activate gatk4
gatk --version
if [[ $? -ne 0 ]]
then
	echo "Error - check GATK4 installation."
	exit 1
fi

# Create temp directory
if [[ ! -d $tempdir ]]
then
        mkdir $tempdir
fi

# Run GATK4's SortVcf
gatk SortVcf \
--java-options "-Xms20g -Xmx20g" \
-R $genome \
-I $infile \
-O ${infile_base}.sorted.vcf.gz \
--TMP_DIR $tempdir

# Checkpoint
if [[ $? -eq 0 ]]
then
	if [[ -f ${infile_base}.sorted.vcf.gz ]]
	then
		if [[ ! -d checkpoints ]]
		then
			mkdir checkpoints
		fi
		touch \
checkpoints/${prefix}_${SLURM_ARRAY_TASK_ID}.checkpoint
		exit 0
	else
		echo "Error on sort of $infile"
		exit 1
	fi
else
	echo "Error - non-zero exit code returned by GATK4."
	exit 1
fi

