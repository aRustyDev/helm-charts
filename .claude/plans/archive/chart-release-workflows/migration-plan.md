# Migration Plan: Chart Release Workflow Overhaul

## Overview

This plan covers the initial migration requirements to prepare the repository for the new 8-workflow attestation-backed release pipeline.

## Migration Steps

### Phase 0: Pre-Migration Preparation

#### 0.1 Backup Current State
```bash
# Document current branch state
git branch -a > backup-branches.txt

# Document current rulesets
gh api repos/{owner}/{repo}/rulesets > backup-rulesets.json

# Document Cloudflare Pages config (manual)
# Screenshot or export current CF Pages settings
```

#### 0.2 Verify Prerequisites
- [ ] Admin access to repository
- [ ] Access to Cloudflare Pages dashboard
- [ ] GitHub CLI (`gh`) installed and authenticated
- [ ] Current workflows are not running (pause if needed)

---

### Phase 1: Create Integration Branch

#### 1.1 Create Branch from Main
```bash
# Ensure main is up to date
git fetch origin
git checkout main
git pull origin main

# Create integration branch
git checkout -b integration

# Push to origin
git push -u origin integration
```

#### 1.2 Create Integration Ruleset
```bash
# Create ruleset via API
cat > integration-ruleset.json << 'EOF'
{
  "name": "integration-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/integration"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true
      }
    }
  ],
  "bypass_actors": [
    {
      "actor_id": 1,
      "actor_type": "RepositoryRole",
      "bypass_mode": "always"
    }
  ]
}
EOF

gh api repos/{owner}/{repo}/rulesets -X POST --input integration-ruleset.json
```

#### 1.3 Verification
```bash
# Verify branch exists
git ls-remote origin integration

# Verify ruleset applied
gh api repos/{owner}/{repo}/rulesets --jq '.[] | select(.name == "integration-protection")'
```

---

### Phase 2: Rename Charts Branch to Release

#### 2.1 Local Rename
```bash
# Fetch latest
git fetch origin

# Checkout charts branch
git checkout charts
git pull origin charts

# Create release branch from charts
git checkout -b release

# Push release branch
git push -u origin release
```

#### 2.2 Update Default Branch References

Check for references to `charts` branch in:
- [ ] `.github/workflows/*.yaml` - Any workflow referencing `charts`
- [ ] `CLAUDE.md` - Documentation references
- [ ] `README.md` - Installation instructions
- [ ] `docs/` - Documentation site
- [ ] External links/bookmarks

```bash
# Find references in codebase
grep -r "charts" --include="*.yaml" --include="*.md" .github/ docs/
```

#### 2.3 Update Cloudflare Pages

1. **Login to Cloudflare Dashboard**
   - Navigate to Pages
   - Select the helm-charts project

2. **Update Build Configuration**
   - Change production branch from `charts` to `release`
   - OR create new deployment for `release` branch

3. **Verify Deployment**
   - Trigger manual deployment
   - Verify Helm repo index is accessible

**Cloudflare Pages Settings to Update**:
| Setting | Old Value | New Value |
|---------|-----------|-----------|
| Production branch | `charts` | `release` |
| Build command | (unchanged) | (unchanged) |
| Output directory | (unchanged) | (unchanged) |

#### 2.4 Update/Create Release Ruleset
```bash
# Option A: Update existing charts ruleset (if using API)
# Get existing ruleset ID
RULESET_ID=$(gh api repos/{owner}/{repo}/rulesets --jq '.[] | select(.name | contains("charts")) | .id')

# Update target
cat > release-ruleset-update.json << 'EOF'
{
  "name": "release-protection",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/release"],
      "exclude": []
    }
  }
}
EOF

gh api repos/{owner}/{repo}/rulesets/$RULESET_ID -X PUT --input release-ruleset-update.json

# Option B: Create new ruleset (if preferred)
cat > release-ruleset.json << 'EOF'
{
  "name": "release-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/release"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "update" },
    { "type": "non_fast_forward" }
  ],
  "bypass_actors": []
}
EOF

gh api repos/{owner}/{repo}/rulesets -X POST --input release-ruleset.json
```

#### 2.5 Delete Old Charts Branch (After Verification)
```bash
# Only after verifying release branch works!
# And after Cloudflare Pages is updated!

# Delete remote charts branch
git push origin --delete charts

# Delete local charts branch
git branch -d charts
```

#### 2.6 Verification
```bash
# Verify release branch exists
git ls-remote origin release

# Verify charts branch is gone
git ls-remote origin charts  # Should return nothing

# Verify Cloudflare Pages
curl -s https://your-helm-repo.pages.dev/index.yaml | head -20
```

---

### Phase 3: Create Tag Ruleset

