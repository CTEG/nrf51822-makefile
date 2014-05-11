#------------ include configuration -------------------------------------------#
include Makefile.config

#------------ common makefile, do not modify ----------------------------------#
DEVICE := NRF51
DEVICESERIES := nrf51

SDK_INCLUDE_PATH = $(SDK_PATH)/Include/
SDK_SOURCE_PATH = $(SDK_PATH)/Source/
TEMPLATE_PATH += $(SDK_SOURCE_PATH)templates/gcc/

ifeq ($(USE_SOFTDEVICE),s110)
	USE_BLE = 1
	SOFTDEVICE = $(wildcard $(SOC_PATH)/$(USE_SOFTDEVICE)_*.hex)
endif
ifeq ($(USE_SOFTDEVICE),s120)
	SOFTDEVICE = $(wildcard $(SOC_PATH)/$(USE_SOFTDEVICE)_*.hex)
	USE_BLE = 1
endif

ifeq ($(LINKER_SCRIPT),)
	ifeq ($(USE_SOFTDEVICE), s110)
		LINKER_SCRIPT = gcc_$(DEVICESERIES)_s110_$(DEVICE_VARIANT).ld
		OUTPUT_FILENAME := $(OUTPUT_FILENAME)_s110_$(DEVICE_VARIANT)
	else
		ifeq ($(USE_SOFTDEVICE), s120)
			LINKER_SCRIPT = gcc_$(DEVICESERIES)_s120_$(DEVICE_VARIANT).ld
			OUTPUT_FILENAME := $(OUTPUT_FILENAME)_s120_$(DEVICE_VARIANT)
		else
			LINKER_SCRIPT = gcc_$(DEVICESERIES)_blank_$(DEVICE_VARIANT).ld
			OUTPUT_FILENAME := $(OUTPUT_FILENAME)_blank_$(DEVICE_VARIANT)
		endif
	endif
else
# Use externally defined settings
endif

# which arch do you use
CPU := cortex-m0

