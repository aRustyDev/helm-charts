# Contributing

1. Add a branch for your contribution `dev-<chart>/<feature>`
2. Install [pre-commit](https://pre-commit.com/) and run `pre-commit install`
3. Follow conventional commit message guidelines
4. When your contribution is ready, create a pull request

## Getting Started

There is a chance that when installing pre-commit, it will error out complaining that something wasn't able to be installed. In cases like this, you likely need to update one of the dependent languages (ruby, python, etc) to the latest version. You can do this by running `brew update && brew upgrade` or `apt-get update && apt-get upgrade`, or similar (depending on your OS).

## Conventional Commit Cheat Sheet ([source](https://gist.github.com/qoomon/5dfcdf8eec66a051ecd85625518cfd13))

### Types

- API or UI relevant changes
  - `feat` Commits, that add or remove a new feature to the API or UI
  - `fix` Commits, that fix a API or UI bug of a preceded `feat` commit
- `refactor` Commits, that rewrite/restructure your code, however do not change any API or UI behaviour
  - `perf` Commits are special refactor commits, that improve performance
- `style` Commits, that do not affect the meaning (white-space, formatting, missing semi-colons, etc)
- `test` Commits, that add missing tests or correcting existing tests
- `docs` Commits, that affect documentation only
- `build` Commits, that affect build components like build tool, ci pipeline, dependencies, project version, ...
- `ops` Commits, that affect operational components like infrastructure, deployment, backup, recovery, ...
- `chore` Miscellaneous commits e.g. modifying `.gitignore`

### Scopes

The `scope` provides additional contextual information.

- Is an optional part of the format
- Allowed Scopes depends on the specific project
- Don't use issue identifiers as scopes

### Breaking Changes Indicator

Breaking changes should be indicated by an `!` before the `:` in the subject line e.g. `feat(api)!: remove status endpoint`

- Is an optional part of the format

### Description

The description contains a concise description of the change.

- Is a mandatory part of the format
- Use the imperative, present tense: "change" not "changed" nor "changes"
  - Think of `This commit will...` or `This commit should...`
- Don't capitalize the first letter
- No dot (`.`) at the end

### Body

The `body` should include the motivation for the change and contrast this with previous behavior.

- Is an optional part of the format
- Use the imperative, present tense: "change" not "changed" nor "changes"
- This is the place to mention issue identifiers and their relations

### Footer

The `footer` should contain any information about Breaking Changes and is also the place to reference Issues that this commit refers to.

- Is an optional part of the format
- optionally reference an issue by its id.
- Breaking Changes should start with the word `BREAKING CHANGES`: followed by space or two newlines. The rest of the commit message is then used for this.

### Versioning

- If your next release contains commit with...
  - breaking changes incremented the major version
  - API relevant changes (`feat` or `fix`) incremented the minor version
- Else increment the patch version
