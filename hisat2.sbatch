#!/bin/bash
#SBATCH --time=1-0
#SBATCH --mem=50g
#SBATCH --cpus-per-task=12

prefix=$1 # sbatch filename without file extensions
indir=$2 # input directory
outdir=$3 # output directory
genome=$4
genome_basename=$(basename -- $genome)
genome_base=`echo $genome_basename | sed 's/\..*//g'`
samples_file=$5
sample_id=`cat $samples_file | sed -n ${SLURM_ARRAY_TASK_ID}p`
# Use realpaths for HISAT2 inputs because directory changes
reads1=`realpath ${indir}/${sample_id}_R1.repaired.fastq.gz`
reads2=`realpath ${indir}/${sample_id}_R2.repaired.fastq.gz`
qc_dir=`realpath $6`
indiv_file=$7
# Define memory per thread for samtools sort
mem_per_thread="$(( 9 * $SLURM_MEM_PER_NODE / \
$SLURM_JOB_CPUS_PER_NODE / 10000 ))G"

## Load HISAT2
#source ~/bin/anaconda3/etc/profile.d/conda.sh
#conda activate hisat2
hisat2 --version
if [[ $? -ne 0 ]]
then
	echo "Error - check HISAT2 installation."
	exit 1
fi

# Create output and QC directory (if needed)
if [[ ! -d $outdir ]]
then    
	mkdir $outdir
fi
if [[ ! -d $qc_dir ]]
then    
	mkdir $qc_dir
fi

printf "Running HISAT2 on 2 read files associated \
with ${sample_id}:
$reads1 and
${reads2}.\n\n"

# Define read groups for SAM headers from input $sample_id
# and input FASTQ file read IDs
# Input sample ID format = UniqueID_SampleID_Sequencer_Barcode_Plate_Lane_Read 
# Create array 'rgs' from $sample_id by splitting on '_'
rgs1=(${sample_id//_/ })
read_id=`zcat $reads1 | head -n1 | awk '{print $1}' | sed 's/@//g'`
rgs2=(${read_id//:/ })
# Index both $sample_id array and read ID array to generate read group values
# Read group ID = {FLOWCELL_BARCODE}.{LANE}
rg_id="${rgs2[2]}.${rgs2[3]}"
echo "Read group ID = ID:${rg_id}"
# Read group SaMple name (SM) = shortened SampleID within input $sample_id (no UniqueID)
rg_sm="${rgs1[1]}"
echo "Read group sample name = SM:${rg_sm}"
echo "$rg_sm" >> $indiv_file
# Read group Platform Unit (PU) = {FLOWCELL_BARCODE}.{LANE}.{SAMPLE_NAME}
rg_pu="${rgs2[2]}.${rgs2[3]}.${rgs1[1]}"
echo "Read group platform unit = PU:${rg_pu}"
# Read group LiBrary identifier = SampleID-UniqueID
rg_lb="${rgs1[1]}-${rgs1[0]}"
echo "Read group library identifier = LB:${rg_lb}"
# Read group PLatform (PL) = ILLUMINA
rg_pl="ILLUMINA"
echo "Read group platform = PL:${rg_pl}"

# Run HISAT2 & pipe output to samtools
cd $outdir
hisat2 -p ${SLURM_CPUS_PER_TASK} --time \
-x $genome_base -1 ${reads1} -2 ${reads2} \
--rg-id=${rg_id} --rg SM:${rg_sm} --rg LB:${rg_lb} \
--rg PU:${rg_pu} --rg PL:${rg_pl} \
--summary-file=${qc_dir}/${sample_id}_${genome_base}.hisat2_rerun.summary | \
samtools sort -b -@ ${SLURM_CPUS_PER_TASK} \
-m ${mem_per_thread} \
-O ${sample_id}_${genome_base}.sorted.bam

# Checkpoint
if [[ $? -eq 0 ]]
then
	cd ..
	if [[ -f ${outdir}/${sample_id}_${genome_base}.sorted.bam ]]
	then
		if [[ ! -d checkpoints ]]
		then
			mkdir checkpoints
		fi
		touch \
checkpoints/${prefix}_${SLURM_ARRAY_TASK_ID}.checkpoint
		exit 0
	else
		printf "Error - alignment file not created \
for ${sample_id}.\n"
		exit 1
	fi
else
	echo "Error - non-zero exit code returned by HISAT2."
	exit 1
fi

