#!/bin/bash

# Run this script to start four jobs on your cluster.
# You need to create a singularity / apptainer mandel_node.sif file first.

qsub -N mdl1 mandel.qsub
sleep 2

qsub -N mdl2 mandel.qsub
sleep 2

qsub -N mdl3 mandel.qsub
sleep 2

qsub -N mdl4 mandel.qsub
