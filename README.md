# num_crunch
Distributed number crunching with [Nim](https://nim-lang.org/ "The Nim programming language").

The num_crunch library allows you to write distributed number crunching programs easily.

It takes care of the communication between the server and the individual compute processes (called nodes), so you don't have to worry about it.

The communication is encrypted and heartbeat messages ensure that if one node crashes the server and the other nodes still keep working.

You can also add new nodes while your computation is running. Thus is allows you to add more computational power when needed without restarting the
whole process.

The library is written in the powerful [Nim](https://nim-lang.org/ "The Nim programming language") programming language which allows for easy integration with C code and other programming languages.

Have a look at the Mandelbrot example to see how it works.

## How to use it
You have to provide two data structures and implement some method for them.

1. For the compute node: **NCNodeDataProcessor.** Implement your own data structure based on this one:

    ```nim
    import num_crunch

    type MyStructNode ref object of NCNodeDataProcessor
        data: int32

    method ncInit(self: var MyStructNode, data: seq[byte]) =
        # This method is optionaly and only has to be implemented
        # if needed. It will be called exactly once when the node
        # connects to the server for the first time.

        # Convert the data given by the server to the data type we need:
        let initData = ncFromBytes(data, int32)

        # Assign the data to our struct:
        self.data = initData
    
    method ncProcessData(self: var MyStructNode, inputData: seq[byte]): seq[byte] =
        # This method has to be implemented.
        # It will be called everytime the node connects to the server and asks for
        # new data to be processed by the node.

        # Convert the input data given by the server to the data type we need:
        let data = ncFromBytes(inputData, float64)

        # Do some heavy calculations:
        let value = float64(self.data) * data

        # Convert it back to a stream of bytes for the server:
        let bytes = ncToBytes(value)

        # And just return it:
        return bytes
    ```

2. For the server: **NCServerDataProcessor.** Implement your own data structure based on this one:

    ```nim
    import num_crunch

    type MyStructServer ref object of NCServerDataProcessor
        data: float64

    method ncIsFinished(self: var MyStructServer): bool =
        # This method has to be implemented and tells the server when the
        # compute job is done.
        return self.data > 10

    method ncGetInitData(self: var MyStructServer): seq[byte] =
        # This method is optionally and just returns the initial data for the node.
        # It is called exactly once when the node connects to the server 
        # for the first time.
        return ncToBytes(2.0)

    method ncGetNewData(self: var MyStructServer, n: NCNodeID): seq[byte] =
        # This method has to be implemented and returns the new data
        # that needs to be processed by the given node (node id).
        # The node id should be stored so that when collecting the data
        # the server knows which node has processed which piece of data.
        # It is called everytime the node requests new data to be processed.
        return ncToBytes(3.5)

    method ncCollectData(self: var MyStructServer, n: NCNodeID, data: seq[byte]) =
        # This method has to be implemented and collects the processed data
        # from the given node (ndoe id).
        # It is called every time the node has processed the data and sends it back 
        # to the server.
        self.data = ncFromBytes(data, float64)

    method ncMaybeDeadNode(self: var MyStructServer, n: NCNodeID) =
        # This method has to be implemented and manages a list of registered nodes.
        # If a node misses a heartbeat message this method will be called.
        # The piece of data that the node should have been processed has to be
        # marked as "dirty" or "unprocessed" and should be given to another node.
        discard

    method ncSaveData(self: var MyStructServer) =
        # This method has to be implemented. It will be called when the job is done.
        # Thas is when the method "ncIsFinished()" returns true.
        # It has to save the data onto disk or into a database or somewhere else.
        discard

    ```

There is more work to do for the server side, but the idea is that these methods will be just delegated
(or passed on) to another method of a "smart" data structure that knows how to handle it.
Currently num_crunch provides two such "smart" data structure: NCArray2D and NCFileArray.
More data structures will be added in future versions of this library.
See the Mandelbrot example on how this works in detail.


## FAQ
- Why is it called num_crunch ?
    It stands for "**num**ber **crunch**ing"
    It's also a wordplay: nim -> num

- Can it run on a cluster (HPC) ?
    Yes there is an example batch script for SLURM (sbatch) and Torq / Moab (qsub).

- How does it compare to MPI (OpenMPI) ?
    MPI (message passing interface) is super optimized and has support for C, C++ and Fortran.
    It's faster than num_crunch but less flexible. You can't add more nodes while the program is
    running and if one node crahes the whole program crashes.
    With num_crunch you can add more nodes while your program is running and one node can't crash
    your whole program.

## License
This library is licensed under the MIT license.

