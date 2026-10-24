VERSION := 4.1.0
# MCA build driver for HoffSoft Libs (Core + Gfx) and MyCare. Libs is built once per GUI toolkit
# (gtk | qt); MyCare itself is toolkit-neutral (libmycare.so links only Core), so it is built once, under
# the first selected toolkit's preset, and the launcher picks the toolkit's Gfx at run time. Linux only. The same file works from Libs/ and from MyCare/ (they are siblings).
#
# This file is maintained in the shared CMakeFiles repo; each project keeps a copy that
# `make update` keeps current (see the update mechanism below). Edit it in CMakeFiles/.
#
#   make help        full target list
#   make all         configure + build + stage, Libs then app, both toolkits
#
# Order matters and is handled: the app needs the *staged* Core of its toolkit's tree (and the
# run needs each toolkit's staged Gfx), so Libs always goes first. The build is deliberately serial (.NOTPARALLEL): module compiles peak at
# 2-4 GB each, and the ordering above is not expressed per-file.

SHELL := /bin/bash
.NOTPARALLEL:
.DEFAULT_GOAL := help

ifneq ($(shell uname -s),Linux)
$(error This Makefile drives the Linux GTK/Qt builds only; use cmake --preset directly elsewhere)
endif

# ---------------------------------------------------------------------------------------------
# Settings (override on the command line or in the environment)
# ---------------------------------------------------------------------------------------------
BT           ?= debug
TK           ?= both
JOBS         ?= $(shell nproc 2>/dev/null || echo 4)
STAGE_ROOT   ?= $(HOME)/dev/stage
ARCHIVE_ROOT ?= $(HOME)/dev/archives
RUN          ?= runtime
GUI          ?= auto
RUN_ARGS     ?= --x-arg=pussy-cat --quiet
DEEP         ?=
REPO         ?= git@github.com:ga2k/CMakeFiles.git

ifeq ($(BT),debug)
  BTU := Debug
else ifeq ($(BT),release)
  BTU := Release
else
  $(error BT must be debug or release, not '$(BT)')
endif

ifeq ($(TK),both)
  TKS := gtk qt
else ifneq ($(filter $(TK),gtk qt),)
  TKS := $(TK)
else
  $(error TK must be gtk, qt or both, not '$(TK)')
endif
# libmycare.so and the launcher are identical under either toolkit, so the app is built (and staged) once:
# under gtk when both toolkits are selected. `make merge` then combines it with both toolkits' Gfx.
APPTKS := $(firstword $(TKS))

# Locate the two projects from wherever make was started.
THIS := $(abspath $(CURDIR))
ifneq ($(wildcard $(THIS)/Core/CMakeLists.txt),)
  LIBS_DIR ?= $(THIS)
  APP_DIR  ?= $(abspath $(THIS)/../MyCare)
else
  APP_DIR  ?= $(THIS)
  LIBS_DIR ?= $(abspath $(THIS)/../Libs)
endif

