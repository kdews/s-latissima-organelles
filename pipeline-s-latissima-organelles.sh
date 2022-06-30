#!/bin/bash
#SBATCH -p cegs
#SBATCH --time=3-0
#SBATCH -J queen
#SBATCH -o %x.log

## Organelle load calculation pipeline
# A SLURM- and conda-dependent pipeline with sequential job steps linked by 
# dependencies and checkpoint files

# Help message
if [[ $1 = "-h" ]] || [[ $1 = "--help" ]]
then
	printf "%s\n" "\
----------------------WELCOME TO ORGANELLE LOAD PIPELINER----------------------

Usage: 
  sbatch pipeline_template.sh [options] <path/to/reference/genome> <path/to/dir/
containing/FASTQs> <partition> [scripts_dir] [outdir]

Options:
  -h/--help                      print this usage message

Note: Sourced SBATCH files named with convention: <prefix>.sbatch 

Takes as input a genome and PATH to a directory containing FASTQs to align, and
outputs...

Analysis:
  indexer/
    samples_file.txt             indexes sample IDs
    individuals_file.txt         indexes individual IDs
    intervals_file.txt           indexes split interval lists
    gvcf.list                    indexes gVCF files 
    vcf.list                     indexes VCF files (in numerical order)
  wgs/                        
    *.fastq.gz                   FASTQ files renamed to shorter sample IDs 
                                 (copied from source)
    *.repaired.fastq.gz          FASTQ read pairs repaired with repair.sh
  trimmed_reads/
    *_val_1/2.fq.gz              reads post trimming by Trim Galore!
  bams/
    *.fasta                      reference genome (copied from source)
    *.fasta.ht2                  indexed reference genome
    *.fasta.fai                  samtools-indexed reference genome
    *.dict                       GATK4-style reference genome dictionary
    *.sorted.bam                 sorted alignment files of trimmed reads to 
                                 reference genome
    *.sorted.marked.bam          sorted alignment files, duplicates marked
    *.sorted.marked.merged.bam   sorted alignment files, merged by individual
  gvcfs/
    *.g.vcf.gz                   genome variant call files (gVCFs) for each 
                                 individual
  split_intervals/
    *-scattered.interval_list    GATK4-style lists of genomic intervals, split 
                                 into as close to the desired scatter count as 
                                 possible without splitting input reference 
                                 contigs (e.g., scaffolds/chromosomes)
  genomicsdbimport/
    interval_*/                  GATK4-style GenomicsDB (datastore of variant
                                 call data from each individual, split into 
                                 groups of genomic intervals specified in 
                                 *-scattered.interval_list files)
  vcfs/
    *.vcf.gz                     variant call files (VCFs) for each group of 
                                 genomic intervals
  master_{genome_base}.vcf.gz    final VCF file of all samples aligned to the
                                 reference genome

Quality control:
  quality_control/
    *_fastqc.zip/html            FastQC reports for all input FASTQs
    *_val_1/2_fastqc.zip/html    FASTQC reports for trimmed FASTQs
    *_trimming_report.txt        Trim Galore! trimming report for each sample
    *.hisat2.summary             HISAT2 alignment report for each sample
    *.validate.summary           validation reports of alignment (SAM/BAM) and 
                                 variant (gVCF/VCF) files
    multiqc_report.html          MultiQC report summarizing QCs at each step

Logs and checkpoints:
  queen.log                      log file generated by pipeliner script
  <prefix>_logs/
    <prefix>_<#>.out             SLURM log files from inividual job step 
                                 submissions, named with the convention: 
                                 <prefix>.sbatch > 
                                 <prefix>_logs/<prefix>_<#>.out 2>&1
                                 created upon job completion, where #
                                 corresponds to array index of <prefix> job step
  checkpoints/
    <prefix>_<#>.checkpoint      checkpoint file(s) for each job step, named 
                                 with the convention: 
                                 <prefix>.sbatch == <prefix>_<#>.checkpoint
                                 created upon job completion, where # 
                                 corresponds to array index of <prefix> job step

Temporary directories:
  <prefix>_tmp                   temporary directory for a given job step

Direct any questions to Kelly DeWeese (kdeweese@mac.com)
"
	exit 0
fi


