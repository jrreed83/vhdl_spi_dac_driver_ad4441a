# Device Driver for the AD5541A 16-bit DAC

The AD5541A is a 16-bit Digital to Analog converter from Analog Devices and used in a variety of data acqusition and instrumentation applications.  

The datasheet can be found at https://www.analog.com/media/en/technical-documentation/data-sheets/ad5541a.pdf.  

This repository contains a VHDL implementation of the serial interface described in the datasheet.  I implemented it as a Moore
state machine using sequential and combinational logic.

Parts of OSVVM (Open Source VHDL Verification Methodology) were used to implement a self-checking testbench.  A simple A/D model is used
to verify that the data written to the SPI clock, data, and chip-select lines is correct.  I also used assertions to verify that timing constraints
described in the datasheet's timing diagram are satisfied.  



## Features 

## Instructions 

1. Analyze, elaborate and run the project.  

```sh
make 
```

2. View the waveform file under gtkwave.

```sh 
make view
```


