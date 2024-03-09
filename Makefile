'':
	make format
	make doc
format:
	nvim -l scripts/format.lua
doc:
	make meta
	make vimdoc
vimdoc:
	nvim -l scripts/gen_vimdoc.lua
meta:
	nvim -l scripts/gen_meta.lua
.PHONY: doc
