# Configuration
PROJECT := $(notdir $(CURDIR))
BUILD_VARIANTS := clang clang/gtk3 clang/Qt6
BUILD_TYPE := debug
LINK_TYPE := shared
STAGE_DIR := /tmp/stage
MODULES := Core Gfx MyCare

# Find all available build directories
BUILD_DIRS := $(wildcard $(addprefix build/,$(addsuffix /$(BUILD_TYPE)/$(LINK_TYPE),$(BUILD_VARIANTS))))

# Helper function to get module build dir for a specific variant
module_build_dir = ../$1/build/$2/$(BUILD_TYPE)/$(LINK_TYPE)

.PHONY: help clean build stage install nuke-data nuke-generated nuke-build nuke-all nuke-everything
.PHONY: clean-% build-% stage-% install-% push pull push-% pull-%

help:
	@echo "Usage:"
	@echo "  make clean              - Clean current project"
	@echo "  make build              - Build current project"
	@echo "  make stage              - Stage installation to /tmp/stage"
	@echo "  make install            - Install current project (requires sudo)"
	@echo "  make clean-<Module>     - Clean specific module (Core, Gfx, MyCare, or All)"
	@echo "  make build-<Module>     - Build specific module (Core, Gfx, MyCare, or All)"
	@echo "  make stage-<Module>     - Stage specific module (Core, Gfx, MyCare, or All)"
	@echo "  make install-<Module>   - Install specific module (Core, Gfx, MyCare, or All)"
	@echo "  make push MSG=\"msg\"      - Commit and push current project and cmake submodule"
	@echo "  make push-<Module> MSG=\"msg\" - Commit and push specific module (Core, Gfx, MyCare, or All)"
	@echo "  make pull               - Pull current project and cmake submodule"
	@echo "  make pull-<Module>      - Pull specific module (Core, Gfx, MyCare, or All)"
	@echo "  make nuke-data          - Remove all data files"
	@echo "  make nuke-generated     - Remove generated source files"
	@echo "  make nuke-build         - Remove build directories"
	@echo "  make nuke-all           - Remove data, generated, and build"
	@echo "  make nuke-everything    - Complete project removal and re-clone"

# Check if build directory exists
check-build-dir:
	@if [ -z "$(BUILD_DIRS)" ]; then \
		echo "Error: No build directory found. Expected one of:"; \
		for variant in $(BUILD_VARIANTS); do \
			echo "  build/$variant/$(BUILD_TYPE)/$(LINK_TYPE)"; \
		done; \
		exit 1; \
	fi

# Clean targets
clean: check-build-dir
	@for build_dir in $(BUILD_DIRS); do \
		echo "cmake --build $build_dir --target clean"; \
		cmake --build "$build_dir" --target clean || exit 1; \
	done

clean-%: check-build-dir
	@if [ "$*" = "All" ]; then \
		for build_dir in $(BUILD_DIRS); do \
			variant=$(echo $build_dir | sed 's|build/\(.*\)/$(BUILD_TYPE)/$(LINK_TYPE)|\1|'); \
			for module in $(MODULES); do \
				echo "cmake --build $(call module_build_dir,$module,$variant) --target clean"; \
				cmake --build "$(call module_build_dir,$module,$variant)" --target clean || exit 1; \
			done; \
		done; \
	elif echo "$(MODULES)" | grep -q -w "$*"; then \
		for build_dir in $(BUILD_DIRS); do \
			variant=$(echo $build_dir | sed 's|build/\(.*\)/$(BUILD_TYPE)/$(LINK_TYPE)|\1|'); \
			echo "cmake --build $(call module_build_dir,$*,$variant) --target clean"; \
			cmake --build "$(call module_build_dir,$*,$variant)" --target clean || exit 1; \
		done; \
	else \
		echo "Error: Unknown target '$*'. Valid targets: All, $(MODULES)"; \
		exit 1; \
	fi

