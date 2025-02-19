.PHONY: clean setup test all

all: setup test clean

setup:
	@echo "Installing repo dependencies"
	@bash .scripts/install.sh

clean:
	@echo "Cleaning up repo dependencies"
	@rm -rf node_modules
	@rm -rf .husky

test:
	@echo "Testing repo dependencies"
	@echo "TODO"
