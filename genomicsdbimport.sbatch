#!/bin/bash
#SBATCH --mem=50g
#SBATCH --time=1-0

prefix=$1 # sbatch filename without file extensions
indir=$2 # input directory
outdir=$3 # parent output directory containing subdirectories
if [[ ! -d $outdir ]]
then
        mkdir $outdir
fi
# subdirectory for this job step
outdir=${outdir}/interval_${SLURM_ARRAY_TASK_ID} # output directory
genome=$4
genome_basename=$(basename -- $genome)
genome_base=`echo $genome_basename | sed 's/\..*//g'`
genome_path=`dirname $genome`
intervals_file=$5
interval=`cat $intervals_file | sed -n ${SLURM_ARRAY_TASK_ID}p`
gvcf_list=$6
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

## Generate array to hold list all g.vcfs
## and the required "-V" flag before each
#f=`ls ${indir}/*.g.vcf.gz`
#input_gvcfs=(${f// / })
#cnt=${#input_gvcfs[@]}
#for ((i=0;i<cnt;i++)); do
#    input_gvcfs[i]="-V ${input_gvcfs[i]}"
#done

# Run GATK4's GenomicsDBImport
gatk GenomicsDBImport \
--java-options "-Xms39g -Xmx39g" \
-R $genome \
--sequence-dictionary ${genome_path}/${genome_base}.dict \
-L $interval \
-V $gvcf_list \
--genomicsdb-workspace-path $outdir \
--tmp-dir $tempdir

# Checkpoint
if [[ $? -eq 0 ]]
then
	if [[ -d $outdir ]]
	then
		if [[ ! -d checkpoints ]]
		then
			mkdir checkpoints
		fi
		touch \
checkpoints/${prefix}_${SLURM_ARRAY_TASK_ID}.checkpoint
		exit 0
	else
		echo "Error - Genomics Database Workspace \
$outdir not created."
		exit 1
	fi
else
	echo "Error - non-zero exit code returned by GATK4."
	exit 1
fi

