.PHONY: test lint smoke

test:
	nvim --headless -u tests/minimal_init.lua -c "lua dofile('tests/run.lua')" -c "qa"

smoke:
	nvim --headless -u tests/minimal_init.lua +'lua require("cursor").setup({}); print("SMOKE_OK")' +qa

lint:
	@command -v stylua >/dev/null 2>&1 && stylua --check lua plugin tests || echo "stylua not installed, skipping"
	@command -v luacheck >/dev/null 2>&1 && luacheck lua || echo "luacheck not installed, skipping"
