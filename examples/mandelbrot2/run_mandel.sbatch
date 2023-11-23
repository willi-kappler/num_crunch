#!/usr/bin/env bash
## Run script for num_crunch mandelbrot example
## This can be run on a SLURM based cluster (HPC)

## General configuration options
#SBATCH -J num_crunch_mandel1
#SBATCH -e num_crunch_mandel1%j.error
#SBATCH -o num_crunch_mandel1%j.screen
#SBATCH --mail-user=my_email
#SBATCH --mail-type=ALL

## Machine and CPU configuration
## Number of tasks per job:
#SBATCH -n 1
## Number of nodes:
#SBATCH -N 1

./mandel
