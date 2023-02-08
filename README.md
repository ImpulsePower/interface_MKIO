# MKIO_inteface
One of the many implementations of the MKIO on-board interface (MIL-STD-1553)

## Introduction

В данном проекте реализуется Контроллер
## Software Requirements

* Python 3.6+
* Icarus Verilog + GTKwave

## How is it run?
Running the included testbench requires Python and Icarus Verilog.
## Block-diagram project
![text](../interface_MKIO/doc/Block_diagram.png)
## Structure of project

The structure of the project is shown below:

/rtl:
    mkio.sv             : Top-level module of MKIO interface
    mkio_transmitter.sv : Transmitter of MKIO interface
    mkio_receiver.sv    : Receiver of MKIO interface
    mkio_control.sv     : Controller of the MKIO interface terminal devices
    device3.sv          : Terminal devices with subadress 3
    device5.sv          : Terminal devices with subadress 5
    mem_dev3.sv         : Dual-port memory for terminal device 3
    mem_dev5.sv         : Dual-port memory for terminal device 5
/tb:

## Hardware requerements 
## Documentation

* MIL-STD-1553 Tutorial (in doc)
* МКИО ГОСТ Р 52070-2003 (in doc)
* Разработка контроллера протокола MIL-STD-1553B на ПЛИС [1-4] (Highly recomendded)