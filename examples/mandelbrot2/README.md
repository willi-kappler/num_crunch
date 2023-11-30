In order to run the Mandelbrot example you need to have a working [Nim](https://nim-lang.org/) installation.

In this folder you find a [Singularity](https://sylabs.io/docs/) / [Apptainer](https://apptainer.org/documentation/) definition file.
That creates a container where the clients (nodes) are running:

`sudo singularity build mandel_node.sif mandel_node.def`

Copy that file (`mandel_node.sif`) onto your cluster (HPC).

For the nodes you have to specify the URL of the server (hostname or IP address) in the configuration file (`config.ini`) that also has to be copied to the cluster. And if you use `qsub` you also have to copy over the `mandel.qsub` file.

Then you can use the example batch script `run_mandel_pbs.sh` or `run_mandel_slurm.sh` that you also have to copy to the cluster. Please change the file according to your needs.

Now start the server first on your server machine:

`./mandel --server &`

Then on the cluster you just start the batch script:

`run_mandel_pbs.sh`

or

`run_mandel_slurm.sh`


