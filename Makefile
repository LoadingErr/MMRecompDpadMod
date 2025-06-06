BUILD_DIR := build
MOD_TOML := ./mod.toml
LIB_NAME := recomp_achievements_lib
LIB_PREFIX := lib
ASSETS_EXTRACTED_DIR ?= assets_extracted
ASSETS_INCLUDE_DIR ?= assets_extracted/assets
# Allow the user to specify the compiler and linker on macOS
# as Apple Clang does not support MIPS architecture
ifeq ($(OS),Windows_NT)
CC      := clang
LD      := ld.lld
OFFLINE_BUILD_PLATFORM_FLAGS := -s
OFFLINE_BUILD_PLATFORM_EXT := dll
else ifneq ($(shell uname),Darwin)
CC      := clang
LD      := ld.lld
OFFLINE_BUILD_PLATFORM_FLAGS := -ldl -fPIC
OFFLINE_BUILD_PLATFORM_EXT := so
else
CC      ?= clang
LD      ?= ld.lld
OFFLINE_BUILD_PLATFORM_FLAGS := -fPIC
OFFLINE_BUILD_PLATFORM_EXT := dylib
endif

# Extlib Building Info:
# (has to be here so python can use it.)

ifeq ($(OS),Windows_NT)
PYTHON_EXEC ?= python
else
PYTHON_EXEC ?= python3
endif

PYTHON_FUNC_MODULE := make_python_functions
define call_python_func
	$(PYTHON_EXEC) -c "import $(PYTHON_FUNC_MODULE); $(PYTHON_FUNC_MODULE).ModInfo(\"$(MOD_TOML)\", \"$(BUILD_DIR)\").$(1)($(2))"
endef

define get_python_func
$(shell $(PYTHON_EXEC) -c "import $(PYTHON_FUNC_MODULE); $(PYTHON_FUNC_MODULE).ModInfo(\"$(MOD_TOML)\", \"$(BUILD_DIR)\").$(1)($(2))")
endef

define get_python_val
$(shell $(PYTHON_EXEC) -c "import $(PYTHON_FUNC_MODULE); print($(PYTHON_FUNC_MODULE).ModInfo(\"$(MOD_TOML)\", \"$(BUILD_DIR)\").$(1))")
endef

# Recomp Tools Building Info:
N64RECOMP_DIR := N64Recomp
N64RECOMP_BUILD_DIR := $(N64RECOMP_DIR)/build
RECOMP_MOD_TOOL := $(N64RECOMP_BUILD_DIR)/RecompModTool
OFFLINE_MOD_TOOL := $(N64RECOMP_BUILD_DIR)/OfflineModRecomp

# Mod Building Info:

MOD_FILE := $(call get_python_func,get_mod_file,)
$(info MOD_FILE = $(MOD_FILE))
MOD_ELF  := $(call get_python_func,get_mod_elf,)
$(info MOD_ELF = $(MOD_ELF))

MOD_SYMS := $(BUILD_DIR)/mod_syms.bin
MOD_BINARY := $(BUILD_DIR)/mod_binary.bin
ZELDA_SYMS := Zelda64RecompSyms/mm.us.rev1.syms.toml
OFFLINE_C_OUTPUT := $(BUILD_DIR)/mod_offline.c
LDSCRIPT := mod.ld
CFLAGS   := -target mips -mips2 -mabi=32 -O2 -G0 -mno-abicalls -mno-odd-spreg -mno-check-zero-division \
			-fomit-frame-pointer -ffast-math -fno-unsafe-math-optimizations -fno-builtin-memset \
			-Wall -Wextra -Wno-incompatible-library-redeclaration -Wno-unused-parameter -Wno-unknown-pragmas -Wno-unused-variable \
			-Wno-missing-braces -Wno-unsupported-floating-point-opt -Werror=section
CPPFLAGS := -nostdinc -D_LANGUAGE_C -DMIPS -DF3DEX_GBI_2 -DF3DEX_GBI_PL -DGBI_DOWHILE -I include -I include/mod -I include/dummy_headers \
			-I mm-decomp/include -I mm-decomp/src -I mm-decomp/extracted/n64-us -I mm-decomp/include/libc \
			-I assets_extracted -I assets_extracted/assets -I assets_extracted/assets/assets
LDFLAGS  := -nostdlib -T $(LDSCRIPT) -Map $(BUILD_DIR)/mod.map --unresolved-symbols=ignore-all --emit-relocs -e 0 --no-nmagic

OFFLINE_BUILD_FLAGS := -shared -I ./offline_build $(OFFLINE_BUILD_PLATFORM_FLAGS)

C_SRCS := $(wildcard src/*.c)
C_OBJS := $(addprefix $(BUILD_DIR)/, $(C_SRCS:.c=.o))
C_DEPS := $(addprefix $(BUILD_DIR)/, $(C_SRCS:.c=.d))

# General Recipes:
all: nrm runtime

runtime:
	$(call call_python_func,copy_to_runtime_dir,)

# Mod Recipes:
nrm: $(MOD_FILE)

$(MOD_FILE): $(RECOMP_MOD_TOOL) $(MOD_ELF) 
	$(RECOMP_MOD_TOOL) $(MOD_TOML) $(BUILD_DIR)

offline: nrm
	$(OFFLINE_MOD_TOOL) $(MOD_SYMS) $(MOD_BINARY) $(ZELDA_SYMS) $(OFFLINE_C_OUTPUT)
	$(CC) $(OFFLINE_BUILD_FLAGS) -o $(MOD_FILE:.nrm=.$(OFFLINE_BUILD_PLATFORM_EXT)) $(OFFLINE_C_OUTPUT)

elf: $(MOD_ELF) 

$(BUILD_DIR) $(BUILD_DIR)/src $(N64RECOMP_BUILD_DIR):
ifeq ($(OS),Windows_NT)
	mkdir $(subst /,\,$@)
else
	mkdir -p $@
endif

$(MOD_ELF): $(C_OBJS) $(LDSCRIPT) | $(BUILD_DIR) $(BUILD_DIR)/src $(ASSETS_INCLUDE_DIR)
	$(LD) $(C_OBJS) $(LDFLAGS) -o $@

$(C_OBJS): $(BUILD_DIR)/%.o : %.c | $(BUILD_DIR) $(BUILD_DIR)/src $(ASSETS_INCLUDE_DIR)
	$(CC) $(CFLAGS) $(CPPFLAGS) $< -MMD -MF $(@:.o=.d) -c -o $@

$(ASSETS_INCLUDE_DIR):
	$(call call_python_func,create_asset_archive,\"$(ASSETS_INCLUDE_DIR)\")

# Recomp Tools Recipes:
$(RECOMP_MOD_TOOL): $(N64RECOMP_BUILD_DIR) 
	cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -S $(N64RECOMP_DIR) -B $(N64RECOMP_BUILD_DIR)
	cmake --build $(N64RECOMP_BUILD_DIR)

# Misc Recipes:
clean:
ifeq ($(OS),Windows_NT)
	- rmdir "$(BUILD_DIR)" /s /q
	- rmdir "$(N64RECOMP_BUILD_DIR)" /s /q
	- rmdir "$(ASSETS_EXTRACTED_DIR)" /s /q
else
	- rm -rf $(BUILD_DIR)
	- rm -rf $(N64RECOMP_BUILD_DIR)
	- rm -rf $(ASSETS_EXTRACTED_DIR)
endif

-include $(C_DEPS)

.PHONY: all runtime nrm offline clean
