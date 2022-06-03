#!/bin/bash

# This is a generic running script. It can run in two configurations:
# Single job mode: pass the python arguments to this script
# Batch job mode: pass a file with first the job tag and second the commands per line

#SBATCH --cpus-per-task=4
#SBATCH --gres=gpu:1
#SBATCH --partition=debug

set -e # fail fully on first line failure

module purge
module load anaconda3

eval "$(conda shell.bash hook)"

# Change this to specify what conda env to use by default
default_conda_env_name="isi"

# Alternatively specify using --conda-env as the first cmdline arg
first_arg=$1
if [ "${first_arg}" = "--conda-env" ] 
then
    shift 1 && conda_env_name=${1} && shift 1
    JOB_CMD="${@}"
else
    conda_env_name="${default_conda_env_name}"
fi


echo "Running on $(hostname)"

if [ -z "$SLURM_ARRAY_TASK_ID" ]
then
    # Not in Slurm Job Array - running in single mode

    JOB_ID=$SLURM_JOB_ID

    # Just read in what was passed over cmdline
    JOB_CMD="${@}"
else
    # In array

    JOB_ID="${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"

    # Get the line corresponding to the task id
    JOB_CMD=$(head -n ${SLURM_ARRAY_TASK_ID} "$1" | tail -1)
fi

# Find what was passed to --job-output-folder
regexp="--job-output-folder\s+(\S+)"
if [[ $JOB_CMD =~ $regexp ]]
then
    JOB_OUTPUT=${BASH_REMATCH[1]}
    JOB_CMD=$(echo $JOB_CMD | sed -E "s/${regexp}//g")
else
    echo "Error: did not find a --job-output-folder argument"
    exit 1
fi

# Check if results exists, if so remove slurm log and skip
if [ -f  "$JOB_OUTPUT/results.json" ]
then
    echo "Results already done - exiting"
    rm "slurm-${JOB_ID}.out"
    exit 0
fi

# Check if the output folder exists at all. We could remove the folder in that case.
if [ -d  "$JOB_OUTPUT" ]
then
    echo "Folder exists, but was unfinished or is ongoing (no results.json)."
    echo "Starting job as usual"
    # It might be worth removing the folder at this point:
    # echo "Removing current output before continuing"
    # rm -r "$JOB_OUTPUT"
    # Since this is a destructive action it is not on by default
else
    # If the folder doesn't exist yet, create it
    mkdir -vp "${JOB_OUTPUT}"
fi

# Activate the environment
conda activate ${conda_env_name}

# Info about conda env for debugging purposes
conda info

# Train the model
srun python $JOB_CMD

# Move the log file to the job folder
mv "slurm-${JOB_ID}.out" "${JOB_OUTPUT}/"
