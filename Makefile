ASM=nasm
CC=gcc
OBJ=objcopy
SRC_DIR=src
BUILD_DIR=build

.PHONY: all always bootloader image clean

all: bootloader image

bootloader:  always
	$(ASM) $(SRC_DIR)/boot.asm -f bin -o $(BUILD_DIR)/boot.bin
	$(CC) $(SRC_DIR)/boot.c -o $(BUILD_DIR)/boot2.tmp
	$(OBJ) -O binary $(BUILD_DIR)/boot2.tmp $(BUILD_DIR)/boot2.bin

clean:
	rm -rf $(BUILD_DIR)

always:
	mkdir -p build

image: bootloader
	dd if=/dev/zero of=$(BUILD_DIR)/image.img bs=512 count=2880
	mkfs.fat -F 12 -n "TestOS" $(BUILD_DIR)/image.img
	dd if=$(BUILD_DIR)/boot.bin of=$(BUILD_DIR)/image.img conv=notrunc
	mcopy -i $(BUILD_DIR)/image.img $(BUILD_DIR)/boot2.bin
