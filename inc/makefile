# makefile do demonstrate using PPP

PERL    = perl 
HEADER  = _dac.h _defonce.h

all: $(HEADER)

_dac.h:;     perl dac.pl
_defonce.h:; perl defonce.pl

clean:
	rm -rf _*

