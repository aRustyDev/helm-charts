NOTES:

- We need to rename `charts` branch -> `release`
- We need to update Cloudflare Pages to reflect the change to `release`
- "Overall Attestation" is to capture a Snapshot of a PR Description (which holds the Attestation ID Map) and attest that collection of Attestation IDs; This is to support "Attestation Lineage"
- "Attestation Lineage" is the ability to follow one attestation back to its roots in a programmatic/algorithmic manner

Requirements:

- Adhere to In-Toto Provenance Attestation Patterns
- Use GH Attestations to attest In-Toto Provenance results
- Adhere to Atomic Releases
- Adhere to Atomic Tag <-> Release pattern; ie each Release has 1 Tag
- Enforce Atomic Chart PRs
- Publish Charts to ALL of
  - GHCR
  - GH Releases
  - `release` branch

---

# Workflows

1. Validate Initial Contribution
2. Filter Charts
3. Enforce Atomic Chart PRs
4. Format Atomic Chart PRs
5. Validate & SemVer Bump Atomic Chart PRs
6. Atomic Chart Tagging
7. Atomic Chart Releases
8. Atomic Release Publishing

---

## Workflow 1: Initial Contribution

### Triggers

- PR: `Feature -> Integration`

### Checks

- `lint-test (v1.32.11)`
  - Follow In-Toto Pattern
  - Use GH Attestation to attest In-Toto provenance result
  - Store Attestation ID in PR Description as Markdown Code Comment
    - NOTE: If Attested again, overwrite original Attestation ID for this 'check' in PR; ie. each unique 'check' gets its own GH Attestation ID Key
- `lint-test (v1.33.7)`
  - Follow In-Toto Pattern
  - Use GH Attestation to attest In-Toto provenance result
  - Store Attestation ID in PR Description as Markdown Code Comment
    - NOTE: If Attested again, overwrite original Attestation ID for this 'check' in PR; ie. each unique 'check' gets its own GH Attestation ID Key
- `lint-test (v1.34.3)`
  - Follow In-Toto Pattern
  - Use GH Attestation to attest In-Toto provenance result
  - Store Attestation ID in PR Description as Markdown Code Comment
    - NOTE: If Attested again, overwrite original Attestation ID for this 'check' in PR; ie. each unique 'check' gets its own GH Attestation ID Key
- `artifacthub-lint`
  - Follow In-Toto Pattern
  - Use GH Attestation to attest In-Toto provenance result
  - Store Attestation ID in PR Description as Markdown Code Comment
    - NOTE: If Attested again, overwrite original Attestation ID for this 'check' in PR; ie. each unique 'check' gets its own GH Attestation ID Key
- `<security>`
  - Follow In-Toto Pattern
  - Use GH Attestation to attest In-Toto provenance result
  - Store Attestation ID in PR Description as Markdown Code Comment
    - NOTE: If Attested again, overwrite original Attestation ID for this 'check' in PR; ie. each unique 'check' gets its own GH Attestation ID Key
- Validate Commit Message Format
  - Follow Conventional-Commit (+ local overrides) format
  - Follow In-Toto Pattern
  - Use GH Attestation to attest In-Toto provenance result
  - Store Attestation ID in PR Description as Markdown Code Comment
    - NOTE: If Attested again, overwrite original Attestation ID for this 'check' in PR; ie. each unique 'check' gets its own GH Attestation ID Key
- Generate Diff CHANGELOG
  - Use `Git-Diff`, Commit Comments to generate
  - Follow "Keep-A-Changelog" format
  - Follow In-Toto Pattern
  - Use GH Attestation to attest In-Toto provenance result
  - Store Attestation ID in PR Description as Markdown Code Comment
    - NOTE: If Attested again, overwrite original Attestation ID for this 'check' in PR; ie. each unique 'check' gets its own GH Attestation ID Key

### Rulesets

- All required checks must pass; Allow admin bypass

### Actions

---

## Workflow 2: Filter Charts

### Trigger

- Merge to `Integration` && changes to `/charts/**`

### Rulesets

- `Integration` protected from deletion; No admin bypass
- `Integration` protected from push/force-push; Allow admin bypass

### Checks

### Actions

- Detect all individual `<chart>` in the last Merge (to support multiple charts at once)
- Open Cherry Picked PR `Integration -> Integration/<chart>` for each `<chart>`
- CASE: PR `Integration -> Integration/<chart-foo>` already exists -> Merge new cherry picked content onto existing PR (allows for updating PR if needed)

---

## Workflow 3: Enforce Atomic Chart PRs

### Triggers