#### 3.1 Create Release Tag Ruleset
```bash
cat > tag-ruleset.json << 'EOF'
{
  "name": "release-tag-protection",
  "target": "tag",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/tags/*-v*"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "update" },
    { "type": "creation" }
  ],
  "bypass_actors": []
}
EOF

gh api repos/{owner}/{repo}/rulesets -X POST --input tag-ruleset.json
```

**Note**: After workflows are deployed, add GitHub Actions as bypass actor for tag creation.

#### 3.2 Verification
```bash
# Try to create a test tag manually (should fail after ruleset)
git tag test-v0.0.1 -m "Test tag"
git push origin test-v0.0.1  # Should be rejected

# Clean up if it succeeded (before ruleset was active)
git push origin --delete test-v0.0.1
git tag -d test-v0.0.1
```

---

### Phase 4: Create Integration Chart Branch Ruleset

#### 4.1 Create Ruleset
```bash
cat > integration-chart-ruleset.json << 'EOF'
{
  "name": "integration-chart-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/integration/*"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "update" },
    { "type": "non_fast_forward" }
  ],
  "bypass_actors": []
}
EOF

gh api repos/{owner}/{repo}/rulesets -X POST --input integration-chart-ruleset.json
```

---

### Phase 5: Update Documentation

#### 5.1 Update CLAUDE.md
Add reference to new branch structure and workflows.

#### 5.2 Update docs/src/ci/
Create or update CI documentation to reflect new workflow structure.

#### 5.3 Update README.md
Update any installation instructions that reference branches.

---

## Migration Checklist

### Pre-Migration
- [ ] Backup current state (branches, rulesets)
- [ ] Verify admin access
- [ ] Document Cloudflare Pages config
- [ ] Ensure no workflows are running

### Phase 1: Integration Branch
- [ ] Create `integration` branch from `main`
- [ ] Push `integration` to origin
- [ ] Create `integration-protection` ruleset
- [ ] Verify ruleset is active

### Phase 2: Charts → Release
- [ ] Create `release` branch from `charts`
- [ ] Push `release` to origin
- [ ] Update Cloudflare Pages to use `release`
- [ ] Verify Cloudflare Pages deployment works
- [ ] Update/create `release-protection` ruleset
- [ ] Update workflow files (if any reference `charts`)
- [ ] Update documentation
- [ ] Delete `charts` branch (after all verifications)

### Phase 3: Tag Protection
- [ ] Create `release-tag-protection` ruleset
- [ ] Verify manual tag creation is blocked

### Phase 4: Integration Chart Protection
- [ ] Create `integration-chart-protection` ruleset

### Phase 5: Documentation
- [ ] Update CLAUDE.md
- [ ] Update CI documentation
- [ ] Update README.md

---

## Rollback Plan

### If Integration Branch Issues
```bash
# Delete integration branch
git push origin --delete integration

# Delete ruleset
RULESET_ID=$(gh api repos/{owner}/{repo}/rulesets --jq '.[] | select(.name == "integration-protection") | .id')
gh api repos/{owner}/{repo}/rulesets/$RULESET_ID -X DELETE
```

### If Release Branch Issues
```bash
# Recreate charts branch from release
git checkout release
git checkout -b charts
git push origin charts

# Update Cloudflare Pages back to charts

# Delete release branch
git push origin --delete release
```

### If Tag Ruleset Issues
```bash
# Delete tag ruleset
RULESET_ID=$(gh api repos/{owner}/{repo}/rulesets --jq '.[] | select(.name == "release-tag-protection") | .id')
gh api repos/{owner}/{repo}/rulesets/$RULESET_ID -X DELETE
```

---

## Post-Migration Verification

```bash
# Verify all branches exist
git ls-remote origin | grep -E "(main|integration|release)"

# Expected output:
# <sha> refs/heads/integration
# <sha> refs/heads/main
# <sha> refs/heads/release

# Verify charts branch is gone
git ls-remote origin | grep charts
# Expected: no output

# Verify rulesets
gh api repos/{owner}/{repo}/rulesets --jq '.[].name'
# Expected output includes:
# - integration-protection
# - integration-chart-protection
# - release-protection
# - release-tag-protection
# - main-protection (or existing main rulesets)

# Verify Cloudflare Pages
curl -I https://your-helm-repo.pages.dev/
# Expected: 200 OK
```

---

## Timeline Estimate

| Phase | Tasks | Estimate |
|-------|-------|----------|
| Phase 0 | Preparation | 15 min |
| Phase 1 | Integration branch | 10 min |
| Phase 2 | Charts → Release | 30 min |
| Phase 3 | Tag protection | 5 min |
| Phase 4 | Chart branch protection | 5 min |
| Phase 5 | Documentation | 20 min |
| **Total** | | **~1.5 hours** |

**Note**: Add buffer for troubleshooting. Cloudflare Pages propagation may take a few minutes.
