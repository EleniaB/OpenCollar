ifeq ($(OS),Windows_NT)
		LSLINT_ENV := win64
else
		UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
				LSLINT_ENV := linux
    endif
    ifeq ($(UNAME_S),Darwin)
				LSLINT_ENV := osx
    endif		
endif

LSLINT_VERSION := v1.0.8
LSLINT_FILE := lslint_$(LSLINT_VERSION)_$(LSLINT_ENV).zip
LSLINT_URL := https://github.com/Makopo/lslint/releases/download/$(LSLINT_VERSION)/$(LSLINT_FILE)

LSLINT := bin/lslint

LSL_FILES := $(shell ls src/*/*.lsl)
LINT_FILES := $(shell echo $(LSL_FILES) | sed 's/src/build\/lint/g' | sed 's/lsl/lslint/g')

BUILD := build/

.PHONY: lint

$(LSLINT):
	mkdir -p $(shell dirname $@)
	cd bin; curl -L $(LSLINT_URL) -o $(LSLINT_FILE)
	cd bin; unzip $(LSLINT_FILE)

$(BUILD)lint/%.lslint: src/%.lsl
	mkdir -p $(shell dirname $@)
	$(LSLINT) -p src/$*.lsl

lint: $(LSLINT) $(LINT_FILES)
