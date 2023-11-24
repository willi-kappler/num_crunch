#!/usr/bin/env bash

# Run script for num_crunch mandelbrot example.
# This can be run on a SLURM based cluster (HPC).

# Start the mandel server first and set its ip / hostname in the configuration file.

# You have to adapt these lines to match your cluster partition, e-mail, etc.
COMMON_OPT="-e mandel_error_%j -o mandel_out_%j --mail-type=ALL --mail-user=my_email -n 1 -N 1"

srun $COMMON_OPT -J mandel1 ./mandel &
sleep 2

srun $COMMON_OPT -J mandel2 ./mandel &
sleep 2

srun $COMMON_OPT -J mandel3 ./mandel &
sleep 2

srun $COMMON_OPT -J mandel4 ./mandel &