# Toolchain commands
CC       := $(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-gcc
AS       := $(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-as
AR       := $(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-ar -r
LD       := $(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-ld
NM       := $(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-nm
OBJDUMP  := $(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-objdump
OBJCOPY  := $(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-objcopy

MK       := mkdir
RM       := rm -rf

OBJECT_DIRECTORY := _build
LISTING_DIRECTORY := _build
OUTPUT_BINARY_DIRECTORY := _build

# build bare-bone bootloader
C_SOURCE_FILES += system_$(DEVICESERIES).c
ASSEMBLER_SOURCE_FILES += gcc_startup_$(DEVICESERIES).s

# Linker flags
LDFLAGS += -L"$(GNU_INSTALL_ROOT)/arm-none-eabi/lib/armv6-m"
LDFLAGS += -L"$(GNU_INSTALL_ROOT)/lib/gcc/arm-none-eabi/$(GNU_VERSION)/armv6-m"
LDFLAGS += -Xlinker -Map=$(LISTING_DIRECTORY)/$(OUTPUT_FILENAME).map
LDFLAGS += -mcpu=$(CPU) -mthumb -mabi=aapcs -L $(TEMPLATE_PATH) -T$(LINKER_SCRIPT)

# Compiler flags (remove -Werror)
CFLAGS += -mcpu=$(CPU) -mthumb -mabi=aapcs -D$(DEVICE) -D$(BOARD) -D$(TARGET_CHIP) --std=gnu99
CFLAGS += -Wall
CFLAGS += -mfloat-abi=soft
ifdef USE_BLE
CFLAGS += -DBLE_STACK_SUPPORT_REQD
endif

# Assembler flags
ASMFLAGS += -x assembler-with-cpp

INCLUDEPATHS += -I"../"
INCLUDEPATHS += -I"$(SDK_INCLUDE_PATH)"
INCLUDEPATHS += -I"$(SDK_INCLUDE_PATH)gcc"
ifdef USE_BLE
INCLUDEPATHS += -I"$(SDK_INCLUDE_PATH)ble"
INCLUDEPATHS += -I"$(SDK_INCLUDE_PATH)ble/ble_services"
INCLUDEPATHS += -I"$(SDK_INCLUDE_PATH)app_common"
INCLUDEPATHS += -I"$(SDK_INCLUDE_PATH)sd_common"
INCLUDEPATHS += -I"$(SDK_INCLUDE_PATH)$(USE_SOFTDEVICE)"
endif
ifdef USE_EXT_SENSORS
INCLUDEPATHS += -I"$(SDK_INCLUDE_PATH)ext_sensors"
endif

# Sorting removes duplicates
BUILD_DIRECTORIES := $(sort $(OBJECT_DIRECTORY) $(OUTPUT_BINARY_DIRECTORY) $(LISTING_DIRECTORY) )

####################################################################
# Rules                                                            #
####################################################################

C_SOURCE_FILENAMES = $(notdir $(C_SOURCE_FILES) )
ASSEMBLER_SOURCE_FILENAMES = $(notdir $(ASSEMBLER_SOURCE_FILES) )

# Make a list of source paths
C_SOURCE_PATHS += ../ $(SDK_SOURCE_PATH) $(TEMPLATE_PATH) $(wildcard $(SDK_SOURCE_PATH)*/)
ifdef USE_BLE
C_SOURCE_PATHS += $(wildcard $(SDK_SOURCE_PATH)ble/*/)
endif
ifdef USE_EXT_SENSORS
C_SOURCE_PATHS += $(wildcard $(SDK_SOURCE_PATH)ext_sensors/*/)
endif
ASSEMBLER_SOURCE_PATHS = ../ $(SDK_SOURCE_PATH) $(TEMPLATE_PATH) $(wildcard $(SDK_SOURCE_PATH)*/)

C_OBJECTS = $(addprefix $(OBJECT_DIRECTORY)/, $(C_SOURCE_FILENAMES:.c=.o) )
ASSEMBLER_OBJECTS = $(addprefix $(OBJECT_DIRECTORY)/, $(ASSEMBLER_SOURCE_FILENAMES:.s=.o) )

# Set source lookup paths
vpath %.c $(C_SOURCE_PATHS)
vpath %.s $(ASSEMBLER_SOURCE_PATHS)

# Include automatically previously generated dependencies
-include $(addprefix $(OBJECT_DIRECTORY)/, $(COBJS:.o=.d))

### Targets
debug:    CFLAGS += -DDEBUG -g3 -O0
debug:    ASMFLAGS += -DDEBUG -g3 -O0
debug:    $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).bin $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).hex

.PHONY: release
release:  clean
release:  CFLAGS += -DNDEBUG -O3
release:  ASMFLAGS += -DNDEBUG -O3
release:  $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).bin $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).hex

echostuff:
	@echo C_OBJECTS: [$(C_OBJECTS)]
	@echo C_SOURCE_FILES: [$(C_SOURCE_FILES)]

## Create build directories
$(BUILD_DIRECTORIES):
	$(MK) $@

## Create objects from C source files
$(OBJECT_DIRECTORY)/%.o: %.c
# Build header dependencies
	$(CC) $(CFLAGS) $(INCLUDEPATHS) -M $< -MF "$(@:.o=.d)" -MT $@
# Do the actual compilation
	$(CC) $(CFLAGS) $(INCLUDEPATHS) -c -o $@ $<

## Assemble .s files
$(OBJECT_DIRECTORY)/%.o: %.s
	$(CC) $(ASMFLAGS) $(INCLUDEPATHS) -c -o $@ $<

## Link C and assembler objects to an .out file
$(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).out: $(BUILD_DIRECTORIES) $(C_OBJECTS) $(ASSEMBLER_OBJECTS) $(LIBRARIES)
	$(CC) $(LDFLAGS) $(C_OBJECTS) $(ASSEMBLER_OBJECTS) $(LIBRARIES) -o $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).out

## Create binary .bin file from the .out file
$(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).bin: $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).out
	$(OBJCOPY) -O binary $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).out $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).bin

## Create binary .hex file from the .out file
$(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).hex: $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).out
	$(OBJCOPY) -O ihex $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).out $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).hex

## Default build target
.PHONY: all
all: clean debug

clean:
	rm -rf $(OUTPUT_BINARY_DIRECTORY)
	rm -f *.jlink
	rm -f JLink.log
	rm -f .gdbinit

#############################################
# flash options using JLink from segger.com #
#############################################
HEX = $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).hex
ELF = $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).out
BIN = $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).bin

