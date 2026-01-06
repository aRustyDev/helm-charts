# Documentation Workflow

**File:** `.github/workflows/docs.yaml`

**Triggers:**
- Pull requests (when `docs/` or `book.toml` changes)
- Push to `main` (when `docs/` or `book.toml` changes)
- Manual dispatch

## Jobs

### `lint`

Lints Markdown files using [markdownlint](https://github.com/DavidAnson/markdownlint).

**Note:** Currently runs with `|| true` until all lint issues are resolved.

### `link-check`

Builds the mdBook and checks for broken internal links.

### `build`

Builds the mdBook documentation:

```bash
mdbook build docs
```

Uploads the built artifact for download/review (7-day retention).

## Local Development

```bash
# Install mdbook
brew install mdbook

# Serve locally with hot reload
cd docs && mdbook serve

# Build
mdbook build docs

# Output is in docs/book/
```

## Structure

```
docs/
├── book.toml          # mdBook configuration
├── src/
│   ├── SUMMARY.md     # Table of contents
│   ├── introduction.md
│   ├── charts/        # Chart documentation
│   ├── adr/           # Architecture Decision Records
│   ├── ci/            # CI/CD documentation
│   ├── security/      # Security documentation
│   └── contributing/  # Contribution guides
└── book/              # Built output (gitignored)
```

## Adding New Pages

1. Create the Markdown file in `docs/src/`
2. Add entry to `docs/src/SUMMARY.md`
3. Commit and push

## Configuration

**`book.toml`:**
```toml
[book]
title = "Helm Charts"
authors = ["aRustyDev"]
language = "en"

[build]
build-dir = "book"

[output.html]
git-repository-url = "https://github.com/aRustyDev/helm-charts"
```
