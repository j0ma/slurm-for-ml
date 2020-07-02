# Slurm for Machine Learners

Many labs have converged on using [Slurm](https://slurm.schedmd.com/documentation.html) for managing their shared compute resources.
It is fairly easy to get going with Slurm, but it quickly gets unintuitive when wanting to run a hyper-parameter search.
In this repo, I provide some scripts to make starting many jobs painless and easy to control.

## Starting a single job

This is easy, but it's here for completeness:

```
sbatch generic.sh train_script.py --dataset CIFAR10 --learning-rate 1e-4
```

You simply pass the arguments you normally pass to `python` to [generic.sh](generic.sh) and it'll start the job for you on Slurm with a gpu and a `conda` environment set up.

## Starting many jobs

For this use case, Slurm has introduced [Job Arrays](https://slurm.schedmd.com/job_array.html).
Slurm assigns separate jobs a simple job array id, which is an integer that starts counting from 1.
This does not map well onto the usual machine learning jobs that requires running over a grid of hyperparameters.

For this use case, I present an easy a flow that:
1) Easily go through a grid of jobs (and skip jobs if you later extend the grid and rerun)
2) Robust against failures (e.g. server crashing, kill jobs mid run etc.)
3) Easily limit parallelism - simply set max number of GPUs to use

The solution involves creating a file with all jobs you want to run (could be created by a Python/Bash script itself).
We then iterate through this file by using the Slurm job array id to index a **line**!
When iterating, we check if a job finished (`results.json` found in the output folder) and skip it if so.

### Step 1:

```
./create_jobs.sh
```

This command creates a job list, with all the jobs we want to run.
There are two requirements: 
1) your command has an `--output_folder` flag which is respected in the code
2) a successful job creates a `results.json` in that folder.

If we later want to add jobs, we can simply update this script, generate new jobs, and slurm will skip jobs that were successfully run before!

### Step 2:

```
./run_file.sh job_list.txt
```

This will start 8 jobs in parallel using Slurm job arrays.
You can easily change the number of jobs run in parallel by editing the top of `run_file.sh`.
It'll check (in `generic.sh`) if a job succeeded before, and skip if that's the case.

## Setup requirements summarised

1. `conda` - by default in the folder `miniconda3` along side these scripts. Change the paths in [generic.sh](generic.sh) to match your setup.
2. Within Python, save your final results to a file called `results.json` so the script can check if the jobs was successful. You can also edit this check for your particular setup (e.g. check for a final model saved).
3. Save your results in the folder specified by `--output_folder`. A suggested job identifier is `<dataset>/lr0.05_bs128`, so it will save all your results in a subfolder called named after your dataset.

Note: [run\_locked.sh](run_locked.sh) might be necessary because `conda` is not thread safe by itself, and calling update multiple times in different processes leads to incorrect behaviour.
If you don't want to update the environment as part of the script, then you can simply skip that line.

I have attempted to comment [generic.sh](generic.sh) as much as possible, so it's easy to see what to change for your Slurm setup!

Happy Slurming!

Let me know if you have any issues with the scripts, or if you see room for improvement. I am happy to accept PRs.

### Useful Commands

Count all GPUs available in partition `normal`:
```
sinfo -N --partition normal -o %G | awk -F ':' '{sum += $3} END {print sum}'
```

Count all GPUs that are part of running jobs in all partitions:
```
squeue -t R --format='%b' --all  | awk -F ':' '{sum += $NF} END {print sum}'
```

Depending on your Slurm setup you will want to tweak the partition (perhaps add a reservation) and maybe not use `--all` in `squeue`.


### Other resources

Check out my other help scripts:
1. [Train a ResNet to 94% accuracy on CIFAR-10 with only 150 lines of PyTorch](https://gist.github.com/y0ast/d91d09565462125a1eb75acc65da1469)
2. [FastMNIST - a drop in replacement for PyTorch' MNIST that avoids unnecessary processing - leading to 2-3x speed up on a **GPU**](https://gist.github.com/y0ast/f69966e308e549f013a92dc66debeeb4)
