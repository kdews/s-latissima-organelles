#!/bin/bash
#SBATCH --mem=5g
#SBTACH --cpus-per-task=12
#SBATCH --time=10:00:00

prefix=$1 # sbatch filename without file extensions
indir=$2 # input directory
outdir=$3 # output directory
genome=$4
genome_basename=$(basename -- $genome)
genome_base=`echo $genome_basename | sed 's/\..*//g'`
genome_path=`dirname $genome`
indiv_file=$5
indiv_id=`cat $indiv_file | sed -n ${SLURM_ARRAY_TASK_ID}p`
tempdir=${prefix}_tmp

# Load GATK4
source ~/bin/anaconda3/etc/profile.d/conda.sh
conda activate gatk4
gatk --version
if [[ $? -ne 0 ]]
then
	printf "Error - check GATK4 installation.\n"
	exit 1
fi

# Create output and temp directories
if [[ ! -d $outdir ]]
then
	mkdir $outdir
fi
if [[ ! -d $tempdir ]]
then
	mkdir $tempdir
fi

# Run GATK4's HaplotypeCaller
gatk HaplotypeCaller -ERC GVCF -ploidy 1 \
-R ${genome} --sequence-dictionary ${genome_path}/${genome_base}.dict \
-I ${indir}/${indiv_id}_${genome_base}.sorted.marked.merged.bam \
-O ${outdir}/${indiv_id}_${genome_base}.g.vcf.gz \
--tmp-dir $tempdir

# Checkpoint
if [[ $? -eq 0 ]]
then
	if [[ -f \
${outdir}/${indiv_id}_${genome_base}.g.vcf.gz ]]
	then
		if [[ ! -d checkpoints ]]
		then
			mkdir checkpoints
		fi
		touch \
checkpoints/${prefix}_${SLURM_ARRAY_TASK_ID}.checkpoint
		exit 0
	else
		printf "Error - gVCF file \
${outdir}/${indiv_id}_${genome_base}.g.vcf.gz \
not created.\n"
		exit 1
	fi
else
	printf "Error - non-zero exit code returned by GATK4.\n"
	exit 1
fi