# Build targets
build: check-build-dir
	@for build_dir in $(BUILD_DIRS); do \
		echo "cmake --build $build_dir --target $(PROJECT)"; \
		cmake --build "$build_dir" --target $(PROJECT) || exit 1; \
	done

build-%: check-build-dir
	@if [ "$*" = "All" ]; then \
		for build_dir in $(BUILD_DIRS); do \
			variant=$(echo $build_dir | sed 's|build/\(.*\)/$(BUILD_TYPE)/$(LINK_TYPE)|\1|'); \
			for module in $(MODULES); do \
				echo "cmake --build $(call module_build_dir,$module,$variant) --target $module"; \
				cmake --build "$(call module_build_dir,$module,$variant)" --target "$module" || exit 1; \
			done; \
		done; \
	elif echo "$(MODULES)" | grep -q -w "$*"; then \
		for build_dir in $(BUILD_DIRS); do \
			variant=$(echo $build_dir | sed 's|build/\(.*\)/$(BUILD_TYPE)/$(LINK_TYPE)|\1|'); \
			echo "cmake --build $(call module_build_dir,$*,$variant) --target $*"; \
			cmake --build "$(call module_build_dir,$*,$variant)" --target "$*" || exit 1; \
		done; \
	else \
		echo "Error: Unknown target '$*'. Valid targets: All, $(MODULES)"; \
		exit 1; \
	fi

# Stage targets
stage: check-build-dir
	@mkdir -p $(STAGE_DIR)
	@for build_dir in $(BUILD_DIRS); do \
		echo "DESTDIR=$(STAGE_DIR) cmake --build $build_dir --target install"; \
		DESTDIR=$(STAGE_DIR) cmake --build "$build_dir" --target install || exit 1; \
	done

stage-%: check-build-dir
	@mkdir -p $(STAGE_DIR)
	@if [ "$*" = "All" ]; then \
		for build_dir in $(BUILD_DIRS); do \
			variant=$(echo $build_dir | sed 's|build/\(.*\)/$(BUILD_TYPE)/$(LINK_TYPE)|\1|'); \
			for module in $(MODULES); do \
				echo "DESTDIR=$(STAGE_DIR) cmake --build $(call module_build_dir,$module,$variant) --target install"; \
				DESTDIR=$(STAGE_DIR) cmake --build "$(call module_build_dir,$module,$variant)" --target install || exit 1; \
			done; \
		done; \
	elif echo "$(MODULES)" | grep -q -w "$*"; then \
		for build_dir in $(BUILD_DIRS); do \
			variant=$(echo $build_dir | sed 's|build/\(.*\)/$(BUILD_TYPE)/$(LINK_TYPE)|\1|'); \
			echo "DESTDIR=$(STAGE_DIR) cmake --build $(call module_build_dir,$*,$variant) --target install"; \
			DESTDIR=$(STAGE_DIR) cmake --build "$(call module_build_dir,$*,$variant)" --target install || exit 1; \
		done; \
	else \
		echo "Error: Unknown target '$*'. Valid targets: All, $(MODULES)"; \
		exit 1; \
	fi

# Install targets
install: check-build-dir
	@for build_dir in $(BUILD_DIRS); do \
		echo "sudo cmake --build $build_dir --target install"; \
		sudo cmake --build "$build_dir" --target install || exit 1; \
	done

install-%: check-build-dir
	@if [ "$*" = "All" ]; then \
		for build_dir in $(BUILD_DIRS); do \
			variant=$(echo $build_dir | sed 's|build/\(.*\)/$(BUILD_TYPE)/$(LINK_TYPE)|\1|'); \
			for module in $(MODULES); do \
				echo "sudo cmake --build $(call module_build_dir,$module,$variant) --target install"; \
				sudo cmake --build "$(call module_build_dir,$module,$variant)" --target install || exit 1; \
			done; \
		done; \
	elif echo "$(MODULES)" | grep -q -w "$*"; then \
		for build_dir in $(BUILD_DIRS); do \
			variant=$(echo $build_dir | sed 's|build/\(.*\)/$(BUILD_TYPE)/$(LINK_TYPE)|\1|'); \
			echo "sudo cmake --build $(call module_build_dir,$*,$variant) --target install"; \
			sudo cmake --build "$(call module_build_dir,$*,$variant)" --target install || exit 1; \
		done; \
	else \
		echo "Error: Unknown target '$*'. Valid targets: All, $(MODULES)"; \
		exit 1; \
	fi

