.PHONY: all check format check-format lint fix

BIOME ?= biome

all: format lint

check: check-format lint

format:
	$(BIOME) format --write .

check-format:
	$(BIOME) format .

lint:
	$(BIOME) lint .

fix:
	$(BIOME) check --write .
