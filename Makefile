.PHONY: all check format check-format lint fix validate validate-full check-agents-md test-git-guardrails test-fork-keeper check-gitleaks

BIOME ?= biome

all: format fix validate-full

check: check-format lint validate check-agents-md test-git-guardrails test-fork-keeper check-gitleaks

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

test-git-guardrails:
	./plugins/git-guardrails/tests/run.sh

test-fork-keeper:
	./plugins/fork-keeper/tests/run.sh

# Scans every commit (the history is small; ~0.2s). Known false positives are
# pinned by fingerprint in .gitleaksignore.
check-gitleaks:
	@if ! command -v gitleaks >/dev/null 2>&1; then \
		echo "Error: gitleaks is required for make check"; \
		echo "Install with: brew install gitleaks (or setup-dev: ./ensure.sh gitleaks)"; \
		exit 1; \
	fi
	@gitleaks git --redact --no-banner .

validate-full: fix validate
	claude plugin validate .
