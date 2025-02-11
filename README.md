# Device Driver for the AD5541A 16-bit DAC

The AD5541A is a 16-bit Digital to Analog converter from Analog Devices and used in a variety of data acqusition and instrumentation applications.  

The datasheet can be found at https://www.analog.com/media/en/technical-documentation/data-sheets/ad5541a.pdf.  

This repository contains a VHDL implementation of the serial interface described in the datasheet.  I implemented it as a Moore
state machine using sequential and combinational logic.

With the *Load DAC* line is held low, it uses a fairly standard 3-wire SPI interface to load the internal DAC register: 

* active-low chip-select line
* clock
* serial input data 
 


## Contents

- `dac_ad5541a.vhdl`    : main design
- `dac_ad5541a_tb.vhdl` : main testbench
- `adc_for_dac.vhdl`    : helper module that mimics an A/D converter.

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


