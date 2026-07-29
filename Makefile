SHELL := /bin/bash

ROCKSPEC := tealdoc-dev-1.rockspec
LUAROCKS_CMD ?= luarocks
TL ?= tl
BUSTED ?= busted
TEALDOC ?= tealdoc
HEAD_REF ?= HEAD

.PHONY: all help deps build dist install test smoke check

all: check

help:
	@printf '%s\n' \
		'Usage: make <target>' \
		'' \
		'Targets:' \
		'  help     Show this help message.' \
		'  deps     Install project and test dependencies.' \
		'  build    Compile Teal sources into build/.' \
		'  install  Build and install tealdoc with LuaRocks.' \
		'  test     Install tealdoc and run the Busted specs.' \
		'  smoke    Generate docs from the LuaRocks Teal package.' \
		'  check    Run the tests and documentation smoke test.' \
		'  dist     Build the release tarball and its rockspec.'

deps:
	$(LUAROCKS_CMD) make --only-deps $(ROCKSPEC)
	@$(LUAROCKS_CMD) show busted >/dev/null 2>&1 || \
		$(LUAROCKS_CMD) install busted

build:
	@set -eu; \
	while IFS= read -r source; do \
		output="build/$${source#src/}"; \
		output="$${output%.tl}.lua"; \
		mkdir -p "$$(dirname "$$output")"; \
		$(TL) -I src -I types gen "$$source" -o "$$output"; \
	done < <(find src -type f -name '*.tl' | sort); \
	mkdir -p build/tealdoc/generator/site/assets; \
	cp src/tealdoc/generator/site/assets/pico.classless-2.1.1.min.css \
		build/tealdoc/generator/site/assets/

install: deps build
	$(LUAROCKS_CMD) make $(ROCKSPEC)

test: install
	$(BUSTED)

smoke: install
	@sample="$$(lua -e ' \
		for template in package.path:gmatch("[^;]+") do \
			local path = template:gsub("?", "tl") \
			local file = io.open(path, "r") \
			if file then \
				file:close() \
				print((path:gsub("%.lua$$", ".tl"))) \
				return \
			end \
		end \
		os.exit(1) \
	')"; \
	output="$${TMPDIR:-/tmp}/tealdoc-tl-docs.md"; \
	$(TEALDOC) md --no-warn-missing --output "$$output" "$$sample"; \
	test -s "$$output"; \
	grep -q '^# Module:' "$$output"

check: test smoke

# What a release is built from: the Teal the tree carries and the Lua it does
# not. The rock installs both, so a project depending on tealdoc can run it and
# type-check against it, and neither copy is committed for the other to drift
# from.
# What a release is built from. `make dist` stages the Teal the tree carries
# and the Lua it does not into one directory, tars it, and writes the rockspec
# that names the tarball. The rock installs both, so a project depending on
# tealdoc can run it and type-check against it, and neither copy is committed
# for the other to drift from.
#
# VERSION is read from the source rather than repeated here, so a release
# cannot be cut under a number the program does not report. A tagged build
# passes REVISION to distinguish a re-release of the same version.
# The `+dev` a working tree carries is not a LuaRocks version, so it is cut.
# A tagged build passes VERSION explicitly and this default is not consulted.
VERSION ?= $(shell sed -n 's/^tealdoc\.version = "\([^+"]*\).*"$$/\1/p' src/tealdoc.tl)
REVISION ?= 1
DIST ?= dist
STAGE := $(DIST)/tealdoc-$(VERSION)
TARBALL := $(DIST)/tealdoc-$(VERSION).tar.gz
RELEASE_ROCKSPEC := $(DIST)/tealdoc-$(VERSION)-$(REVISION).rockspec
TARBALL_URL ?= https://github.com/teal-language/tealdoc/releases/download/v$(VERSION)/tealdoc-$(VERSION).tar.gz

dist: build
	@set -eu; \
	declared="$$(sed -n 's/^tealdoc\.version = "\([^+"]*\).*"$$/\1/p' src/tealdoc.tl)"; \
	if [[ "$(VERSION)" != "$$declared" ]]; then \
		printf 'version %s does not match tealdoc.version %s\n' \
			"$(VERSION)" "$$declared" >&2; \
		exit 1; \
	fi; \
	rm -rf "$(STAGE)" "$(TARBALL)" "$(RELEASE_ROCKSPEC)"; \
	mkdir -p "$(STAGE)"; \
	cp -R src build bin types "$(STAGE)/"; \
	cp LICENSE README.md "$(STAGE)/"; \
	tar -czf "$(TARBALL)" -C "$(DIST)" "tealdoc-$(VERSION)"; \
	sed \
		-e 's|^version = .*|version = "$(VERSION)-$(REVISION)"|' \
		-e 's|^   url = .*|   url = "$(TARBALL_URL)",|' \
		-e 's|^   branch = .*|   dir = "tealdoc-$(VERSION)"|' \
		$(ROCKSPEC) > "$(RELEASE_ROCKSPEC)"; \
	printf 'wrote %s\n%s\n' "$(TARBALL)" "$(RELEASE_ROCKSPEC)"
