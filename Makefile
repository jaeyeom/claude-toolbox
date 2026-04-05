.PHONY: all check format check-format lint fix validate validate-full check-agents-md

BIOME ?= biome

all: format fix validate-full

check: check-format lint validate check-agents-md

format:
	$(BIOME) format --write .

check-format:
	$(BIOME) format .

lint:
	$(BIOME) lint .

fix: format
	$(BIOME) check --write .

validate:
	./scripts/validate-marketplace.sh

check-agents-md:
	./scripts/check-agents-md.sh

validate-full: fix validate
	claude plugin validate .
