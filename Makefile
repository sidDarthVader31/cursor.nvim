.PHONY: test test-file lint smoke test-live

test:
	nvim --headless -u tests/minimal_init.lua -c "lua dofile('tests/run.lua')" -c "qa"

test-file:
	@if [ -z "$(FILE)" ]; then echo "Usage: make test-file FILE=tests/unit/foo_spec.lua"; exit 1; fi
	FILE="$(FILE)" nvim --headless -u tests/minimal_init.lua -c "lua dofile('tests/run.lua')" -c "qa"

test-live:
	@if [ -z "$$CURSOR_NVIM_LIVE" ]; then echo "Set CURSOR_NVIM_LIVE=1 to run live agent tests"; exit 0; fi
	CURSOR_NVIM_LIVE=1 nvim --headless -u tests/minimal_init.lua -c "lua dofile('tests/run.lua')" -c "qa"

smoke:
	nvim --headless -u tests/minimal_init.lua +'lua require("cursor").setup({}); print("SMOKE_OK")' +qa

lint:
	@command -v stylua >/dev/null 2>&1 && stylua --check lua plugin tests || echo "stylua not installed, skipping"
	@command -v luacheck >/dev/null 2>&1 && luacheck lua || echo "luacheck not installed, skipping"