# Nuke targets
nuke-data:
	rm -f ~/Documents/*.mcdb
	rm -rf ~/.MyCare
	rm -rf ~/.HoffSoft/MyCare
	rm -rf ~/.cache/HoffSoft
	rm -rf ~/.cache/MyCare
	rm -rf ~/Library/Caches/HoffSoft/MyCare
	@echo 'data gone'

nuke-generated:
	rm -rf src/generated
	@echo 'generated gone'

nuke-build:
	rm -rf build external out
	@echo 'build gone'

nuke-all: nuke-data nuke-generated nuke-build

nuke-everything:
	@echo -n "Completely remove $(PROJECT)? <Enter> for yes, ^C if not > "
	@read confirm
	cd .. && rm -rf "$(PROJECT)" && \
	git clone --recurse https://$GITOKEN@github.com/ga2k/$(PROJECT).git && \
	cd "$(PROJECT)" && . ./cmake/setup

# Git targets
push:
	@if [ -z "$(MSG)" ]; then \
		echo "Error: Commit message required. Usage: make push MSG=\"your message\""; \
		exit 1; \
	fi
	@if [ -d cmake/.git ]; then \
		cd cmake && \
		git add . && \
		git commit -m "$(MSG)" && \
		git pull && \
		git push && \
		cd ..; \
	fi
	git add .
	git commit -m "$(MSG)"
	git pull
	git push

push-%:
	@if [ -z "$(MSG)" ]; then \
		echo "Error: Commit message required. Usage: make push-<Module> MSG=\"your message\""; \
		exit 1; \
	fi
	@if [ "$*" = "All" ]; then \
		for module in $(MODULES); do \
			echo "Pushing $module..."; \
			if [ -d "../$module/cmake/.git" ]; then \
				cd "../$module/cmake" && \
				git add . && \
				git commit -m "$(MSG)" && \
				git pull && \
				git push && \
				cd ../..; \
			fi; \
			cd "../$module" && \
			git add . && \
			git commit -m "$(MSG)" && \
			git pull && \
			git push && \
			cd ../$(PROJECT) || exit 1; \
		done; \
	elif echo "$(MODULES)" | grep -q -w "$*"; then \
		echo "Pushing $*..."; \
		if [ -d "../$*/cmake/.git" ]; then \
			cd "../$*/cmake" && \
			git add . && \
			git commit -m "$(MSG)" && \
			git pull && \
			git push && \
			cd ../..; \
		fi; \
		cd "../$*" && \
		git add . && \
		git commit -m "$(MSG)" && \
		git pull && \
		git push; \
	else \
		echo "Error: Unknown target '$*'. Valid targets: All, $(MODULES)"; \
		exit 1; \
	fi

pull:
	@if [ -d cmake/.git ]; then \
		cd cmake && git pull && cd ..; \
	fi
	git pull

pull-%:
	@if [ "$*" = "All" ]; then \
		for module in $(MODULES); do \
			echo "Pulling $module..."; \
			if [ -d "../$module/cmake/.git" ]; then \
				cd "../$module/cmake" && git pull && cd ../..; \
			fi; \
			cd "../$module" && git pull && cd ../$(PROJECT) || exit 1; \
		done; \
	elif echo "$(MODULES)" | grep -q -w "$*"; then \
		echo "Pulling $*..."; \
		if [ -d "../$*/cmake/.git" ]; then \
			cd "../$*/cmake" && git pull && cd ../..; \
		fi; \
		cd "../$*" && git pull; \
	else \
		echo "Error: Unknown target '$*'. Valid targets: All, $(MODULES)"; \
		exit 1; \
	fi