# Colours
BOLD   := \033[1m
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[1;33m
NC     := \033[0m

# ---------------------------------------------------------------------------------------------
# Update mechanism: once a day, compare VERSION with the copy in $(REPO) and replace this file
# if the repo's is newer (the current command is then aborted: re-run it).
# ---------------------------------------------------------------------------------------------
SELF       := $(abspath $(firstword $(MAKEFILE_LIST)))
MARKER     := $(dir $(SELF)).makefile_update_check
QUIET_FILE := $(dir $(SELF)).makefile_quiet
LAST_CHECK_TIME := $(shell [ -f "$(MARKER)" ] && cut -d' ' -f2- "$(MARKER)" 2>/dev/null || echo Never)

export FORCE

AUTOUPDATE_SKIP_GOALS := update quiet noisy version check-update __autoupdate help
DRYRUN := $(findstring n,$(filter-out --%,$(firstword -$(MAKEFLAGS))))
ifneq ($(strip $(MAKECMDGOALS)),)
ifeq ($(MAKELEVEL),0)
ifeq ($(DRYRUN),)
ifeq ($(filter $(AUTOUPDATE_SKIP_GOALS),$(MAKECMDGOALS)),)
$(foreach g,$(MAKECMDGOALS),$(eval $(g): __autoupdate))
endif
endif
endif
endif

.PHONY: __autoupdate update check-update quiet noisy version help

__autoupdate:
	@quiet=0; [ -f "$(QUIET_FILE)" ] && quiet=1; \
	say() { [ "$$quiet" -eq 1 ] || printf "$$@"; }; \
	now=$$(date +%s); last=0; [ -f "$(MARKER)" ] && last=$$(cut -d' ' -f1 "$(MARKER)" 2>/dev/null || echo 0); \
	say "$(BOLD)MCA Build System v$(VERSION)$(NC)  (last update check: $(YELLOW)$(LAST_CHECK_TIME)$(NC))\n"; \
	if [ $$((now - last)) -lt 86400 ] && [ "$(FORCE)" != "TRUE" ]; then exit 0; fi; \
	echo "$$now $$(date '+%Y-%m-%d %H:%M:%S')" > "$(MARKER)"; \
	tmp=$$(mktemp -d "$${TMPDIR:-/tmp}/makefile.repo.XXXXXX"); trap 'rm -rf "$$tmp"' EXIT; \
	say "Checking for updates from $(REPO)...\n"; \
	if ! GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=5" \
	     timeout 20 git clone --depth 1 -q "$(REPO)" "$$tmp" >/dev/null 2>&1; then \
	  say "$(RED)Update check skipped: could not reach $(REPO).$(NC)\n"; exit 0; \
	fi; \
	new=$$(sed -n 's/^VERSION[[:space:]]*:=[[:space:]]*//p' "$$tmp/Makefile" 2>/dev/null | head -n1); \
	if [ -z "$$new" ]; then say "$(RED)No Makefile VERSION found in $(REPO), skipping.$(NC)\n"; exit 0; fi; \
	newest=$$(printf '%s\n%s\n' "$(VERSION)" "$$new" | sort -V | tail -n1); \
	if [ "$$new" = "$(VERSION)" ]; then \
	  say "$(GREEN)Your Makefile is up to date.$(NC)\n"; \
	elif [ "$$newest" = "$$new" ]; then \
	  cp "$$tmp/Makefile" "$(SELF)"; \
	  printf "$(GREEN)Makefile updated $(VERSION) -> $$new.$(NC) $(YELLOW)Please re-run your command.$(NC)\n"; exit 1; \
	else \
	  printf "$(YELLOW)Your Makefile ($(VERSION)) is newer than the repo's ($$new).$(NC)\n"; \
	  if [ -t 0 ] && [ -t 1 ]; then \
	    printf "Push it to $(REPO)? [y/N] "; read ans; \
	    if [ "$$ans" = y ] || [ "$$ans" = Y ]; then \
	      cp "$(SELF)" "$$tmp/Makefile"; \
	      ( cd "$$tmp" && git remote set-url origin "$$(echo "$(REPO)" | sed 's|https://github.com/|git@github.com:|')" \
	        && git add Makefile && git commit -q -m "Makefile $(VERSION)" && git push -q ); \
	    fi; \
	  fi; \
	fi

update:
	@$(MAKE) --no-print-directory __autoupdate FORCE=TRUE

check-update:
	@tmp=$$(mktemp -d "$${TMPDIR:-/tmp}/makefile.repo.XXXXXX"); trap 'rm -rf "$$tmp"' EXIT; \
	if ! GIT_TERMINAL_PROMPT=0 timeout 20 git clone --depth 1 -q "$(REPO)" "$$tmp" >/dev/null 2>&1; then \
	  printf "$(RED)Could not reach $(REPO).$(NC)\n"; exit 1; fi; \
	online=$$(sed -n 's/^VERSION[[:space:]]*:=[[:space:]]*//p' "$$tmp/Makefile" 2>/dev/null | head -n1); \
	printf "Update Check Results\n--------------------\nCurrent Version : $(VERSION)\nOn-line Version : %s\n   Last checked : $(LAST_CHECK_TIME)\n" "$${online:-unknown}"

quiet:
	@touch "$(QUIET_FILE)"; printf "$(GREEN)Update check messages suppressed (make noisy to re-enable).$(NC)\n"

noisy:
	@rm -f "$(QUIET_FILE)"; printf "$(GREEN)Update check messages re-enabled.$(NC)\n"

version:
	@echo $(VERSION)

# ---------------------------------------------------------------------------------------------
# Helpers.   $(1) = libs|app   $(2) = gtk|qt
# ---------------------------------------------------------------------------------------------
STEM    = linux/$(BT)/shared/$(1)
PRESET  = Linux $(BTU) Shared $(if $(filter gtk,$(1)),GTK,Qt)
DIR     = $(if $(filter libs,$(1)),$(LIBS_DIR),$(APP_DIR))
STAGE   = $(STAGE_ROOT)/$(call STEM,$(1))
RUNTIME = $(STAGE_ROOT)/linux/$(BT)/shared/runtime

# Paths removed by `make clean-<libs|app>-<tk>`. Only ever per-toolkit trees.
CLEAN_PATHS = $(call DIR,$(1))/build/$(call STEM,$(2)) $(call DIR,$(1))/out/$(call STEM,$(2)) \
  $(if $(filter libs,$(1)),$(call STAGE,$(2)),$(call DIR,$(1))/generated/$(call STEM,$(2))) \
  $(if $(DEEP),$(call DIR,$(1))/external/$(call STEM,$(2)) $(if $(filter libs,$(1)),$(ARCHIVE_ROOT)/$(call STEM,$(2))))

# CMakePresets.json is generated (and gitignored): rebuild it when the template is newer.
$(LIBS_DIR)/CMakePresets.json: $(LIBS_DIR)/CMakeFiles/templates/CMakePresets.in
	cd "$(LIBS_DIR)" && sh CMakeFiles/setup
$(APP_DIR)/CMakePresets.json: $(APP_DIR)/CMakeFiles/templates/CMakePresets.in
	cd "$(APP_DIR)" && sh CMakeFiles/setup

# ---------------------------------------------------------------------------------------------
# Per project, per toolkit:  clean- configure- build- stage-  (libs|app)-(gtk|qt)
#   configure-X always configures; build-X configures only if the tree has never been configured;
#   stage-X builds first, then installs into $(STAGE_ROOT)/linux/<build>/shared/<tk>/usr/local.
# ---------------------------------------------------------------------------------------------
define TK_RULES
.PHONY: clean-$(1)-$(2) configure-$(1)-$(2) _cfg-$(1)-$(2) build-$(1)-$(2) stage-$(1)-$(2)

clean-$(1)-$(2):
	@printf "$(YELLOW)== clean $(1) ($(2), $(BT))$(NC)\n"
	rm -rf --one-file-system -- $(call CLEAN_PATHS,$(1),$(2))

configure-$(1)-$(2): $(call DIR,$(1))/CMakePresets.json
	@printf "$(GREEN)== configure $(1) ($(2), $(BT))$(NC)\n"
	@test -d "$(call DIR,$(1))" || { echo "$(call DIR,$(1)) not found"; exit 1; }
$(if $(filter app,$(1)),	@test -f "$(call STAGE,$(2))/usr/local/lib64/cmake/CoreConfig.cmake" || { echo "Core for $(2) is not staged in $(call STAGE,$(2)). Run: make stage-libs-$(2)"; exit 1; })
	cd "$(call DIR,$(1))" && cmake --preset "$(call PRESET,$(2))"

_cfg-$(1)-$(2): $(call DIR,$(1))/CMakePresets.json
	$$(if $$(wildcard $(call DIR,$(1))/build/$(call STEM,$(2))/build.ninja),@:,@$$(MAKE) --no-print-directory configure-$(1)-$(2))

build-$(1)-$(2): _cfg-$(1)-$(2)
	@printf "$(GREEN)== build $(1) ($(2), $(BT))$(NC)\n"
	cd "$(call DIR,$(1))" && cmake --build --preset "$(call PRESET,$(2))" --parallel $(JOBS)

stage-$(1)-$(2): build-$(1)-$(2)
	@printf "$(GREEN)== stage $(1) ($(2), $(BT)) -> $(call STAGE,$(2))$(NC)\n"
	cd "$(call DIR,$(1))" && cmake --build --preset "$(call PRESET,$(2))" --parallel $(JOBS) --target install
endef

$(foreach w,libs app,$(foreach t,gtk qt,$(eval $(call TK_RULES,$(w),$(t)))))

# ---------------------------------------------------------------------------------------------
# Aggregates over the selected toolkits (TK=gtk|qt|both):  <phase>-libs  <phase>-app  <phase>-all
# ---------------------------------------------------------------------------------------------
PHASES := clean configure build stage

# Libs goes through every selected toolkit; the (toolkit-neutral) app only through APPTKS, except `clean`,
# which removes the app's tree under every selected toolkit (an older per-toolkit build may linger there).
define AGG_RULES
.PHONY: $(1)-$(2)
$(1)-$(2): $(foreach t,$(if $(and $(filter app,$(2)),$(filter-out clean,$(1))),$(APPTKS),$(TKS)),$(1)-$(2)-$(t))
endef
$(foreach p,$(PHASES),$(foreach w,libs app,$(eval $(call AGG_RULES,$(p),$(w)))))

.PHONY: $(foreach p,$(PHASES),$(p)-all) all merge run smoke
$(foreach p,$(PHASES),$(eval $(p)-all: $(p)-libs $(p)-app))

all: stage-all

# Staging for both toolkits also assembles the combined runtime tree (the app from gtk + both Gfx).
stage-app:
	$(if $(filter both,$(TK)),@$(MAKE) --no-print-directory merge)

merge:
	@printf "$(GREEN)== merge toolkit stages -> $(RUNTIME)$(NC)\n"
	STAGE_ROOT="$(STAGE_ROOT)" "$(APP_DIR)/scripts/merge-toolkit-stages.sh" $(BT)

# ---------------------------------------------------------------------------------------------
# Run / smoke
# ---------------------------------------------------------------------------------------------
LAUNCHER = $(if $(filter runtime,$(RUN)),$(RUNTIME),$(call STAGE,$(RUN)))/usr/local/bin/MyCare

run:
	@case "$(RUN)" in gtk|qt|runtime) ;; *) echo "RUN must be gtk, qt or runtime"; exit 1;; esac
	@case "$(GUI)" in auto|gtk|qt) ;; *) echo "GUI must be auto, gtk or qt"; exit 1;; esac
	@test -x "$(LAUNCHER)" || { echo "$(LAUNCHER) not found: $(if $(filter runtime,$(RUN)),make stage-libs stage-app (TK=both),make stage-libs-$(RUN) stage-app-$(RUN))"; exit 1; }
	WhatsNew=1 exec "$(LAUNCHER)" $(RUN_ARGS) --gui=$(GUI)

