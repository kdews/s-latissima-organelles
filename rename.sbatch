#!/bin/bash
#SBATCH --mem=5mb
#SBATCH --time=03:00:00

prefix=$1 # sbatch filename without file extensions
indir=$2 # input directory
outdir=$3 # output directory
logdir=${prefix}_logs # log directory
samples_file=$4
# Optional, to specify directory containing scripts
# MUST end in '/'
scripts_dir=$4

# Create new output directory (if needed)
if [[ ! -d $outdir ]]
then
	printf "Creating output directory ${outdir}.\n\n"
	mkdir $outdir 
fi

# Run rename Python script
python ${scripts_dir}rename_MO_KD.py $indir $outdir $logdir
# Exit with error code on Python failure
if [[ $? -ne 0 ]]
then
	printf "Error on Python script submission.\n"
	exit 1
fi

# MD5sums
printf "Checking file copy integrity with MD5sum.\n"
# Run MD5sum on contents of $indir (if needed)
if [[ ! -f ${indir}/md5sum ]]
then
	printf "Creating MD5sum in ${indir}.\n"
	for file in `ls ${indir}/*fastq.gz`
	do
		md5sum $file >> ${indir}/md5sum
	done
elif [[ `awk '{print $2}' ${indir}/md5sum` != `ls ${indir}/*fastq.gz` ]]
then
	rm ${indir}/md5sum
	printf "Mistmatch detected. Recreating MD5sum in ${indir}.\n"
        for file in `ls ${indir}/*fastq.gz`
        do
                md5sum $file >> ${indir}/md5sum
        done
else
	printf "MD5sum detected in ${indir}.\n"
fi
# Run MD5sum on contents of $outdir (if needed)
if [[ ! -f ${outdir}/md5sum ]]
then
	printf "Creating MD5sum in ${outdir}.\n"
	for file in `ls ${outdir}/*fastq.gz`
	do
		md5sum $file >> ${outdir}/md5sum
	done
elif [[ `awk '{print $2}' ${outdir}/md5sum` != `ls ${outdir}/*fastq.gz` ]]
then
	rm ${outdir}/md5sum
	printf "Mistmatch detected. Recreating MD5sum in ${outdir}.\n"
	for file in `ls ${outdir}/*fastq.gz`
	do
		md5sum $file >> ${outdir}/md5sum
	done
else
	printf "MD5sum detected in ${outdir}.\n"
fi

# Verify that file contents are the same and create
# $samples_file listing new sample IDs
printf "Comparing MD5sum files.\n"
md5sum_test="test"
if [[ -f ${indir}/md5sum ]] && [[ -f ${outdir}/md5sum ]]
then
	md5sum_test=`comm -3 \
<(awk '{print $1}' ${indir}/md5sum | sort) \
<(awk '{print $1}' ${outdir}/md5sum | sort)`
else
	printf "Error - MD5sum files not created.\n"
	exit 1
fi
if [[ -z $md5sum_test ]]
then
	# Make $samples_file
	printf "Creating ${samples_file}.\n"
	ls ${outdir}/*fastq.gz | sed 's/.*\///g' | \
sed 's/_R[12].fastq.*//g' | sort -u > $samples_file
	if [[ $? -eq 0 ]]
	then
		# Make checkpoint file
		printf "Creating checkpoint.\n"
		if [[ ! -d checkpoints ]]
		then
			mkdir checkpoints
		fi
		touch checkpoints/${prefix}.checkpoint
		exit 0
	else
		printf "Error creating ${samples_file}.\n"
	fi
else
	printf "Error - the following renamed file \n\
contents are not identical according to MD5sums:\n"
	for md5 in $md5sum_test
	do
		grep "$md5" ${indir}/md5sum \
${outdir}/md5sum
	done
	exit 1
fi
