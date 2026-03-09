.PHONY: help install-deps lint test

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

install-deps: ## Install runtime and dev dependencies
	sudo apt-get install -y xorriso cpio gzip shellcheck bats

lint: ## Run shellcheck on all scripts
	shellcheck build reinstall lib/*.sh tools/*.sh

test: ## Run bats tests
	bats test/
