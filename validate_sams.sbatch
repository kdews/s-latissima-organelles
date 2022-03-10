#!/bin/bash
#SBATCH --mem=8gb
#SBATCH --time=05:00:00

prefix=$1 # sbatch filename without file extensions
indir=$2 # input directory
outdir=$3 # output directory
genome=$4
genome_basename=$(basename -- $genome)
genome_base=`echo $genome_basename | sed 's/\..*//g'`
id_file=$5
id=`cat $id_file | sed -n ${SLURM_ARRAY_TASK_ID}p`
pattern=$6 # SAM/BAM file ending pattern (e.g., .sorted.bam)
# Note: input filenames must have an underscore following the unique ID
infile=`ls ${indir}/*${id}_*${pattern}`
infile_basename=$(basename -- $infile)

# Load GATK4
source ~/bin/anaconda3/etc/profile.d/conda.sh
conda activate gatk4
gatk --version
if [[ $? -ne 0 ]]
then
	echo "Error - check GATK4 installation."
	exit 1
fi

# Create output directory (if needed)
if [[ ! -d $outdir ]]
then
	mkdir $outdir
fi

# Run GATK4's ValidateSamFile in summary mode
gatk ValidateSamFile -M SUMMARY \
-R $genome -I $infile \
-O ${outdir}/${infile_basename}.validate.summary

# Checkpoint
if [[ $? -eq 0 ]]
then
	if [[ -f ${outdir}/${infile_basename}.validate.summary ]]
	then
		if [[ ! -d checkpoints ]]
		then
			mkdir checkpoints
		fi
		touch \
checkpoints/${prefix}_${SLURM_ARRAY_TASK_ID}.checkpoint
		exit 0
	else
		echo "Error - ValidateSamFile summary for BAM \
$infile not created."
		exit 1
	fi
else
	echo "Error - non-zero exit code returned by GATK4."
	exit 1
fi
