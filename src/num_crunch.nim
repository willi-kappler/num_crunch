## This module is part of num_crunch: https://github.com/willi-kappler/num_crunch
## Written by Willi Kappler, License: MIT
##
## This module just reexports items from other modules.
##
## This nim library allows you to write programs for distrubuted computing.
##
## It consists of two main parts:
##
## 1. The server, this is a classic server application that accepts client
## connections from the compute nodes processes.
## The communication is based on HTTP and compressed and encrypted.
## The server prepares data to be processed for each node and collects
## all the processed data from the nodes after computation / processing.
##
## 2. The node, this is an application that does the heavy computation.
## It can run on the same machine as the server, on another machine or on a cluster.
## Each node sends a heartbeat message to the server. If a node does not send
## heartbeat messages then the server assumes it that it may be dead and
## gives the data to another node to process.
##

import num_crunch/nc_array2d
import num_crunch/nc_common
import num_crunch/nc_config
import num_crunch/nc_file_array
import num_crunch/nc_log
import num_crunch/nc_node
import num_crunch/nc_nodeid
import num_crunch/nc_server


