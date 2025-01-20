# Makefile

# Variables
SWAP_TYPE ?= mocSwaps
FORGE_CMD := forge test --no-match-test invariant

# Targets
.PHONY: all test moc dex help

all: help

# Default test target
test:
	@echo "Running tests for SWAP_TYPE=$(SWAP_TYPE)"
	@if [ "$(SWAP_TYPE)" = "mocSwaps" ]; then \
		make moc; \
	elif [ "$(SWAP_TYPE)" = "dexSwaps" ]; then \
		make dex; \
	else \
		echo "Invalid SWAP_TYPE: $(SWAP_TYPE)"; \
		exit 1; \
	fi

# MocSwaps specific tests
moc:
	@echo "Executing MocSwaps tests..."
	$(FORGE_CMD)
moc-tropykus:
	@echo "Executing MocSwaps Tropykus tests..."
	LENDING_PROTOCOL=tropykus $(FORGE_CMD)
moc-sovryn:
	@echo "Executing MocSwaps Sovryn tests..."
	LENDING_PROTOCOL=sovryn $(FORGE_CMD)

# DexSwaps specific tests
dex:
	@echo "Executing DexSwaps tests..."
	$(FORGE_CMD) --no-match-contract MockContractsTest

coverage:
	@echo "Calculating coverage excluding invariant tests..."
	forge coverage --no-match-test invariant

# Help target
help:
	@echo "Available targets:"
	@echo "  make test SWAP_TYPE=mocSwaps   # Run MocSwaps tests"
	@echo "  make test SWAP_TYPE=dexSwaps   # Run DexSwaps tests"
	@echo "  make moc                       # Directly run MocSwaps tests"
	@echo "  make dex                       # Directly run DexSwaps tests"
	@echo "  make help                      # Show this help message"
