#!/bin/bash
#SBATCH --mem=17g
#SBATCH --time=04:00:00

prefix=$1 # sbatch filename without file extensions
indir=$2 # parent input directory containing subdirectories
# subdirectory for this job step
indir=${indir}/interval_${SLURM_ARRAY_TASK_ID}
outdir=$3 # output directory
genome=$4
genome_basename=$(basename -- $genome)
genome_base=`echo $genome_basename | sed 's/\..*//g'`
genome_path=`dirname $genome`
intervals_file=$5
interval=`cat $intervals_file | sed -n ${SLURM_ARRAY_TASK_ID}p`
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

# Create output directory
if [[ ! -d $outdir ]]
then
	mkdir $outdir
fi
if [[ ! -d $tempdir ]]
then
	mkdir $tempdir
fi

# Run GATK4's GenotypeGVCFs
# GenomicsDBImport option
gatk GenotypeGVCFs \
--java-options "-Xms14g -Xmx14g" \
-R $genome \
--sequence-dictionary ${genome_path}/${genome_base}.dict \
-L $intervals_list \
-V gendb://${indir} \
-O ${outdir}/interval_${SLURM_ARRAY_TASK_ID}_${genome_base}.vcf.gz \
--tmp-dir $tempdir

# Checkpoint
if [[ $? -eq 0 ]]
then
	if [[ -f \
${outdir}/interval_${SLURM_ARRAY_TASK_ID}_${genome_base}.vcf.gz ]]
	then
		if [[ ! -d checkpoints ]]
		then
			mkdir checkpoints
		fi
#		touch \
#checkpoints/${prefix}_${SLURM_ARRAY_TASK_ID}.checkpoint
		exit 0
	else
		echo "Error - VCF file \
${outdir}/interval_${SLURM_ARRAY_TASK_ID}_${genome_base}.vcf.gz \
not created."
		exit 1
	fi
else
	echo "Error - non-zero exit code returned by GATK4."
	exit 1
fi