# Define global variables
# Master log file
pipeline_log=queen.log
# User defined
genome=s_latissima_chloro_NCBI_2020.fasta
#path_to_raw_reads=/project/noujdine_61/kdeweese/latissima/all_wgs_OG_names
path_to_raw_reads=/project/noujdine_61/kdeweese/latissima/wgs_test
partition=cegs
scripts_dir=s-latissima-organelles # optional, directory containing scripts
#scripts_dir=$4
outdir=$5 # optional, output directory for entire pipeline
# If genome file exists, change name to realpath
[[ $genome ]] && genome=$(realpath $genome) && [[ -f $genome ]] || \
{ echo "Genome file $genome not detected." >> $pipeline_log; exit 1; }
genome_basename=$(basename -- $genome)
genome_basename_unzip=`echo $genome_basename | sed 's/\.gz//g'`
genome_base=`echo $genome_basename | sed 's/\..*//g'`
# If path to raw reads exists, change name to realpath
[[ $path_to_raw_reads ]] && path_to_raw_reads=$(realpath $path_to_raw_reads) \
&& [[ -d $path_to_raw_reads ]] || { echo "Reads directory $path_to_raw_reads \
not detected." >> $pipeline_log; exit 1; }
# If scripts directory is speicified and exists, change to realpath and append 
# '/' to name
if [[ $scripts_dir ]]
then
	[[ -d $scripts_dir ]] && echo "Searching for scripts in ${scripts_dir}\
..." >> $pipeline_log && scripts_dir=$scripts_dir/ || echo "Searching for \
scripts in current directory: `pwd`..." >> $pipeline_log
fi
# If output directory is specified and exists, change to output directory
if [[ $outdir ]]
then 
	[[ -d $outdir ]] && cd $outdir && [[ $? -eq 0 ]] && echo "Writing all \
output to ${outdir}." >> $pipeline_log || { echo "Error - output directory \
${outdir} doesn't exist. Exiting." >> $pipeline_log; exit 1; }
fi
# Specific to pipeline
# Assumes paired end FASTQs
num_samples=`expr $(ls ${path_to_raw_reads}/*fastq.gz | wc -l) / 2`
indexer_dir=indexer
samples_dir=wgs
samples_file=${indexer_dir}/samples_file.txt
qc_dir=quality_control
trimmed_dir=trimmed_reads
bams_dir=bams
indiv_file=${indexer_dir}/individuals_file.txt
gvcfs_dir=gvcfs
split_intervals_dir=split_intervals
# Number of interval groups to split into for scatter-gather parallelization
scatter=2
intervals_file=intervals_file.txt
gvcf_list=${indexer_dir}/gvcfs.list
genomicsdbimport_dir=genomicsdbimport
vcf_list=${indexer_dir}/vcf.list
vcfs_dir=vcfs
# Define function to format output file with newlines between job steps
printspace () { printf "\n" >> $pipeline_log; }
# Define function to return prefix of input file
get_prefix () {
	local filename=`basename -- $1`
	local filename="${filename%.*}"
	echo $filename
}
# Define function to make a log directory from an input string
# (e.g., prefix), but only if it doesn't already exist
make_logdir () {
	local logdir=${1}_logs
	# Create log directory (if needed)
	if [[ ! -d $logdir ]]
	then
		mkdir $logdir
	fi
	echo "$logdir"
}
# Define function for array or non-array submission
# that returns the jobid but takes no dependencies
no_depend () {
	# Define job type
	# Determine array size for all batch jobs
	# (e.g., number of samples)
	if [[ $1 = "--array" ]]
	then
		# Inputs
		local array_size=$2
		if [[ `echo $array_size | sed 's/,/ /g' | wc -w` -eq 1 ]]
		then
			array_size="1-${array_size}"
		fi
		local sbatch_file=$3
		local prefix=$4
		local trailing_args="${@:5}"
		# Create log directory named after prefix
		local logdir=`make_logdir $prefix`
		# Job submission
		local jobid=`sbatch -p $partition -J ${prefix} --parsable \
--array=${array_size} -o ${logdir}/%x_%a.out $sbatch_file $prefix \
$trailing_args`
		echo "sbatch -p $partition -J ${prefix} --parsable \
--array=${array_size} -o ${logdir}/%x_%a.out $sbatch_file $prefix \
$trailing_args" >> $pipeline_log
	else
		# Inputs
		local sbatch_file=$1
		local prefix=$2
		local trailing_args="${@:3}"
		# Create log directory named after prefix
		local logdir=`make_logdir $prefix`
		# Job submission
		local jobid=`sbatch -p $partition -J ${prefix} --parsable -o \
${logdir}/%x.out $sbatch_file $prefix $trailing_args`
		echo "sbatch -p $partition -J ${prefix} \
--parsable -o ${logdir}/%x.out $sbatch_file $prefix $trailing_args" \
>> $pipeline_log
	fi
	echo "$jobid"
}
# Define function for array or non-array submission
# that takes a dependency and returns a jobid
depend () {
	# Define job type
	if [[ $1 = "--array" ]]
	then
		# Inputs
		local array_size=$2
		if [[ `echo $array_size | sed 's/,/ /g' | wc -w` -eq 1 ]]
		then
			array_size="1-${array_size}"
		fi
		local sbatch_file=$3
		local prefix=$4
		local dep_jobid=$5
		local trailing_args="${@:6}"
		# Create log directory named after prefix
		local logdir=`make_logdir $prefix`
		# Job submission
		local jobid=`sbatch -p $partition -J ${prefix} --parsable \
--array=${array_size} -o ${logdir}/%x_%a.out --dependency=afterok:${dep_jobid} \
$sbatch_file $prefix $trailing_args`
		echo "sbatch -p $partition -J ${prefix} --parsable \
--array=${array_size} -o ${logdir}/%x_%a.out --dependency=afterok:${dep_jobid} \
$sbatch_file $prefix $trailing_args" >> $pipeline_log
	else
		# Inputs
		local sbatch_file=$1
		local preifx=$2
		local dep_jobid=$3
		local trailing_args="${@:4}"
		# Create log directory named after prefix
		local logdir=`make_logdir $prefix`
		# Job submission
		local jobid=`sbatch -p $partition -J ${prefix} --parsable -o \
${logdir}/%x.out --dependency=afterok:${dep_jobid} $sbatch_file $prefix \
$trailing_args`
		echo "sbatch -p $partition -J ${prefix} --parsable -o \
${logdir}/%x.out --dependency=afterok:${dep_jobid} $sbatch_file $prefix \
$trailing_args" >> $pipeline_log
	fi
	echo "$jobid"
}
# Define function to check for existence of a set of 
# similarly named checkpoint files with a wildcard
checkpoints_exist () {
	prefix=$1
	if [[ -z $prefix ]]
	then
		{ date;  echo "Error - no prefix supplied to checkpoints_exist \
function."; } >> $pipeline_log
		exit 1
	fi
	if compgen -G "checkpoints/${prefix}*.checkpoint" > /dev/null
	then
		echo "true"
	else
		echo "false"
	fi
}
# Define function to check for and remove a set of 
# similarly named checkpoint files
wipecheckpoints () {
	if [[ `checkpoints_exist $1` = "true" ]]
        then
                rm checkpoints/${1}*.checkpoint
        fi
}
# Define function to check for a set of similarly named 
# checkpoint files and return missing array indices
missingcheckpoints () {
	# $1 is input_prefix
	# $2 is array_size
	if [[ `checkpoints_exist $1` = "true" ]]
	then
		local total=`seq 1 1 "$2"`
		for i in `echo "$total"`
		do
			[[ -f checkpoints/${1}_${i}.checkpoint ]] || printf \
"${i},"
		done
	else
		echo "Error - no checkpoints found for ${1}."
		exit 1
	fi
}
# Define function to run an array job step with a set number of 
# checkpoints files as a "dependency" (e.g., wait steps)
# (This avoids QOSMax errors from SLURM with next to zero use of storage)
pipeliner () {
	if [[ $1 = "--array" ]]
	then
		local array_indices=$2
		local dependency_prefix=$3
		local dependency_size=$4
		local sleep_time=$5
		local input_sbatch=$6
		local input_prefix=$7
		local trailing_args="${@:8}"
	else
		local dependency_prefix=$1
		local dependency_size=$2
		local sleep_time=$3
		local input_sbatch=$4
		local input_prefix=$5
		local trailing_args="${@:6}"
	fi
	[[ "$@" ]] || { echo "Error - no input to pipeliner. Exiting..." >> \
$pipeline_log ; exit 1; }
	echo "pipeliner $@" >> $pipeline_log
	until [[ `checkpoints_exist $dependency_prefix` = "true" ]] && \
[[ `ls checkpoints/${dependency_prefix}*.checkpoint | wc -l` -eq \
$dependency_size ]]
	do
		{ date; echo "Waiting for completion of $dependency_prefix \
step."; } >> $pipeline_log
		sleep $sleep_time
	done
	if [[ `checkpoints_exist $input_prefix` = "true" ]]
	then
		local num_checks=`ls \
checkpoints/${input_prefix}*.checkpoint | wc -l`
		{ date; echo "${num_checks} checkpoint(s) detected for \
${input_prefix}. Validating..."; } >> $pipeline_log
		if [[ $1 = "--array" ]] && [[ $array_indices ]] && \
[[ $num_checks -ne $array_indices ]] 
		then
			local array_flag="${1} `missingcheckpoints \
$input_prefix $array_indices`"
		echo "Error detected in ${input_prefix} checkpoint. Restarting \
step at checkpoint." >> $pipeline_log
		echo "Submitting job array indices: $array_indices" \
>> $pipeline_log
		local jobid=`no_depend $array_flag $input_sbatch $input_prefix \
$trailing_args`
		elif [[ $num_checks -eq $array_indices ]]
		then
			echo "${input_prefix} run already \
completed. Skipping." >> $pipeline_log
		elif [[ $1 != "--array" ]] && [[ $num_checks -eq 1 ]]
		then
			echo "${input_prefix} run already completed. \
Skipping." >> $pipeline_log
		else
			echo "Error - check inputs to 'pipeliner' function." \
>> $pipeline_log
		fi
	else
		[[ $1 = "--array" ]] && [[ $array_indices ]] && local \
array_flag="${1} ${array_indices}"
		echo "Beginning ${input_prefix} step." >> $pipeline_log
		local jobid=`no_depend $array_flag $input_sbatch \
$input_prefix $trailing_args`
	fi
	echo $jobid
}