- PR: `Integration -> Integration/<chart>`

### Checks

### Rulesets

- Only `Integration` may merge to `Integration/<chart>`; No admin bypass
- `Integration/<chart>` protected from push/force-push; No admin bypass

### Actions

- Automatically Merge the PR

---

## Workflow 4: Format Atomic Chart PRs

### Triggers

- Merge: `Integration/<chart>`

### Checks

### Rulesets

### Actions

- Open PR `Integration/<chart> -> Main`
- Include Source PR (that merged this to `integration`) in the PR description

---

## Workflow 5: Validate & SemVer Bump Atomic Chart PRs

### Triggers

- PR: `Integration/<chart> -> Main`

### Checks

- Verify Attestations
  - Follow In-Toto Pattern
  - Use GH Attestation to attest In-Toto provenance result
  - Store Attestation ID in PR Description as Markdown Code Comment
    - NOTE: If Attested again, overwrite original Attestation ID for this 'check' in PR; ie. each unique 'check' gets its own GH Attestation ID Key

### Rulesets

- All required checks must pass; No admin bypass

### Actions

- SemVer Bumping + Attestation@SHA(-> PR)
  - Follow In-Toto Pattern
  - Use GH Attestation to attest In-Toto provenance result
  - Store Attestation ID in PR Description as Markdown Code Comment
    - NOTE: If Attested again, overwrite original Attestation ID for this 'check' in PR; ie. each unique 'check' gets its own GH Attestation ID Key
- Overall Attestation@SHA

---

## Workflow 6: Atomic Chart Tagging

### Triggers

- Merge: `Main` && changes to `/charts/**`

### Checks

### Rulesets

- `Main` branch protected from deletion; No admin bypass
- `Main` branch protected from push/force-push; Allow admin bypass
- `<chart>-vX.Y.Z` tags protected from deletion; No admin bypass
- `<chart>-vX.Y.Z` tags are immutable; No admin bypass
- `<chart>-vX.Y.Z` tags may only be created against `Main`; No admin bypass

### Actions

- Open PR `Main -> Release`
- Create Immutable Annotated Tag (use `<chart>-vX.Y.Z`; get SemVer from Chart)
  - Tag Annotations
    - Attestation Lineage
    - CHANGELOG Diff
    - Summary

---

## Workflow 7: Atomic Chart Releases

### Triggers

- PR: `Main -> Release`

### Checks

- Verify Attestations at TAG
  - Follow In-Toto Pattern
  - Use GH Attestation to attest In-Toto provenance result
  - Store Attestation ID in PR Description as Markdown Code Comment

### Rulesets

- Only `Main` may Merge to `Release`; No admin bypass
- All required checks must pass; No admin bypass

### Actions

- Build Chart
  - Follow In-Toto Pattern
  - Use GH Attestation to attest In-Toto provenance result
  - Store Attestation ID in PR Description as Markdown Code Comment
    - NOTE: If Attested again, overwrite original Attestation ID for this 'check' in PR; ie. each unique 'check' gets its own GH Attestation ID Key
- Overall Attestation@SHA

---

## Workflow 8: Atomic Release Publishing

### Triggers

- Merge: `Release`

### Checks

### Rulesets

- `Release` protected from deletion; No admin bypass
- `Release` protected from push/force-push; No admin bypass

### Actions

- Publish Chart TAR from latest on `Release` branch -> GHCR
- Publish Chart TAR from latest on `Release` branch -> GH Release (Immutable)
  - Assets
    - Attestation Lineage
    - Development Diff Lineage (in tree; not squashed)
    - Chart TAR
    - CHANGELOG
    - README.md
    - Chart LICENSE

---

# Questions

1. What controls exist to prevent making a commit w/ more than 1 directory in it? (ex: no chart-foo && chart-bar in 1 commit)
2. W1: Linting, Formatting, Validation
3. W3: Per-chart Security scans, per-chart testing, etc
4. Advanced feature blocking logic for git management; Ex: Feats A, B, & C are being worked on simultaneously for the same chart. To remain atomic, they should be introduced individually. But currently logic forwards all changes for same chart to same branch. Need to add a way to handle either seqentially gating or parallelizing the feature blocks contributions and versionings.

---

# Repo Automations

1. Weekly Stale PR cleanup
2. Triggered/automatic merging of dependabot like PRs

---

# TODOs

- Revisit / Review "attestation lineage" pattern/approach.
  - How do/should we propagate the attestations map from source PR to per-chart PRs through to Releases?
