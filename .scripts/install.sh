#!/usr/bin/env bash

if $(whoami) == "analyst"; then
    git setup github
fi

# Install dependencies
brew update
brew install autoenv
brew install 1password-cli

pip install --user pre-commit --upgrade
pip install --user ggshield --upgrade

# Setup autoenv
source $(brew --prefix)/opt/autoenv/activate.sh

# Setup GitGuardian
op signin
ggshield install -m local -t pre-commit -f
ggshield install -m local -t pre-push -a

# Setup pre-commit
pre-commit install --hook-type commit-msg
pre-commit install --install-hooks
npm install --save-dev @commitlint/{cli,config-conventional}
# npm install --save-dev husky
# npx husky init
# echo "npx --no -- commitlint --edit \$1" > .husky/commit-msg