# Run pipeline
# Set array size for working with sample IDs
array_size=$num_samples
{ date; echo "Array size set to ${array_size}."; } >> $pipeline_log
printspace

# Set sleep time (wait time) between checking for checkpoints
sleep_time=1800
if (( $(( $sleep_time / 60 )) < 1 ))
then
	st="$(( $sleep_time / 60 )) second(s)"
elif (( $(( $sleep_time / 3600 )) > 1 ))
then
	hr="$(( $sleep_time / 3660 ))"
	min="$(( ($sleep_time - ($hr * 3600)) / 60 ))"
	st="$hr hour(s) and $min minute(s)"
else
	st="$(( $sleep_time / 60 )) minute(s)"
fi
{ date; echo "Wait time between checking for checkpoints set to: $st"; } \
>> $pipeline_log
printspace

# Rename reads and create $samples_file
input_sbatch=${scripts_dir}rename.sbatch
input_prefix=`get_prefix $input_sbatch`
# Before running, check if run has already succeeded
if [[ -f $samples_file ]] && \
[[ `checkpoints_exist $input_prefix` = "true" ]]
then
	{ date; echo "Checkpoint and $samples_file detected. Skipping \
${input_prefix} step."; } >> $pipeline_log
else
	wipecheckpoints $input_prefix
	{ date; echo "Renaming: Files in $path_to_raw_reads copied into \
$samples_dir and renamed."; } >> $pipeline_log 
	jobid=`no_depend $input_sbatch $input_prefix \
$path_to_raw_reads $samples_dir \
$samples_file $scripts_dir`
fi
# Set dependency size for next step
dependency_size=1
printspace

