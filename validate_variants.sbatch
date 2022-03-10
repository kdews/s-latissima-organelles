#!/bin/bash
#SBATCH --mem=8gb
#SBATCH --time=05:00:00

prefix=$1 # sbatch filename without file extensions
indir=$2 # input directory
outdir=$3 # output directory
genome=$4
genome_basename=$(basename -- $genome)
genome_base=`echo $genome_basename | sed 's/\..*//g'`
infile_list=$5
infile=`cat $infile_list | sed -n ${SLURM_ARRAY_TASK_ID}p`
infile_basename=$(basename -- $infile)
# Set $filetype_flag to -gvcf, if needed
gvcf_patterns=("g.vcf" "gvcf")
for i in "${gvcf_patterns[@]}"
do 
	[[ `echo $infile | grep $i` ]] && filetype_flag="-gvcf" \
&& echo "Treating $infile as gVCF file."
done
[[ -z $filetype_flag ]] &&  echo "Treating $infile as VCF file."

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

# Run GATK4's ValidateVariants
gatk ValidateVariants $filetype_flag \
--validation-type-to-exclude ALLELES \
-R $genome \
-V $infile > \
${outdir}/${infile_basename}.validate.summary 2>&1

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
		echo "Error - ValidateVariant summary for \
$infile not created."
		exit 1
	fi
else
	echo "Error - non-zero exit code returned by GATK4."
	exit 1
fi
