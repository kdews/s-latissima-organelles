#!/bin/bash
#SBATCH --mem=100g
#SBATCH --time=4-0

prefix=$1 # sbatch filename without file extensions
indir=$2 
genome=$3
genome_basename=$(basename -- $genome)
genome_base=`echo $genome_basename | sed 's/\..*//g'`
genome_path=`dirname $genome`
vcf_list=$4
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

# Run GATK4's MergeVcfs
gatk MergeVcfs --java-options "-Xms85g -Xmx85g" \
-R $genome -D ${genome_path}/${genome_base}.dict \
-I $vcf_list -O master_${genome_base}.vcf.gz \
--TMP_DIR $tempdir

# Checkpoint
if [[ $? -eq 0 ]]
then
	if [[ -f master_${genome_base}.vcf.gz ]]
	then
		if [[ ! -d checkpoints ]]
		then
			mkdir checkpoints
		fi
		touch checkpoints/${prefix}.checkpoint
		exit 0
	else
		echo "Error - VCF file master_${genome_base}.vcf.gz \
not created."
		exit 1
	fi
else
	echo "Error - non-zero exit code returned by GATK4."
	exit 1
fi

