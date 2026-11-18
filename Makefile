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
	$(MAKE) -C engine

temp:
	mkdir -p $@

ICON_SOURCE := images/bftc/bb.png

icon: tools/makeicon.pas tools/win3icon.pas
	mkdir -p temp/tools
	fpc -vq -FUtemp/tools -FEtemp/tools tools/makeicon.pas
	temp/tools/makeicon $(ICON_SOURCE) images/pixelchess.ico images/icon.png 3

ifneq ($(OS),Windows_NT)
UNAME_S := $(shell uname -s)
endif

ifneq ($(UNAME_S),Linux)
desktop:
	$(error The desktop target is only supported on Linux)
else
DESKTOP_DIR := $(shell xdg-user-dir DESKTOP 2>/dev/null || echo $(HOME)/Desktop)
DESKTOP_FILE := $(DESKTOP_DIR)/$(TARGET).desktop

desktop: $(TARGET)
	printf '%s\n' \
	  '[Desktop Entry]' \
	  'Type=Application' \
	  'Name=Pixel Chess' \
	  'Comment=Pixel-art chess game' \
	  'Exec="$(CURDIR)/$(TARGET)"' \
	  'Path=$(CURDIR)' \
	  'Icon=$(CURDIR)/images/icon.png' \
	  'Terminal=false' \
	  'Categories=Game;BoardGame;' \
	  > "$(DESKTOP_FILE)"
	chmod +x "$(DESKTOP_FILE)"
	-gio set "$(DESKTOP_FILE)" metadata::trusted true 2>/dev/null
endif

clean:
	rm -rf temp $(TARGET)
	$(MAKE) -C engine/source distclean

.PHONY: all alouette clean desktop icon