- Revisit / brainstorm how to handle '**Complex** charts' that have external dependencies, when trying to 'ct install'
- SKILL: `k8s-helm-charts-dev/`
  - assets/patterns/external-database.yaml : add additional for different database types (mysql vs postgres, relational vs graph, etc)
  - assets/patterns/external-database.yaml : add additional for different search systesm (SaaS vs Self Hosted, Meilisearch, Typesense)
- `k8s-install-test` - Matrix job testing chart installation on K8s 1.32, 1.33, 1.34
  - Support passing K8s X.Y ver and determining latest PATCH for each
- Revisit / brainstorm how to detect / flag LARGE PRs that should be split for atomicity. ie This PR contains ~100 commits, that when squashed contain ~300 lines of code -> its TOO BIG, should probably be split into smaller PRs
- Brainstorm PR Lineage discovery pattern (ie 'Source PR Discovery')
- Brainstorm Queueing multiple "same chart different tags" for release
- Ensure /create-helm-chart defaults to targeting `aRustyDev/helm-charts` for PRs, Issues, Contributions, etc
- Automate updating Repo README w/ current charts + current/latest versions in the 'Available Charts' table
- Automate updating Repo README w/ chart endpoints
- Brainstorm and consider adding chart specific usage guides from `docs/` to the `<chart>.tgz` during release builds
- Review+Audit the Attestation Framework/pattern
  - MUST follow in-toto pattern
    - In-toto wraps the command `cat foo.txt`,
    - hashes the contents of the source code, i.e. `demo-project/foo.py`
    - adds the hash together with other information to a metadata file
    - signs the metadata with `GITHUB_APP` private key
    - stores everything to `clone.[GHApp keyid].link`.
- Create Claude Hooks for
  - Secrets Scanning: Gitleaks / trufflehog
  - Commit Linting: ConventionalCommit / CommitLint
  - EditorConfig linting
  - Markdown Linting
  - Markdown Link Checker
- Review Project Board Labels & Issue Tracking Integration
- `integration` automation
  - [x] `charts/**`: `integration -> charts/<chart>`
  - [ ] `.github/**` / CI stuff: `integration -> gh/<scope>`
  - [ ] `docs/**`: `integration -> docs/<scope>`
  - [ ] `.claude/**` / AI Stuff: `integration -> ai/<scope>`
  - [ ] ELSE
- Update `.helmignore`?
- Repo Rulesets
  - Require linear history
  - Require signed commits
  - Require a pull request before merging
  - Require branches to be up to date before merging
- `Changelog Preview`
  - needs to update its existing comment not create new comment each run for same PR
  - Needs Keep-A-Changelog format
  - Q: what creates this? Git-Cliff?
- K8s test failure: The attestation step uses github.sha (git commit, 40 chars) instead of a proper SHA256 hash (64 chars).
- W5 not auto-triggering: The PR was created by W2 via the GitHub API, which may not trigger workflows the same way as manual PR creation.

- fork vs copy-local decision framework
- Prefer Contributing back to community > purely private work
- Prefer Atomic work contributions
- Research Phase workflow
  - information gathering checklist
  - Formal research plan
  - review/refine cycle
  - approval gates
  - structured documentation
- Planning Phase workflow
  - No high-level plan creation
  - No atomic component identification
  - No phase plans
  - No approval gates
  - No issue mapping
- Implementation Phase checkpoints
  - Has worktree workflow and PR creation
  - Issue assignment
  - draft PR at start
  - formal sanity checks
  - external review stops

---

- Create main issue in repo, with child issues for each atomic work item
- PR per child item
- (?): Add GitHub Project integration?

- W8: Publish to GHCR and create GitHub Releases
- Remove dev artifacts like `workflow_dispatch trigger`
- commit-validation failed again (same issue with historical commits).
- The PR creation failed because the automated label doesn't exist.
- update `promote` -> `charts` in W2
  - The charts branch exists for the Helm repo index, so we can't create charts/<chart> branches. Let me update W2 to use promote/<chart> instead.

---

| Category             | Tool (Open Source / Free)   | Focus                     |
| -------------------- | --------------------------- | ------------------------- |
| SBOM                 | Syft, Tern                  | SBOM generation           |
| SCA                  | Grype                       | Vulnerability scanning    |
| Image Lint           | Dockle                      | Best practices            |
| Kubernetes/Helm Lint | KubeLinter, Datree, kubeval | YAML/Helm checks          |
| Secret Detection     | Semgrep, Gitleaks           | Secrets in code/manifests |
| Static Code SAST     | Semgrep, SonarQube OSS      | Code security             |
| Policy Enforcement   | Kyverno, OPA                | CI/Runtime policies       |

