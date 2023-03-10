# MKIO_inteface
One of the many implementations of the MKIO on-board interface (MIL-STD-1553)

## Introduction

So, the standard MIL-STD-1553B (MKIO) is intended for use in military avionics, 
but later it began to be used in civilian systems. MIL-STD-1553B communication 
channels have a bus organization. There is one common trunk, and terminal are 
connected to it through galvanic isolation. The number of terminals can be up to 31

All subscribers on the trunk are divided into three types:
* BC is a bus controller. The central device of the system. Sends command words (BC) and 
information data to other subscribers. There can be only one BC on one trunk.
* RT is a remote terminals. One of 31 peripheral devices. It waits for command words 
from the BC, processes them, and sends the response word (RS) back to the BC. Each RT 
has a unique address of 5 bits.
* BM is a bus monitor. Something like a reporting device. Monitors the information in 
the channel. Collects statistics, etc.

This project implements a remote terminal. Let's go

## Software Requirements

* Python 3.6+
* Icarus Verilog + GTKwave

## How is it run?

Running the included testbench requires Python and Icarus Verilog.
To start the simulation, just run the script in the tb folder

## Block-diagram of project

![Block-diagram](/doc/Block_diagram.png)

## Structure of project

The structure of the project is shown below:

/rtl:
* mkio.sv             : Top-level module of MKIO interface
* mkio_transmitter.sv : Transmitter of MKIO interface
* mkio_receiver.sv    : Receiver of MKIO interface
* mkio_control.sv     : Controller of the MKIO interface terminal devices
* device2.sv          : Terminal devices with subadress 2
* device4.sv          : Terminal devices with subadress 4
* mem_dev2.sv         : Dual-port memory for terminal device 2
* mem_dev4.sv         : Dual-port memory for terminal device 4
* enable_sync.sv      : Module for eliminate clock jitter
* reset_sync.sv       : Module for reset synchronizer 

/tb:
* tb_testing.py       : Python script to run a testbench
* test_mkio.sv        : Testbench for top-level module

## Hardware Requirements

* Intel / Altera EP3C25F324C6 
* Total logic elements: 339
* Total registers: 222
* Total pins: 61
* Total memory bits: 1024

## Documentation

* MIL-STD-1553 Tutorial (in doc)
* ???????? ???????? ?? 52070-2003 (in doc)
* ???????????????????? ?????????????????????? ?????????????????? MIL-STD-1553B ???? ???????? [1-4]

# Further plans

* Introduction to the state machine - default states for more correct synthesis in Quartus
* It's necessary to add synthesis constraints
* Eliminate the crutch delay in device2 and device4
* Use one memory design instead of two
* Further redesigning the project to a more current SystemVerilog standard while maintaining support for IcarusVeilog