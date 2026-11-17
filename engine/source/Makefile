
PROGRAM := alouette
SOURCES := $(filter-out $(PROGRAM).pas,$(wildcard *.pas))
UNITS := temp

PC := fpc
PFLAGS := -Mobjfpc -Sh

ifdef DEBUG
PFLAGS += -ghl
PFLAGS += -Sa
else
PFLAGS += -O3 -CX -XX -Xs
endif

PFLAGS += -FU$(UNITS)
PFLAGS += -FE..

PFLAGS += -vq
PFLAGS += -vm5036,5037,5059,5090

$(PROGRAM): $(PROGRAM).pas $(SOURCES) $(UNITS)
	$(PC) $(PFLAGS) $<

$(UNITS):
	$(info Create directory $(UNITS))
	mkdir $@

clean:
	rm -fv $(UNITS)/*.o $(UNITS)/*.ppu *.bak *.log

distclean: clean
	rm -fv ../$(PROGRAM)
