ASM=nasm
ASMFLAGS=-f obj
CC=gcc
CC16=/opt/watcom/binl/wcc
CFLAGS16=-4 -d3 -s -wx -ms -zl -zq
LD16=/opt/watcom/binl/wlink
OBJ=objcopy
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
	$(CC) $(SRC_DIR)/boot.c -o $(BUILD_DIR)/bootc.o
	$(OBJ) -O binary $(BUILD_DIR)/bootc.o $(BUILD_DIR)/bootc.bin
	#$(BUILD_DIR)/stage2.bin: $(OBJECTS_ASM) $(OBJECTS_C)
	#        $(LD16) NAME $(BUILD_DIR)/boot2.bin FILE \{ $(OBJECTS_ASM) $(OBJECTS_C) \} OPTION MAP=$(BUILD_DIR)/boot2.map @linker.lnk
	#        
	#$(BUILD_DIR)/%.obj: %.c always
	#        $(CC16) $(CFLAGS16) -fo=$@ $<
	#
	#$(BUILD_DIR)/%.obj: %.asm always
	#        $(ASM) $(ASMFLAGS) -o $@ $<
	
clean:
	rm -rf $(BUILD_DIR)

always:
	mkdir -p build

image: bootloader
	dd if=/dev/zero of=$(BUILD_DIR)/image.img bs=512 count=2880
	mkfs.fat -F 12 -n "TESTOS" $(BUILD_DIR)/image.img
	dd if=$(BUILD_DIR)/boot.bin of=$(BUILD_DIR)/image.img conv=notrunc
	mcopy -i $(BUILD_DIR)/image.img $(BUILD_DIR)/boot2.bin "::boot.bin"
	mcopy -i $(BUILD_DIR)/image.img $(BUILD_DIR)/bootc.bin "::bootc.bin"