smoke:
	@STAGE_ROOT="$(STAGE_ROOT)" RUN_ARGS="$(RUN_ARGS)" "$(APP_DIR)/scripts/smoke.sh" $(BT)

# ---------------------------------------------------------------------------------------------
help:
	@printf '$(BOLD)MCA Build System v$(VERSION)$(NC)   libs: $(LIBS_DIR)\n                              app:  $(APP_DIR)\n'
	@printf 'Settings: BT=$(BT)  TK=$(TK) (%s)  JOBS=$(JOBS)\n\n' "$(TKS)"
	@printf '  make all                             configure + build + stage everything (Libs first)\n'
	@printf '  make <phase>-<what>[-<tk>]           phase: clean configure build stage\n'
	@printf '                                       what:  libs app all     tk: gtk qt (default: TK=)\n'
	@printf '                                       (the app is toolkit-neutral: built once, under $(APPTKS))\n'
	@printf '      e.g. make build-app-qt   make stage-libs   make clean-all   make configure-all TK=gtk\n'
	@printf '  make clean-all DEEP=1                also remove external/ and ~/dev/archives (wx; slow to redo)\n'
	@printf '  make merge                           combined runtime tree: the app (built once) + both toolkits'"'"' Gfx\n'
	@printf '  make run [RUN=gtk|qt|runtime] [GUI=auto|gtk|qt] [RUN_ARGS="..."]\n'
	@printf '  make smoke                           start each tree/--gui combination and check the result\n'
	@printf '  make update | check-update | quiet | noisy | version\n'
	@printf '  Options: BT=debug|release  TK=gtk|qt|both  JOBS=N  STAGE_ROOT=...   Dry run: make -n <target>\n'
