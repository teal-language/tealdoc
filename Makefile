SHELL := /bin/bash

ROCKSPEC := tealdoc-dev-1.rockspec
LUAROCKS_CMD ?= luarocks
TL ?= tl
BUSTED ?= busted
TEALDOC ?= tealdoc
HEAD_REF ?= HEAD

.PHONY: all help deps build install test smoke check check-generated-diff

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
		'  check-generated-diff' \
		'           Require changed src/*.tl files to have build/*.lua changes.'

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
	done < <(find src -type f -name '*.tl' | sort)

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

check-generated-diff:
	@if [[ -z "$(BASE_REF)" ]]; then \
		echo 'BASE_REF is required.' >&2; \
		exit 2; \
	fi; \
	changed="$$(git diff --name-only --no-renames "$(BASE_REF)" "$(HEAD_REF)")"; \
	missing=0; \
	while IFS= read -r source; do \
		[[ "$$source" == src/*.tl ]] || continue; \
		mirror="build/$${source#src/}"; \
		mirror="$${mirror%.tl}.lua"; \
		if ! grep -Fqx -- "$$mirror" <<< "$$changed"; then \
			echo "Missing generated change: $$mirror (for $$source)" >&2; \
			missing=1; \
		fi; \
	done <<< "$$changed"; \
	exit "$$missing"
