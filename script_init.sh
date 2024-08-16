#!/bin/bash

# Print date and time
date
echo

# Wrapper around sourcing a file
source_file () {
  if [[ -a "$1" ]]
  then
    source "$1"
  else
    echo "Error on source of $1"
    exit 1
  fi
}

# Extract job name from script
if [[ -z "${SLURM_JOB_NAME}" ]]
then
  job_name="$(basename "$0" | sed 's/\..*//g')"
else
  job_name="${SLURM_JOB_NAME}"
fi

# Load conda
cond=~/.conda_for_sbatch.sh
if [[ -a "$cond" ]]
then
  source "$cond"
else
  echo "Error on source of $cond"
  exit 1
fi

# Scripts directory
scripts_dir_name="/home1/kdeweese/scripts/s-latissima-organelles"
[[ -d $scripts_dir_name ]] && scripts_dir="${scripts_dir_name}/"

# Environments for required packages
R_mod_file="modules_for_Rscript.txt"
mapfile -t R_mods < <(cat "${scripts_dir}${R_mod_file}")
load_R_mods="module load ${R_mods[*]}"