## Repair FASTQs with BBMap repair.sh
## Depend start upon last job step
#dependency=$jobid
#dependency_prefix=$input_prefix
#input_sbatch=${scripts_dir}repair.sbatch
#input_prefix=`get_prefix $input_sbatch`
#jobid=`pipeliner --array $array_size \
#$dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$samples_dir $samples_dir \
#$samples_file`
## Set dependency size for next step
#dependency_size=$array_size
#printspace
#
## Remove original renamed reads to conserve memory before next steps
## Depend start upon last job step
#dependency_prefix=$input_prefix
#input_prefix=og_reads_deleted
#if [[ `checkpoints_exist $dependency_prefix` = "true" ]] && \
#[[ `ls checkpoints/${dependency_prefix}*.checkpoint | wc -l` -eq \
#$dependency_size ]]
#then
#	if [[ `checkpoints_exist $input_prefix` = "true" ]]
#	then
#		{ date; echo "Original reads already removed. Skipping."; } >> \
#$pipeline_log
#	else	
#		{ date; echo "Removing original renamed reads \
#to conserve memory before next steps."; } >> $pipeline_log
#		for sample_id in `cat $samples_file`
#		do
#			if \
#[[ -f ${samples_dir}/${sample_id}_R1.fastq.gz ]] && \
#[[ -f ${samples_dir}/${sample_id}_R2.fastq.gz ]] && \
#[[ -f ${trimmed_dir}/${sample_id}_R1.repaired.fastq.gz ]] && \
#[[ -f ${trimmed_dir}/${sample_id}_R2.repaired.fastq.gz ]]
#			then
#				rm ${samples_dir}/${sample_id}_R1.fastq.gz
#				rm ${samples_dir}/${sample_id}_R2.fastq.gz
#			else
#				{ date; echo "Error - some reads missing for \
#${sample_id}, and no checkpoint file detected for $input_prefix step."; } >> \
#$pipeline_log
#				exit 1
#			fi
#		done
#		touch checkpoints/${input_prefix}.checkpoint
#	fi
#fi
#printspace
#
## FastQC
## Keep previous dependency
#dependency=$jobid
#dependency_prefix=$dependency_prefix
#input_sbatch=${scripts_dir}fastqc.sbatch
#input_prefix=`get_prefix $input_sbatch`
## Check for dependency jobid
#if [[ $dependency ]]
#then
#	{ date; echo "Running $input_prefix following completion of \
#$dependency_prefix step (jobid ${dependency})."; } >> $pipeline_log
#	jobid=`depend --array $array_size \
#$input_sbatch $input_prefix $dependency \
#$samples_dir $qc_dir \
#$samples_file`
#else
#	# If dependency is finished running, verify its checkpoint
#	jobid=`pipeliner --array $array_size \
#$dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$samples_dir $qc_dir \
#$samples_file`
#fi
## Set dependency size for next step
#dependency_size=$array_size
#printspace
#
## Quality and adapter trimming
## Depend start upon last job step
#dependency_prefix=$input_prefix
#input_sbatch=${scripts_dir}trim_galore.sbatch
#input_prefix=`get_prefix $input_sbatch`
#jobid=`pipeliner --array $array_size \
#$dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$samples_dir $qc_dir \
#$samples_file $trimmed_dir`
## Set dependency size for next step
#dependency_size=$array_size
#printspace
#
## Run HISAT2-build on genome
## Depend start upon last job step
#dependency_prefix=$input_prefix
#input_sbatch=${scripts_dir}build_hisat2.sbatch
#input_prefix=`get_prefix $input_sbatch`
#jobid=`pipeliner \
#$dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$bams_dir $bams_dir \
#$genome`
#dependency_size=1
#printspace
#
## Redefine $genome location after HISAT2-build step
#if [[ -f ${bams_dir}/${genome_basename_unzip} ]]
#then
#	genome=${bams_dir}/${genome_basename_unzip}
#	{ date; echo "Genome now being sourced from: $genome"; } >> \
#$pipeline_log
#else
#	{ date; echo "Error - gunzipped genome not detected in ${bams_dir}."; \
#} >> $pipeline_log
#	exit 1
#fi
#printspace
#
## Run HISAT2 on all samples
## Depend start upon last job step
#dependency=$jobid
#dependency_prefix=$input_prefix
#input_sbatch=${scripts_dir}hisat2.sbatch
#input_prefix=`get_prefix $input_sbatch`
#jobid=`pipeliner --array $array_size \
#$dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$trimmed_dir $bams_dir \
#$genome $samples_file $qc_dir $indiv_file`
#dependency_size=$array_size
## Set dependency size for next step
#dependency_size=$array_size
#printspace
#
## Sort IDs in $indiv_file for unique invidual IDs
#dependency_prefix=$input_prefix
#until [[ -f $indiv_file ]] && \
#[[ `checkpoints_exist $dependency_prefix` = "true" ]] && [[ `ls \
#checkpoints/${dependency_prefix}*.checkpoint | wc -l` -eq $dependency_size ]]
#do
#	{ date; echo "Waiting for completion of \
#$dependency_prefix step."; } >> $pipeline_log
#	sleep $sleep_time
#done
#if [[ -f $indiv_file ]]
#then
#	{ date; echo "Sorting $indiv_file for unique invidual IDs."; } >> \
#$pipeline_log
#	sort -u $indiv_file > ${indiv_file}_sorted
#	mv ${indiv_file}_sorted $indiv_file
#else
#	{ date; echo "Error - $indiv_file not detected."; } >> $pipeline_log
#	exit 1
#fi
#printspace
#
## Create reference genome dictionary and 
## samtools index of genome for GATK tools
## Depend start upon last job step
#dependency=$jobid
#dependency_prefix=$input_prefix
#input_sbatch=${scripts_dir}prep_ref.sbatch
#input_prefix=`get_prefix $input_sbatch`
#jobid=`pipeliner $dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$bams_dir $bams_dir \
#$genome`
## Set dependency size for next step
#dependency_size=1
#printspace
#
## Run GATK4 ValidateSamFile on HISAT2 alignmnet BAMs
## Depend start upon last job step
#dependency=$jobid
#dependency_prefix=$input_prefix
#input_sbatch=${scripts_dir}validate_sams.sbatch
#input_prefix=`get_prefix $input_sbatch`
#pattern=.sorted.bam
#iteration=1
#input_prefix=${input_prefix}_${iteration}
#jobid=`pipeliner --array $array_size \
#$dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$bams_dir $qc_dir \
#$genome $samples_file $pattern`
## Set dependency size for next step
#dependency_size=$array_size
#printspace
#
## Run GATK4 CollectAlignmentSummaryMetrics 
## on HISAT2 alignmnet BAMs
## Depend start upon last job step
#dependency=$jobid
#dependency_prefix=$input_prefix
#input_sbatch=${scripts_dir}collect_alignment_summary_metrics.sbatch
#input_prefix=`get_prefix $input_sbatch`
#jobid=`pipeliner --array $array_size \
#$dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$bams_dir $qc_dir \
#$genome $samples_file`
## Set dependency size for next step
#dependency_size=$array_size
#printspace
#
## Run GATK4 CollectWgsMetrics on HISAT2 alignmnet BAMs
## Depend start upon last job step
#dependency=$jobid
#dependency_prefix=$input_prefix
#input_sbatch=${scripts_dir}collect_wgs_metrics.sbatch
#input_prefix=`get_prefix $input_sbatch`
#jobid=`pipeliner --array $array_size \
#$dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$bams_dir $qc_dir \
#$genome $samples_file`
#
## Run GATK4 MarkDuplicates
## Depend start upon last job step
#dependency=$jobid
#dependency_prefix=$input_prefix
#input_sbatch=${scripts_dir}mark_dupes.sbatch
#input_prefix=`get_prefix $input_sbatch`
#jobid=`pipeliner --array $array_size \
#$dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$bams_dir $bams_dir \
#$genome $samples_file $qc_dir`
## Set dependency size for next step
#dependency_size=$array_size
#printspace 
#
## Run GATK4 ValidateSamFile on MarkDuplicate BAMs
## Depend start upon last job step
#dependency=$jobid
#dependency_prefix=$input_prefix
#input_sbatch=${scripts_dir}validate_sams.sbatch
#input_prefix=`get_prefix $input_sbatch`
#pattern=.marked.sorted.bam
#iteration=2
#input_prefix=${input_prefix}_${iteration}
#jobid=`pipeliner --array $array_size \
#$dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$bams_dir $qc_dir \
#$genome $samples_file $pattern`
## Set dependency size for next step
#dependency_size=$array_size
#printspace
#
## Set new array size to number of individuals
#if [[ -f $indiv_file ]]
#then
#	num_indiv=`cat $indiv_file | wc -l`
#	array_size=$num_indiv
#	{ date; echo "Array size set to ${array_size}."; } >> $pipeline_log
#else
#	{ date; echo "Error - $indiv_file not detected."; } >> $pipeline_log
#	exit 1
#fi
#printspace
#
## Collapse BAMs per sample into BAMs per individual with GATK4 MergeSamFiles
## Depend start upon last job step
#dependency=$jobid
#dependency_prefix=$input_prefix
#input_sbatch=${scripts_dir}collapse_bams.sbatch
#input_prefix=`get_prefix $input_sbatch`
#jobid=`pipeliner --array $array_size \
#$dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$bams_dir $bams_dir \
#$genome $indiv_file`
## Set dependency size for next step
#dependency_size=$array_size
#printspace
#
## Run GATK4 ValidateSamFile on MarkDuplicate BAMs
## Depend start upon last job step
#dependency=$jobid
#dependency_prefix=$input_prefix
#input_sbatch=${scripts_dir}validate_sams.sbatch
#input_prefix=`get_prefix $input_sbatch`
#pattern=.merged.marked.sorted.bam
#iteration=3
#input_prefix=${input_prefix}_${iteration}
#jobid=`pipeliner --array $array_size \
#$dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$bams_dir $qc_dir \
#$genome $indiv_file $pattern`
## Set dependency size for next step
#dependency_size=$array_size
#printspace
#
## Index collapsed BAMs for GATK4 HaplotypeCaller
## Depend start upon last job step
#dependency=$jobid
#dependency_prefix=$input_prefix
#input_sbatch=${scripts_dir}index_bams.sbatch
#input_prefix=`get_prefix $input_sbatch`
#jobid=`pipeliner --array $array_size \
#$dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$bams_dir $bams_dir \
#$genome $indiv_file`
## Set dependency size for next step
#dependency_size=$array_size
#printspace
#
## Run GATK4 HaplotypeCaller
## Depend start upon last job step
#dependency=$jobid
#dependency_prefix=$input_prefix
#input_sbatch=${scripts_dir}haplotype_caller.sbatch
#input_prefix=`get_prefix $input_sbatch`
#jobid=`pipeliner --array $array_size \
#$dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$bams_dir $gvcfs_dir \
#$genome $indiv_file`
## Set dependency size for next step
#dependency_size=$array_size
#printspace
#
## Create file to index HaplotypeCaller gVCFs
#dependency_prefix=$input_prefix
#until [[ -d $gvcfs_dir ]] && \
#[[ `checkpoints_exist $dependency_prefix` = "true" ]] && [[ `ls \
#checkpoints/${dependency_prefix}*.checkpoint | wc -l` -eq $dependency_size ]]
#do
#	{ date; echo "Waiting for completion of $dependency_prefix step."; } \
#>> $pipeline_log
#	sleep $sleep_time
#done
#num_gvcfs=`ls ${gvcfs_dir}/*g.vcf.gz | wc -l`
#if [[ $num_gvcfs -eq $array_size ]]
#then
#	{ date; echo "Creating $gvcf_list of $num_gvcfs files."; } >> \
#$pipeline_log
#	ls $gvcfs_dir/*g.vcf.gz > $gvcf_list
#	if [[ `cat $gvcf_list | wc -l` -ne $array_size ]]
#	then
#		{ date; echo "Error - incorrect number of files in $gvcf_list \
#(`cat $gvcf_list | wc -l`/${array_size}). Exiting..."; } >> \
#$pipeline_log
#		exit 1
#	fi
#else
#	{ date; echo "Error - incorrect number of files \
#(${num_gvcfs}/${array_size}) detected in ${gvcfs_dir}. $gvcf_list not created. \
#Exiting..."; } >> $pipeline_log
#	exit 1
#fi
#printspace
#
## Run GATK4 ValidateVariants on HaplotypeCaller gVCFs
## Depend start upon last job step
#dependency=$jobid
#dependency_prefix=$input_prefix
#input_sbatch=${scripts_dir}validate_variants.sbatch
#input_prefix=`get_prefix $input_sbatch`
#iteration=1
#input_prefix=${input_prefix}_${iteration}
#jobid=`pipeliner --array $array_size \
#$dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$gvcfs_dir $qc_dir \
#$genome $gvcf_list`
## Set dependency size for next step
#dependency_size=$array_size
#printspace
#
## Run GATK4 SplitIntervals on genome to produce interval 
## lists in $split_intervals_dir for CombineGVCFs step
## Depend start upon last job step
#dependency=$jobid
#dependency_prefix=$input_prefix
#input_sbatch=${scripts_dir}split_intervals.sbatch
#input_prefix=`get_prefix $input_sbatch`
#jobid=`pipeliner $dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$split_intervals_dir $split_intervals_dir \
#$genome $scatter`
## Set dependency size for next step
#dependency_size=1
#printspace
#
## Set array size to number of split interval lists created
#dependency_prefix=$input_prefix
#until [[ -d $split_intervals_dir ]] && \
#[[ `checkpoints_exist $dependency_prefix` = "true" ]] && \
#[[ `ls checkpoints/${dependency_prefix}*.checkpoint | wc -l` -eq \
#$dependency_size ]]
#do
#	{ date; echo "Waiting for completion of $dependency_prefix step."; } \
#>> $pipeline_log
#	sleep $sleep_time
#done
#array_size=$(( `ls ${split_intervals_dir}/*list | wc -l` ))
#{ date; printf "Array size set to number of split interval lists ($array_size) 
#created by split_intervals step (not necessarily equal to scatter=${scatter} 
#because --subdivision-mode BALANCING_WITHOUT_INTERVAL_SUBDIVISION).\n"; } >> \
#$pipeline_log
## Create file to index split intervals lists
#ls ${split_intervals_dir}/*list > $intervals_file
#printspace
#
## Run GATK4 GenomicsDBImport
## Depend start upon last job step
#dependency=$jobid
#dependency_prefix=$input_prefix
#input_sbatch=${scripts_dir}genomicsdbimport.sbatch
#input_prefix=`get_prefix $input_sbatch`
#jobid=`pipeliner --array $array_size \
#$dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$gvcfs_dir $genomicsdbimport_dir \
#$genome $intervals_file $gvcf_list`
## Set dependency size for next step
#dependency_size=$array_size
#printspace
#
## Run GATK4 GenotypeGVCFs
## Depend start upon last job step
#dependency=$jobid
#dependency_prefix=$input_prefix
#input_sbatch=${scripts_dir}genotype_gvcfs.sbatch
#input_prefix=`get_prefix $input_sbatch`
#jobid=`pipeliner --array $array_size \
#$dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$genomicsdbimport_dir $vcfs_dir \
#$genome`
## Set dependency size for next step
#dependency_size=$array_size
#printspace
#
## Create list of GenotypeGVCFs VCFs
#dependency_prefix=$input_prefix
#until [[ -d $vcfs_dir ]] && \
#[[ `checkpoints_exist $dependency_prefix` = "true" ]] && [[ `ls \
#checkpoints/${dependency_prefix}*.checkpoint | wc -l` -eq $dependency_size ]]
#do
#	{ date; echo "Waiting for completion of $dependency_prefix step."; } \
#>> $pipeline_log
#	sleep $sleep_time
#done
#num_vcfs=`ls ${vcfs_dir}/*${genome_base}.vcf.gz | wc -l`
#if [[ $num_vcfs -eq $array_size ]]
#then
#	{ date; echo "Creating $vcf_list of $num_vcfs files."; } >> \
#$pipeline_log
#	ls $vcfs_dir/*${genome_base}.vcf.gz > $vcf_list
#	if [[ `cat $vcf_list | wc -l` -ne $array_size ]]
#	then
#		{ date; echo "Error - incorrect number of files \
#(`cat $vcf_list | wc -l`/${array_size}) in ${vcf_list}. Exiting..."; } >> \
#$pipeline_log
#		exit 1
#	fi
#else
#	{ date; echo "Error - incorrect number of files \
#(${num_vcfs}/${array_size}) detected in ${vcfs_dir}. $vcf_list not created. \
#Exiting..."; } >> $pipeline_log
#	exit 1
#fi
#printspace
#
## Run GATK4 SortVcf on GenotypeGVCFs VCFs
## Depend start upon last job step
#dependency=$jobid
#dependency_prefix=$input_prefix
#input_sbatch=${scripts_dir}sort_vcf.sbatch
#input_prefix=`get_prefix $input_sbatch`
#jobid=`pipeliner --array $array_size \
#$dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$vcfs_dir $qc_dir \
#$genome $vcf_list`
## Set dependency size for next step
#dependency_size=$array_size
#printspace
#
## Overwrite index of VCF files with sorted index
## Depend start upon last job step
#dependency_prefix=$input_prefix
#until [[ `checkpoints_exist $dependency_prefix` = "true" ]] && [[ `ls \
#checkpoints/${dependency_prefix}*.checkpoint | wc -l` -eq $dependency_size ]]
#do
#	{ date; echo "Waiting for completion of $dependency_prefix step."; } \
#>> $pipeline_log
#	sleep $sleep_time
#done
#num_vcfs=`ls ${vcfs_dir}/*${genome_base}.sorted.vcf.gz | wc -l`                                      
#if [[ $num_vcfs -eq $array_size ]]                                              
#then
#	{ date; echo "Creating $vcf_list of $num_vcfs files."; } \
#>> $pipeline_log
#	ls $vcfs_dir/*${genome_base}.sorted.vcf.gz > $vcf_list
#	if [[ `cat $vcf_list | wc -l` -ne $array_size ]]
#	then
#		{ date; echo "Error - incorrect number of files \
#(`cat $vcf_list | wc -l`/${array_size}) in ${vcf_list}. Exiting..."; } >> \
#$pipeline_log
#		exit 1
#	fi
#else
#	{ date; echo "Error - incorrect number of files \
#(${num_vcfs}/${array_size}) detected in ${vcfs_dir}. $vcf_list not updated. \
#Exiting..."; } >> $pipeline_log
#fi
#printspace
#
## Run GATK4 ValidateVariants on GenotypeGVCFs VCFs
## Depend start upon last job step
#dependency=$jobid
#dependency_prefix=$input_prefix
#input_sbatch=${scripts_dir}validate_variants.sbatch
#input_prefix=`get_prefix $input_sbatch`
#iteration=2
#input_prefix=${input_prefix}_${iteration}
#jobid=`pipeliner --array $array_size \
#$dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$vcfs_dir $qc_dir \
#$genome $vcf_list`
## Set dependency size for next step
#dependency_size=$array_size
#printspace
#
## Run GATK4 MergeVcfs
## Depend start upon last job step
#dependency=$jobid
#dependency_prefix=$input_prefix
#input_sbatch=${scripts_dir}merge_vcfs.sbatch
#input_prefix=`get_prefix $input_sbatch`
#jobid=`pipeliner $dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$vcfs_dir $genome $vcf_list`
## Set dependency size for next step
#dependency_size=1
#printspace
#
## Run MultiQC on pipeline QC outputs
## Depend start upon last job step
#dependency=$jobid
#dependency_prefix=$input_prefix
#input_sbatch=${scripts_dir}multiqc.sbatch
#input_prefix=`get_prefix $input_sbatch`
#if [[ $dependency ]]
#then
#	{ date; echo "Running $input_prefix following completion of \
#$dependency_prefix step (jobid ${dependency})."; } >> $pipeline_log
#	jobid=`depend $input_sbatch $input_prefix \
#$dependency \
#$qc_dir $scripts_dir`
#fi
#jobid=`pipeliner $dependency_prefix $dependency_size \
#$sleep_time $input_sbatch $input_prefix \
#$qc_dir $scripts_dir`
## Set dependency size for next step
#dependency_size=1
#printspace
#
