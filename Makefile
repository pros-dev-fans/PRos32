include cfg/Makefile.header

CFLAGS += -I./include 
LDFLAGS += -Ttext 0

VERSION_H := include/generated/version.h
VERSION_STRING := $(VERSION_MAJOR).$(VERSION_MINOR).$(VERSION_PATCH)$(VERSION_SUFFIX)
BADGE_VERSION := $(shell echo $(VERSION_STRING) | sed 's/-/--/g')

.PHONY: all clean boot version.h init drivers fs kernel_ kernel image hdd_image

all: hdd_image

boot:
	@make -C boot/

init: version.h
	@echo "$(ESC_GREEN)Compiling init..$(ESC_END)"
	@mkdir -p build/
	@$(CC) $(CFLAGS) -c init/main.c -o build/init.o

drivers:
	@for f in $(wildcard drivers/cmos/*.c); do \
		obj=$$(echo "$$f" | tr '/' '_' | sed 's/\.c$$/.o/'); \
		echo "$(ESC_GREEN)Compiling CMOS driver..$(ESC_END) $(ESC_BLUE)$$f$(ESC_END)"; \
		$(CC) -c $(CFLAGS) $$f -o build/$$obj; \
	done
	@for f in $(wildcard drivers/keyboard/*.c); do \
		obj=$$(echo "$$f" | tr '/' '_' | sed 's/\.c$$/.o/'); \
		echo "$(ESC_GREEN)Compiling keyboard driver..$(ESC_END) $(ESC_BLUE)$$f$(ESC_END)"; \
		$(CC) -c $(CFLAGS) $$f -o build/$$obj; \
	done
	@for f in $(wildcard drivers/vga_tty/*.c); do \
		obj=$$(echo "$$f" | tr '/' '_' | sed 's/\.c$$/.o/'); \
		echo "$(ESC_GREEN)Compiling VGA TTY driver..$(ESC_END) $(ESC_BLUE)$$f$(ESC_END)"; \
		$(CC) -c $(CFLAGS) $$f -o build/$$obj; \
	done
	@for f in $(wildcard drivers/mouse/*.c); do \
		obj=$$(echo "$$f" | tr '/' '_' | sed 's/\.c$$/.o/'); \
		echo "$(ESC_GREEN)Compiling mouse driver..$(ESC_END) $(ESC_BLUE)$$f$(ESC_END)"; \
		$(CC) -c $(CFLAGS) $$f -o build/$$obj; \
	done
	@for f in $(wildcard drivers/pata_pio/*.c); do \
		obj=$$(echo "$$f" | tr '/' '_' | sed 's/\.c$$/.o/'); \
		echo "$(ESC_GREEN)Compiling PATA PIO driver..$(ESC_END) $(ESC_BLUE)$$f$(ESC_END)"; \
		$(CC) -c $(CFLAGS) $$f -o build/$$obj; \
	done

fs:
	@for f in $(wildcard fs/FATs/FAT32/*.c); do \
		obj=$$(echo "$$f" | tr '/' '_' | sed 's/\.c$$/.o/'); \
		echo "$(ESC_GREEN)Compiling FAT32 FS..$(ESC_END) $(ESC_BLUE)$$f$(ESC_END)"; \
		$(CC) -c $(CFLAGS) $$f -o build/$$obj; \
	done

kernel_:
	@for f in $(wildcard kernel/*.c); do \
		obj=$$(echo "$$f" | tr '/' '_' | sed 's/\.c$$/.o/'); \
		echo "$(ESC_GREEN)Compiling kernel piece..$(ESC_END) $(ESC_BLUE)$$f$(ESC_END)"; \
		$(CC) -c $(CFLAGS) $$f -o build/$$obj; \
	done
	@for f in $(wildcard kernel/*.asm); do \
		obj=$$(echo "$$f" | tr '/' '_' | sed 's/\.asm$$/.o/'); \
		echo "$(ESC_GREEN)Assembling kernel piece..$(ESC_END) $(ESC_BLUE)$$f$(ESC_END)"; \
		$(AS) $(ASFLAGS) $$f -o build/$$obj $(NULL); \
	done
	@for f in $(wildcard kernel/memory/*.c); do \
		obj=$$(echo "$$f" | tr '/' '_' | sed 's/\.c$$/.o/'); \
		echo "$(ESC_GREEN)Compiling memory operations..$(ESC_END) $(ESC_BLUE)$$f$(ESC_END)"; \
		$(CC) -c $(CFLAGS) $$f -o build/$$obj; \
	done

kernel: clean boot init drivers fs kernel_
	@$(LD) $(LDFLAGS) --section-start=.text=0x7E00 -o boot/KERNEL_.BIN boot/KERNEL_ENTRY.o build/*.o
	@cp boot/KERNEL_.BIN boot/KERNEL.BIN
	@$(STRIP) boot/KERNEL.BIN
	@$(OBJCOPY) $(OBJCOPYFLAGS) boot/KERNEL.BIN

image: kernel
	@dd if=/dev/zero of=$(IMAGE_NAME) count=2880 bs=512 $(NULL)
	@mkfs.fat -F 12 $(IMAGE_NAME)
	@dd if=boot/MBR.BIN of=$(IMAGE_NAME) conv=notrunc
	@mcopy -i $(IMAGE_NAME) boot/SETUP.BIN ::/
	@mcopy -i $(IMAGE_NAME) boot/KERNEL.BIN ::/

hdd_image:
	@if [ "$(ISGRUBQ)" = "Y" ]; then \
		$(MAKE) hdd_image_grub; \
	elif [ "$(ISGRUBQ)" = "N" ]; then \
		$(MAKE) hdd_image_syslinux; \
	else \
		echo "$(ESC_BLUE)ERROR: ISGRUBQ must be only Y or N!$(ESC_END)"; \
		exit 1; \
	fi

hdd_image_syslinux: image
	@dd if=/dev/zero of=$(HDD_IMAGE) bs=1M count=70 $(NULL)
	@dd if=/dev/zero of=build/1.img bs=1048576 count=33 $(NULL)
	@dd if=/dev/zero of=build/2.img bs=1048576 count=34 $(NULL)
	@parted -s $(HDD_IMAGE) mklabel msdos
	@parted -s $(HDD_IMAGE) mkpart primary 1MiB 34MiB
	@parted -s $(HDD_IMAGE) mkpart primary 35MiB 69MiB
	@parted -s $(HDD_IMAGE) set 1 boot on
	@mkfs.fat -F 32 build/1.img
	@mkfs.ext2 build/2.img
	@mcopy -i build/1.img $(MEMDISK) ::/memdisk
	@mcopy -i build/1.img $(IMAGE_NAME) ::/fd.img
	@mcopy -i build/1.img cfg/syslinux.cfg ::/syslinux.cfg
	@syslinux --install build/1.img
	@dd if=build/1.img of=$(HDD_IMAGE) bs=1M seek=1 conv=notrunc $(NULL)
	@dd if=build/2.img of=$(HDD_IMAGE) bs=1M seek=35 conv=notrunc $(NULL)
	@parted -s $(HDD_IMAGE) unit B print

hdd_image_grub: image
	@echo "$(ESC_PURPLE)Unmounting the image before continuing, you can safely ignore those errors."
	@echo "$(ESC_YELLOW)"
	@make unmount_image
	@echo "$(ESC_END)"
	@dd if=/dev/zero of=$(HDD_IMAGE) bs=1M count=70
	@parted -s $(HDD_IMAGE) mklabel msdos
	@parted -s $(HDD_IMAGE) mkpart primary 1MiB 34MiB
	@parted -s $(HDD_IMAGE) mkpart primary 35MiB 69MiB
	@max=10; \
	for i in `seq 2 $$max`; \
		do \
		if [ -e $(HDD_IMAGE) ]; \
			then break; \
		fi; \
		if [ $$i -eq $$max ]; \
			then exit 1; \
		fi; \
		sleep 0.1; \
	done;
	@LOOP_DEVICE=$$(sudo losetup --find --show $(HDD_IMAGE)); \
	LOOP_NUMBER=$$(basename $$LOOP_DEVICE | sed 's/[^0-9]//g'); \
	MAPPER=/dev/mapper/loop$$LOOP_NUMBER; \
	sudo kpartx -av $$LOOP_DEVICE; \
	max=20; \
	for i in `seq 2 $$max`; \
		do \
		if [ -e $${MAPPER}p1 ] && [ -e $${MAPPER}p2 ]; \
			then break; \
		fi; \
		if [ $$i -eq $$max ]; \
			then exit 1; \
		fi; \
		sleep 0.1; \
	done; \
	sudo mkfs.fat -F 32 $${MAPPER}p1; \
	sudo mkfs.ext2 $${MAPPER}p2; \
	sudo mcopy -i $${MAPPER}p1 $(MEMDISK) ::/; \
	sudo mcopy -i $${MAPPER}p1 $(IMAGE_NAME) ::/fd.img; \
	sudo mkdir -p $(GRUB_MOUNT); \
	sudo mount $${MAPPER}p1 $(GRUB_MOUNT); \
	sudo mkdir -p $(GRUB_MOUNT)/boot/grub/; \
	sudo cp cfg/grub.cfg $(GRUB_MOUNT)/boot/grub/grub.cfg; \
	sudo grub-install \
		--target=i386-pc \
		--boot-directory=$(GRUB_MOUNT)/boot \
		--modules="part_msdos fat" \
		--recheck \
		--force \
		$$LOOP_DEVICE;
	@make unmount_image
	@parted -s $(HDD_IMAGE) unit B print

unmount_image:
	-@LOOP_DEVICE=$$(sudo losetup -j $(HDD_IMAGE) | cut -d: -f1); \
	sudo umount $(GRUB_MOUNT); \
	sudo $(RM) $(GRUB_MOUNT); \
	sudo kpartx -d $$LOOP_DEVICE; \
	sudo losetup -d $$LOOP_DEVICE

config:
	@$(CC) cfg/configurator.c -o configurator $(NULL)
	@chmod +X configurator
	@./configurator

version.h:
	@mkdir -p include/generated
	@echo "// This file is automatically generated, do not touch it. To change the current version, use cfg/Makefile.header" > $(VERSION_H)
	@echo "#ifndef VERSION_H" >> $(VERSION_H)
	@echo "#define VERSION_H" >> $(VERSION_H)
	@echo "" >> $(VERSION_H)
	@echo "#define VERSION_MAJOR $(VERSION_MAJOR)" >> $(VERSION_H)
	@echo "#define VERSION_MINOR $(VERSION_MINOR)" >> $(VERSION_H)
	@echo "#define VERSION_PATCH $(VERSION_PATCH)" >> $(VERSION_H)
	@echo "#define VERSION_SUFFIX \"$(VERSION_SUFFIX)\"" >> $(VERSION_H)
	@echo "#define VERSION_STRING \"$(VERSION_STRING)\"" >> $(VERSION_H)
	@echo "" >> $(VERSION_H)
	@echo "#endif" >> $(VERSION_H)

update_badge:
	@sed -i "s|https://img.shields.io/badge/version-[^?)]*|https://img.shields.io/badge/version-$(BADGE_VERSION)-orange|" readme.md

format:
	@find . -name '*.h' -o -name '*.c' | xargs clang-format -i

clean:
	@$(RM) *.img include/generated/ configurator
	@find . -type f \( -name "*.o" -o -name "*.BIN" \) -exec rm -f {} +
