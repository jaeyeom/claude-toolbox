.PHONY: all check format check-format lint fix validate validate-full

BIOME ?= biome

all: format fix validate-full

check: check-format lint validate

format:
	$(BIOME) format --write .

check-format:
	$(BIOME) format .

lint:
	$(BIOME) lint .

fix:
	$(BIOME) check --write .

validate:
	./scripts/validate-marketplace.sh

validate-full: validate
	claude plugin validate .
