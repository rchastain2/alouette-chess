TARGET := pixelchess

PFLAGS := -Mobjfpc -Sh
PFLAGS += -Fu../sdl3-for-pascal/units/
PFLAGS += -Fusource/chess/
PFLAGS += -Fusource/themes/
PFLAGS += -Fusource/engine/
PFLAGS += -FE.
PFLAGS += -vq
PFLAGS += -FUtemp

$(TARGET): source/pixelchess.pas source/themes/*.pas source/engine/*.pas source/chess/*.pas | temp
	fpc $(PFLAGS) -o$@ $<

temp:
	mkdir -p $@

clean:
	rm -rf temp $(TARGET)

.PHONY: clean
