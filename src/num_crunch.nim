## This module is part of num_crunch: https://github.com/willi-kappler/num_crunch
##
## Written by Willi Kappler, License: MIT
##
## This module just reexports items from other modules.
##
## This nim library allows you to write programs for distrubuted computing.
##
## It consists of two main parts:
##
## 1. The server, this is a classic server application that accepts client
##    connections from the compute nodes processes.
##    The communication is based on HTTP and compressed and encrypted.
##    The server prepares data to be processed for each node and collects
##    all the processed data from the nodes after computation / processing.
##
## 2. The node, this is an application that does the heavy computation.
##    It can run on the same machine as the server, on another machine or on a cluster.
##    Each node sends a heartbeat message to the server. If a node does not send
##    heartbeat messages then the server assumes it that it may be dead and
##    gives the data to another node to process.
##
## There are two corresponding data structures that the user has to inherti from and 
## implement the methods:
##
## 1. NCServerDataProcessor_: this prepares the data, collects the data, initializes the nodes, etc.
##
## 2. NCNodeDataProcessor_: this initializes the node with the given data from the server and 
##    processes the given data from the server and returns the processed data back to the server.
##

import num_crunch/nc_array2d
import num_crunch/nc_common
import num_crunch/nc_config
import num_crunch/nc_file_array
import num_crunch/nc_log
import num_crunch/nc_node
import num_crunch/nc_nodeid
import num_crunch/nc_server


