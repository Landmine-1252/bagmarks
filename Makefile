LUA ?= lua5.1
LUAC ?= luac5.1

.PHONY: test check package icons
test: check
	$(LUA) tests/run.lua

check:
	python3 tools/check.py --luac $(LUAC)

package: test
	python3 tools/package.py

icons:
	python3 tools/build_icons.py
