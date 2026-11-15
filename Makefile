TARGET := pixelchess

PFLAGS := -Mobjfpc -Sh
PFLAGS += -Fu../sdl3-for-pascal/units/
PFLAGS += -Fusource/chess/
PFLAGS += -FE.
PFLAGS += -vq
PFLAGS += -FUtemp

$(TARGET): source/pixelchess.pas source/*.pas source/chess/*.pas | temp
	fpc $(PFLAGS) -o$@ $<

temp:
	mkdir -p $@

clean:
	rm -rf temp $(TARGET)

.PHONY: clean
