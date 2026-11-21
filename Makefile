TARGET := pixelchess

PFLAGS := -Mobjfpc -Sh -O2
PFLAGS += -Fu../sdl3-for-pascal/units/
PFLAGS += -Fusource/chess/
PFLAGS += -Fuengine/source/
PFLAGS += -FE.
PFLAGS += -vq
PFLAGS += -FUtemp

all: $(TARGET) alouette

$(TARGET): source/pixelchess.pas source/*.pas source/chess/*.pas engine/source/*.pas | temp
	fpc $(PFLAGS) -o$@ $<

alouette:
	$(MAKE) -C engine

temp temp/tools:
	mkdir $@

temp/tools: | temp

ICON_SOURCE := images/bftc/bb.png

icon: tools/makeicon.pas tools/win3icon.pas | temp/tools
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

ANDROID_SDK ?= $(HOME)/Android/Sdk
ANDROID_NDK ?= $(ANDROID_SDK)/ndk/28.2.13676358
ANDROID_FPC ?= $(HOME)/Applications/lazarus-261121/fpc/bin/x86_64-linux/fpc.sh
SDL_SRC ?= $(HOME)/Documents/sources/SDL
SDL_TTF_SRC ?= $(HOME)/Documents/sources/SDL_ttf
ANDROID_ABI := arm64-v8a
ANDROID_API := 21
ANDROID_LIBS := android/app/libs/$(ANDROID_ABI)
ANDROID_TEMP := temp/android
ANDROID_APK := android/app/build/outputs/apk/debug/app-debug.apk

ANDROID_CMAKE := -G Ninja -DCMAKE_BUILD_TYPE=Release
ANDROID_CMAKE += -DCMAKE_TOOLCHAIN_FILE=$(ANDROID_NDK)/build/cmake/android.toolchain.cmake
ANDROID_CMAKE += -DANDROID_ABI=$(ANDROID_ABI) -DANDROID_PLATFORM=android-$(ANDROID_API) -DANDROID_STL=c++_static

ANDROID_PFLAGS := -Tandroid -Paarch64 -Mobjfpc -Sh -O2
ANDROID_PFLAGS += -Fu../sdl3-for-pascal/units/
ANDROID_PFLAGS += -Fusource/chess/
ANDROID_PFLAGS += -Fuengine/source/
ANDROID_PFLAGS += -Fl$(ANDROID_LIBS)
ANDROID_PFLAGS += -FU$(ANDROID_TEMP)/units
ANDROID_PFLAGS += -vq

android: $(ANDROID_LIBS)/libSDL3.so $(ANDROID_LIBS)/libSDL3_ttf.so $(ANDROID_LIBS)/libmain.so
	cd android && ./gradlew assembleDebug

android-install: android
	$(ANDROID_SDK)/platform-tools/adb install -r $(ANDROID_APK)

$(ANDROID_LIBS) $(ANDROID_TEMP)/units:
	mkdir -p $@

$(ANDROID_LIBS)/libSDL3.so: | $(ANDROID_LIBS)
	cmake -S $(SDL_SRC) -B $(ANDROID_TEMP)/SDL $(ANDROID_CMAKE) -DSDL_TESTS=OFF -DSDL_EXAMPLES=OFF -DSDL_STATIC=OFF
	cmake --build $(ANDROID_TEMP)/SDL
	cp $(ANDROID_TEMP)/SDL/libSDL3.so $@

$(ANDROID_LIBS)/libSDL3_ttf.so: $(ANDROID_LIBS)/libSDL3.so
	cmake -S $(SDL_TTF_SRC) -B $(ANDROID_TEMP)/SDL_ttf $(ANDROID_CMAKE) -DSDL3_DIR=$(CURDIR)/$(ANDROID_TEMP)/SDL -DSDLTTF_VENDORED=ON -DSDLTTF_HARFBUZZ=OFF -DSDLTTF_PLUTOSVG=OFF -DSDLTTF_SAMPLES=OFF
	cmake --build $(ANDROID_TEMP)/SDL_ttf
	cp $(ANDROID_TEMP)/SDL_ttf/libSDL3_ttf.so $@

$(ANDROID_LIBS)/libmain.so: source/pixelchess.pas source/*.pas source/chess/*.pas engine/source/*.pas $(ANDROID_LIBS)/libSDL3.so $(ANDROID_LIBS)/libSDL3_ttf.so | $(ANDROID_TEMP)/units
	$(ANDROID_FPC) $(ANDROID_PFLAGS) -o$@ $<

android-clean:
	rm -rf $(ANDROID_TEMP) android/app/libs
	cd android && ./gradlew clean

.PHONY: all alouette clean desktop icon android android-install android-clean
