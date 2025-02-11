FLAGS = --std=08 
project= dac_ad5541a
design = $(project).vhdl 
support = adc_for_dac.vhdl
test = $(project)_tb.vhdl
entity = $(project)_tb

stop_time = 50us
time_resolution = 1ns

all:
	# 'analysis'
	ghdl -a $(FLAGS) $(test) $(design) $(support) 
	# 'elaborate'
	ghdl -e $(FLAGS) $(entity) 
	# 'run'
	ghdl -r $(FLAGS) $(entity) --wave=$(entity).ghw --stop-time=$(stop_time)

view:
	gtkwave $(entity).ghw
clean:
	rm *.cf $(entity).ghw
