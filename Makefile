# Variables
SWAP_TYPE ?= mocSwaps
TEST_CMD := forge test --no-match-test invariant

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
	@echo "Executing MocSwaps tests with $(LENDING_PROTOCOL)..."
	SWAP_TYPE=mocSwaps $(TEST_CMD)
moc-tropykus:
	@echo "Executing MocSwaps Tropykus tests..."
	SWAP_TYPE=mocSwaps LENDING_PROTOCOL=tropykus $(TEST_CMD)
moc-sovryn:
	@echo "Executing MocSwaps Sovryn tests..."
	LENDING_PROTOCOL=sovryn $(TEST_CMD)

fork:
	@echo "Executing fork tests with $(LENDING_PROTOCOL)..."
	$(TEST_CMD) --fork-url $(RSK_MAINNET_RPC_URL)
fork-tropykus:
	@echo "Executing Tropykus fork tests..."
	LENDING_PROTOCOL=tropykus $(TEST_CMD) --fork-url $(RSK_MAINNET_RPC_URL)
fork-sovryn:
	@echo "Executing Sovryn fork tests..."
	LENDING_PROTOCOL=sovryn $(TEST_CMD) --fork-url $(RSK_MAINNET_RPC_URL)

# DexSwaps specific tests
dex:
	@echo "Executing DexSwaps tests..."
	SWAP_TYPE=dexSwaps $(TEST_CMD) --no-match-contract MockContractsTest

coverage:
	@echo "Calculating coverage excluding invariant tests..."
	forge coverage --no-match-test invariant

# Help target
help:
	@echo "Available targets:"
	@echo "  make test SWAP_TYPE=mocSwaps   # Run MocSwaps tests"
	@echo "  make test SWAP_TYPE=dexSwaps   # Run DexSwaps tests"
	@echo "  make moc                       # Directly run MocSwaps local tests"
	@echo "  make moc-tropykus              # Run MocSwaps Tropykus local tests"
	@echo "  make moc-sovryn                # Run MocSwaps Sovryn local tests"
	@echo "  make dex                       # Directly run DexSwaps local tests"
	@echo "  make fork                      # Run fork tests"
	@echo "  make fork-tropykus             # Run Tropykus fork tests"
	@echo "  make fork-sovryn               # Run Sovryn fork tests"
	@echo "  make help                      # Show this help message"