FLASH_START_ADDRESS = $(shell $(OBJDUMP) -h $(ELF) -j .text | grep .text | awk '{print $$4}')
ifdef SEGGER_SERIAL
	JLINKEXE_OPTION = -SelectEmuBySn $(SEGGER_SERIAL)
	JLINKGDBSERVER_OPTION = -select USB=$(SEGGER_SERIAL)
endif

JLINK_OPTIONS = -device nrf51822 -if swd -speed 1000
JLINK = -$(PROG_ROOT)/JLinkExe $(JLINK_OPTIONS) $(JLINKEXE_OPTION)
JLINKGDBSERVER = $(PROG_ROOT)/JLinkGDBServer $(JLINK_OPTIONS) $(JLINKGDBSERVER_OPTION)
# program softdevice
SOFTDEVICE_OUTPUT = $(OUTPUT_BINARY_DIRECTORY)/$(notdir $(SOFTDEVICE))
MAIN_BIN = $(SOFTDEVICE_OUTPUT:.hex=_mainpart.bin)
UICR_BIN = $(SOFTDEVICE_OUTPUT:.hex=_uicr.bin)

# (1) flash device
flash: flash.jlink
	$(JLINK) flash.jlink

flash.jlink:
	printf "r\nloadbin $(BIN) $(FLASH_START_ADDRESS)\nr\ng\nexit\n" > flash.jlink

# (2) flash device with softcore S110/S120
flash-softdevice: erase-all flash-softdevice.jlink
ifndef SOFTDEVICE
	$(error "You need to set the SOFTDEVICE command-line parameter to a path (without spaces) to the softdevice hex-file")
endif
	# Convert from hex to binary. Split original hex in two to avoid huge (>250 MB) binary file with just 0s.
	$(OBJCOPY) -Iihex -Obinary --remove-section .sec3 $(SOFTDEVICE) $(MAIN_BIN)
	$(OBJCOPY) -Iihex -Obinary --remove-section .sec1 --remove-section .sec2 $(SOFTDEVICE) $(UICR_BIN)
	$(JLINK) flash-softdevice.jlink

flash-softdevice.jlink:
	# Write to NVMC to enable write. Write mainpart, write UICR. Assumes device is erased.
	printf "w4 4001e504 1\nloadbin \"$(MAIN_BIN)\" 0\nloadbin \"$(UICR_BIN)\" 0x10001000\nr\ng\nexit\n" > flash-softdevice.jlink

recover: recover.jlink erase-all.jlink pin-reset.jlink
	$(JLINK) recover.jlink
	$(JLINK) erase-all.jlink
	$(JLINK) pin-reset.jlink

recover.jlink:
	printf "si 0\nt0\nsleep 1\ntck1\nsleep 1\nt1\nsleep 2\nt0\nsleep 2\nt1\nsleep 2\nt0\nsleep 2\nt1\nsleep 2\nt0\nsleep 2\nt1\nsleep 2\nt0\nsleep 2\nt1\nsleep 2\nt0\nsleep 2\nt1\nsleep 2\nt0\nsleep 2\nt1\nsleep 2\ntck0\nsleep 100\nsi 1\nr\nexit\n" > recover.jlink

pin-reset.jlink:
	printf "w4 40000544 1\nr\nexit\n" > pin-reset.jlink

pin-reset: pin-reset.jlink
	$(JLINK) pin-reset.jlink

reset: reset.jlink
	$(JLINK) reset.jlink

reset.jlink:
	printf "r\ng\nexit\n" > reset.jlink

erase-all: erase-all.jlink
	$(JLINK) erase-all.jlink

erase-all.jlink:
	# Write to NVMC to enable erase, do erase all, wait for completion. reset
	printf "w4 4001e504 2\nw4 4001e50c 1\nsleep 100\nr\nexit\n" > erase-all.jlink

startdebug: debug-gdbinit
	$(TERMINAL) "$(JLINKGDBSERVER) -port $(GDB_PORT_NUMBER)"
	sleep 1
	$(TERMINAL) "$(GDB) $(ELF)"

debug-gdbinit:
	printf "target remote localhost:$(GDB_PORT_NUMBER)\nbreak main\n" > .gdbinit

.PHONY: flash flash-softdevice erase-all startdebug


