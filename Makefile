TARGET := pixelchess

PFLAGS := -Mobjfpc -Sh
PFLAGS += -Fu../sdl3-for-pascal/units/
PFLAGS += -Fusource/chess/
PFLAGS += -FE.
PFLAGS += -vq
PFLAGS += -FUtemp

all: $(TARGET) alouette

$(TARGET): source/pixelchess.pas source/*.pas source/chess/*.pas | temp
	fpc $(PFLAGS) -o$@ $<

alouette:
	$(MAKE) -C engines/alouette

temp:
	mkdir -p $@

clean:
	rm -rf temp $(TARGET)
	$(MAKE) -C engines/alouette/source distclean

.PHONY: all alouette clean
