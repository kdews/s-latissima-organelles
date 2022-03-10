#!/bin/bash
#SBATCH --mem=500mb
#SBATCH --time=02:00:00

prefix=$1 # sbatch filename without file extensions
indir=$2 # input directory
outdir=$3 # output directory
genome=$4
genome_basename=$(basename -- $genome)
genome_base=`echo $genome_basename | sed 's/\..*//g'`

# Load GATK4
source ~/bin/anaconda3/etc/profile.d/conda.sh
conda activate gatk4
gatk --version
if [[ $? -ne 0 ]]
then
	echo "Error - check GATK4 installation."
fi

# Build FASTA dictionary
cd ${indir}
gatk CreateSequenceDictionary -R ${genome}

# Load samtools
conda activate samtools
samtools --version
if [[ $? -ne 0 ]]
then
	printf "Error - check samtools installation.\n"
fi

# Build samtools FASTA index
samtools faidx ${genome_unzip}

# Checkpoint
files_exist_gatk () {
	if compgen -G "${indir}/${1}*.dict" > /dev/null
	then
		echo "true"
	else
		echo "false"
	fi
}

files_exist_sam () {
	if compgen -G "${indir}/${1}*.fai" > /dev/null
	then
		echo "true"
	else
		echo "false"
	fi
}
if [[ $? -eq 0 ]]
then
	cd ..
	if [[ `files_exist_gatk ${genome_base}` == "true" ]] && \
[[ `files_exist_sam ${genome_base}` == "true" ]]
	then
		if [[ ! -d checkpoints ]]
		then
			mkdir checkpoints
		fi
		echo "Success"
		touch checkpoints/${prefix}.checkpoint
		exit 0
	else
		echo "Error - ${genome_base} dictionary & \
index files not detected in '${indir}' directory. Checkpoint not created."
	fi
else
	echo "Error - non-zero exit code returned by GATK4 or samtools."
	exit 1
fi

