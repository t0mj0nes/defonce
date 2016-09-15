# makefile do demonstrate using PPP
# PPP output files, by default are named
#
#    under + input file name - .ppp
#
# So
#
# dac_sine_wave.c.ppp => _dac_sine_wave.c
#
# You can override the output file name using -o option

BIN     = ../bin
INC     = ../inc
PPP     = perl $(BIN)/ppp.pl
DUMMY   = _do_not_execute._delete_
GCC     = gcc -o $(DUMMY)
HEADER  = $(INC)/_dac.h

all: _dac_sine_wave.c
	$(GCC) _dac_sine_wave.c


_dac_sine_wave.c: dac_sine_wave.c.ppp
	cd ../inc && $(MAKE)    
	$(PPP) dac_sine_wave.c.ppp

clean:
	cd ../inc && $(MAKE) clean
	rm -rf _*
