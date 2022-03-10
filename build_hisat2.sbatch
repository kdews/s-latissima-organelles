#!/bin/bash
#SBATCH --mem=40gb
#SBATCH --time=1-0
#SBATCH --cpus-per-task=12

prefix=$1 # sbatch filename without file extensions
indir=$2 # input directory
outdir=$3 # output directory
genome=$4
genome_basename=$(basename -- $genome)
genome_basename_unzip=`echo $genome_basename | sed 's/\.gz//g'`
genome_base=`echo $genome_basename | sed 's/\..*//g'`
genome_path=`dirname $genome`

## Load HISAT2
#source ~/bin/anaconda3/etc/profile.d/conda.sh
#conda activate hisat2
hisat2 --version
if [[ $? -ne 0 ]]
then
	echo "Error - check HISAT2 installation."
fi

# Copy input genome file to $outdir (if needed)
if [[ ! -d $outdir ]]
then
	mkdir $outdir
fi
if [[ !  -f ${outdir}/$genome_basename ]]
then
	echo "Copying $genome to new directory `realpath $outdir`."
	cp $genome $outdir
fi

# Check copy integrity, then unzip
printf "Checking $genome copy (${outdir}/${genome_basename}) \
file integrity with MD5sum.\n"
# Run MD5sum on contents of $datadir (if needed)
if [[ ! -f ${genome_path}/md5sum ]]
then
	printf "Creating MD5sum of $genome_basename in ${genome_path}.\n"
	md5sum $genome >> ${genome_path}/md5sum
else
	printf "MD5sum detected in ${genome_path}.\n"
fi
# Run MD5sum on contents of $outdir (if needed)
if [[ ! -f ${outdir}/md5sum ]]
then
	printf "Creating MD5sum of $genome_basename in ${outdir}.\n"
	md5sum ${outdir}/${genome_basename} >> ${outdir}/md5sum
else
	printf "MD5sum detected in ${outdir}.\n"
fi
# Verify that file contents are the same and create
# $samples_file listing new sample IDs
printf "Comparing MD5sum files.\n"
md5sum_test="test not run"
if [[ -f ${genome_path}/md5sum ]] && [[ -f ${outdir}/md5sum ]]
then
	md5sum_test=`comm -3 \
<(awk '{print $1}' ${genome_path}/md5sum) \
<(awk '{print $1}' ${outdir}/md5sum)`
else
	printf "Error - MD5sum files not created.\n"
	exit 1
fi
# First, verify that copy worked, then unzip copy (if needed)
if [[ -z $md5sum_test ]]
then
	# If copy isn't zipped, does nothing
	if [[ ! -f ${genome_basename_unzip} ]]
	then
		echo "Unzipping ${outdir}/${genome_basename}."
		zcat ${outdir}/${genome_basename} > \
${outdir}/${genome_basename_unzip}
		unzip_test="test not run"
		# Compare contents of zipped and unzipped genomes
		unzip_test=`comm -3 \
<(zcat ${outdir}/${genome_basename} | sort) \
<(cat ${outdir}/${genome_basename_unzip} | sort)`
		if [[ ! -z $unzip_test ]]
		then
			printf "Error - Unzip of \
${outdir}/${genome_basename} unsuccessful.\n See output of comm -3:\n\n"
			printf "${unzip_test}\n"
			exit 1
		fi
	fi
else
	printf "Error - copy of genome file $genome to directory \
'${outdir}' unsuccessful. \n See output of comm -3 of md5sum files:\n\n"
	printf "${md5sum_test}\n"
	exit 1
fi

# Start HISAT2-build run
	printf "Running HISAT2-build on genome file: \
${genome_basename_unzip}\n"
	cd ${outdir}
	hisat2-build -p ${SLURM_CPUS_PER_TASK} \
$genome_basename_unzip $genome_base

# Checkpoint
files_exist () {
	if compgen -G "${outdir}/${1}*.ht2" > /dev/null
	then
		echo "true"
	else
		echo "false"
	fi
}

if [[ $? -eq 0 ]]
then
	cd ..
	if [[ `files_exist ${genome_base}` == "true" ]]
	then
		if [[ ! -d checkpoints ]]
		then
			mkdir checkpoints
		fi
		echo "Success"
		touch \
checkpoints/${prefix}.checkpoint
		exit 0
	else
		printf "Error - ${genome_base}.*.ht2 files \
not detected in '${outdir}' directory. Checkpoint not created.\n"
	fi
else
	printf "Error - non-zero exit code returned by HISAT2-build.\n"
	exit 1
fi

