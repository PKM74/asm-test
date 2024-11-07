ASM=nasm
ASMFLAGS=-f obj
CC=gcc
CC16=/opt/watcom/binl/wcc
CFLAGS16=-4 -d3 -s -wx -ms -zl -zq
LD16=/opt/watcom/binl/wlink
OBJCP=objcopy
OBJCV=objconv
SRC_DIR=src
BUILD_DIR=build


SOURCES_C=$(wildcard *.c)
SOURCES_ASM=$(wildcard *.asm)
OBJECTS_C=$(patsubst %.c, $(BUILD_DIR)//%.obj, $(SOURCES_C))
OBJECTS_ASM=$(patsubst %.asm, $(BUILD_DIR)/%.obj, $(SOURCES_ASM))

.PHONY: all always bootloader image clean

all: bootloader image

bootloader:  always
	$(ASM) $(SRC_DIR)/boot.asm -f bin -o $(BUILD_DIR)/boot.bin
	$(ASM) $(SRC_DIR)/boot2.asm -f bin -o $(BUILD_DIR)/boot2.bin
	
clean:
	rm -rf $(BUILD_DIR)

always:
	mkdir -p build

image: bootloader
	sudo dd if=/dev/zero of=$(BUILD_DIR)/image.img bs=512 count=2880
	mkfs.fat -F 12 -n "TESTOS" $(BUILD_DIR)/image.img
	sudo dd if=$(BUILD_DIR)/boot.bin of=$(BUILD_DIR)/image.img conv=notrunc
	mcopy -i $(BUILD_DIR)/image.img $(BUILD_DIR)/boot2.bin "::boot.bin"
