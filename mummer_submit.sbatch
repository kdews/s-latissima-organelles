#!/bin/bash
#SBATCH -J mummer
#SBATCH --mem=1g
#SBATCH --time=00:10:00
#SBATCH -o %x_%j.log

ref="$1"
query="$2"
r_base="$(basename "${ref%.*}")"
q_base="$(basename "${query%.*}")"
q_ext="$(basename "${query##*.}")"
base_mum="${r_base}_vs_${q_base}"
mums_file="${base_mum}.mums"

# Activate conda
cond=~/.conda_for_sbatch.sh
if [[ -a "$cond" ]]
then
  source "$cond"
else
  echo "Error on source of $cond"
  exit 1
fi

# Create mums alignment
conda activate mummer
echo "mummer version: $(mummer --version)"
cmd="mummer -mum -L -b -c $ref $query"
echo "$cmd > $mums_file"
$cmd > "$mums_file"
conda deactivate

# Check if there are more reverse hits than forward hits
n_tot="$(cat "$mums_file" | wc -l)"
n_fwd="$(grep -n "^>.*Reverse" $mums_file | awk -F ':' '{print $1}')"
n_rev="$(( n_tot - n_fwd ))"
if (( n_rev > n_fwd ))
then
  # Reverse complement
  q_base="${q_base}_revcomp"
  base_mum="${r_base}_vs_${q_base}"
  mums_file="${base_mum}.mums"
  query_r="${q_base}.${q_ext}"
  echo "Generating reverse complement of query: $query_r"
  conda activate seqtk
  echo "seqtk $(seqtk |& grep -i "version")"
  cmd="seqtk seq -r $query"
  echo "$cmd > $query_r"
  $cmd > "$query_r"
  conda deactivate
  # Recreate mums alignment with revcomp FASTA
  conda activate mummer
  echo "mummer version: $(mummer --version)"
  query="$query_r"
  cmd="mummer -mum -L -b -c $ref $query"
  echo "$cmd > $mums_file"
  $cmd > "$mums_file"
  conda deactivate
fi

# Shift query FASTA to line up with reference (if needed)
shift_coords="${base_mum}_shift.coords"
sed -z "s/Rev.*//g" $mums_file | grep -v ">" | sort -n | head -n1 > "$shift_coords"
r_pos="$(awk '{print $1}' $shift_coords)"
q_pos="$(awk '{print $2}' $shift_coords)"
shift_pos="$(( q_pos - r_pos ))"
if (( shift_pos > 0 ))
then
  echo "Shifting $query by $shift_pos bases"
  q_base="${q_base}_shift_${shift_pos}"
  base_mum="${r_base}_vs_${q_base}"
  mums_file="${base_mum}.mums"
  query_s="${q_base}.${q_ext}"
  cmd="fasta_shift -i $query -p $shift_pos"
  echo "$cmd > $query_s"
  $cmd > "$query_s"
  query="$query_s"
  # Recreate mums alignment with shifted FASTA
  conda activate mummer
  echo "mummer version: $(mummer --version)"
  cmd="mummer -mum -L -b -c $ref $query"
  echo "$cmd > $mums_file"
  $cmd > "$mums_file"
  conda deactivate
fi

# Plot fixed mums
module purge
module load gcc/11.3.0 gnuplot/5.4.3
conda activate mummer
cmd="mummerplot --png --prefix=$base_mum $mums_file"
# cmd="mummerplot --postscript --prefix=$base_mum ${base_mum}.mums"
echo "$cmd"
$cmd