| status | Category             | Tool (Open Source / Free)   | Workflow | Focus                     |
| ------ | -------------------- | --------------------------- | -------- | ------------------------- |
| [✅]   | SBOM                 | Syft                        | Wx       | SBOM generation           |
| [✅]   | SBOM                 | Tern                        | Wx       | SBOM generation           |
| [✅]   | SCA                  | Grype                       | Wx       | Vulnerability scanning    |
| [✅]   | Image Lint           | Dockle                      | Wx       | Best practices            |
| [✅]   | Kubernetes/Helm Lint | KubeLinter, Datree, kubeval | Wx       | YAML/Helm checks          |
| [✅]   | Secret Detection     | Semgrep, Gitleaks           | Wx       | Secrets in code/manifests |
| [✅]   | Static Code SAST     | Semgrep, SonarQube OSS      | Wx       | Code security             |
| [✅]   | Policy Enforcement   | Kyverno, OPA                | Wx       | CI/Runtime policies       |

- Nuclei – Fast template-based vulnerability discovery.
- Dradis Framework – Collaboration/reporting hub for security findings from many scanners.
- SonarQube (OSS) – Static analysis including security hotspots and quality issues (more general).
- Gitleaks – Repo and filesystem secret scanners (not Helm specific but useful in pipelines).
- TruffleHog – Repo and filesystem secret scanners (not Helm specific but useful in pipelines).
  - https://www.reddit.com/r/devops/comments/1l2briw?utm_source=chatgpt.com
- Trivy – Widely adopted, scans OS packages, app deps, secrets, misconfiguration, and generates SBOMs.
- Anchore – Alternative open scanners (Clair is CNCF-hosted static analysis; Anchore has rich policy engine).
- Clair – Alternative open scanners (Clair is CNCF-hosted static analysis; Anchore has rich policy engine).
- Dockle – Linter for container images focusing on security best practices (not CVE scanning).
- Gatekeeper - Policy-as-code engines you can use to block unsafe configs.
- OPA - Policy-as-code engines you can use to block unsafe configs.
  - Try to include policy configs to support these (Not directly a linter but excellent for admission control.)
- KubeLinter – Static analysis for Kubernetes manifests and Helm charts.
- Datree – Policy-driven manifest/Helm validation tool.
- Kube-score – Lightweight static checks on Kubernetes objects.
- kubeval – Validates config against Kubernetes API schemas.
- chart-testing (ct) – Helm project’s testing utility (lint/test charts on PRs).
- Syft – Open-source CLI and Go library for SBOM generation from container images and filesystems (supports SPDX & CycloneDX).
- Grype – Vulnerability scanner that works standalone or on Syft SBOMs; common for container images and filesystem scans.
- Tern – SBOM tool focused on container image inspection.
- CycloneDX ecosystem tools (e.g., Tally, ts-scan) – CLI tools for producing, decorating, and scoring CycloneDX SBOMs.
- ScanCode Toolkit - Gold standard for license detection
- Hadolint
- SCAP
- Kube-bench
- Grafeas
- GreenBone OpenVAS
- Notary
- Kubesec
- Vuls
- [Anchore](https://github.com/anchore/anchore-engine)
- [kube-hunter](https://www.wiz.io/academy/kube-hunter-overview)

## Hooks

- Syft
- Grype
- [tern](https://www.wiz.io/academy/top-open-source-sbom-tools#3-tern-30)
- TBD
  - https://www.wiz.io/academy/top-open-source-sbom-tools#2-the-sbom-tool-28

## W1

## W2

## W5

- OPA
- Gatekeeper

## W6


## License Scanning

https://www.wiz.io/academy/standard-sbom-formats

- [SPDX](https://spdx.dev/) by the Linux Foundation, which has a focus on software licenses.
- [CycloneDX](https://cyclonedx.org/) by OWASP, which focuses on security vulnerabilities.
- [SWID](https://csrc.nist.gov/projects/Software-Identification-SWID) by NIST, which does not have one particular emphasis.

### Stage Hooks: **Syft**

### Stage W1: (PR -> Integration)

#### Case: Label(`automation`+`dependency`) -> Dependency Update `charts/**`: **ScanCode**

```bash
scancode --license --json scancode.json ./repo
```

#### Case: else

```bash
# Generate SBOM with licenses
syft image:myimage -o cyclonedx-json > sbom.json

# Validate SBOM structure
cyclonedx-cli validate --input-file sbom.json
cyclonedx-cli analyze --input-file sbom.json


# License policy check
opa eval \
  --data license-policy.rego \
  --input sbom.json \
  "data.license.allow"
```

---
