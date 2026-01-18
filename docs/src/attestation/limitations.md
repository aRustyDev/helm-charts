# Limitations

Attestations provide strong guarantees about *how* an artifact was built, but they have important limitations. Understanding what attestations do NOT prove is essential for a complete security posture.

## What Attestations Are NOT

### Not a Security Audit

```
┌─────────────────────────────────────────────────────────────────────────┐
│  ATTESTATION ≠ SECURITY AUDIT                                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Attestation proves:                                                    │
│    "This chart was built by GitHub Actions from commit abc123"          │
│                                                                         │
│  Attestation does NOT prove:                                            │
│    "This chart is secure and free of vulnerabilities"                   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

A valid attestation means the build process was trusted. It says nothing about whether the source code itself is safe.

### Not a Vulnerability Scan

Attestations do not scan for:
- CVEs in the chart templates
- Insecure default configurations
- Vulnerable base images referenced in values.yaml
- Hardcoded secrets or credentials
- RBAC misconfigurations

**You should still run**:
```bash
# Scan for vulnerabilities
trivy config charts/cloudflared/
grype charts/cloudflared/

# Check for misconfigurations
kubescape scan charts/cloudflared/
checkov -d charts/cloudflared/
```

### Not a Code Review

Attestations prove the workflow ran, but they don't prove:
- Code was reviewed by a human (for non-main branches)
- Business logic is correct
- Best practices were followed
- The change does what the commit message claims

### Not an Identity Verification

GitHub attestations verify the *GitHub account*, not the person behind it:

| What We Know | What We Don't Know |
|--------------|-------------------|
| GitHub user `@contributor` committed this | Who controls that account |
| Commits were signed with their GPG/SSH key | If their key was compromised |
| They're listed in CODEOWNERS (for auto-merge) | Their real-world identity |

### Not Runtime Security

Attestations cover build-time only:

```
                    ATTESTATION COVERAGE
                    ════════════════════

  Source Code ──→ Build ──→ Package ──→ Deploy ──→ Runtime
       │            │          │           │          │
       │      [ATTESTED]  [ATTESTED]       │          │
       │            │          │           │          │
       ▼            ▼          ▼           ▼          ▼
    Unknown     Verified    Verified   Unknown    Unknown
```

What happens after deployment is outside attestation scope:
- Container behavior at runtime
- Network connections made
- Data accessed or exfiltrated
- Resource consumption

## Not Possible with Current Implementation

### Verifying Upstream Images

If a chart's `values.yaml` references:
```yaml
image:
  repository: nginx
  tag: "1.25"
```

The attestation proves the *chart template* came from our repo, but NOT that:
- The nginx image is legitimate
- The image tag hasn't been changed since we tested
- The image is free of vulnerabilities

**Mitigation**: Pin images by digest in your values:
```yaml
image:
  repository: nginx@sha256:abc123...
```

### Proving Source Code Wasn't Malicious

A sophisticated attacker could:
1. Compromise a trusted contributor's GitHub account
2. Submit malicious code with valid GPG signatures
3. The code passes linting (syntax is valid)
4. Tests pass (malicious code activates only in prod)
5. Attestation is generated - everything looks legitimate

The attestation proves the *process* was followed, not that the *code* is safe.

### Proving Dependencies Are Safe

Charts may have dependencies in `Chart.yaml`:
```yaml
dependencies:
  - name: common
    version: "1.x.x"
    repository: "https://charts.bitnami.com/bitnami"
```

Attestations don't verify:
- The external repository is trustworthy
- The dependency hasn't been compromised
- Transitive dependencies are safe

### Verifying Helm Repository Index

The `index.yaml` at `charts.arusty.dev` is NOT signed. It's served from the `release` branch.

Attack vector:
1. Attacker gains write access to `release` branch
2. Modifies `index.yaml` to point to malicious packages
3. Users who `helm install` without verification get bad charts

**Mitigation**: Always verify after download:
```bash
helm pull arustydev/cloudflared
gh attestation verify cloudflared-*.tgz --repo aRustyDev/helm-charts
helm install ... --verify  # Note: --verify uses provenance files, not attestations
```

## What Attestations Don't Cover

| Aspect | Covered? | Details |
|--------|----------|---------|
| Build integrity | Yes | Package matches build output |
| Build source | Yes | Built from specific commit |
| Build environment | Yes | GitHub Actions runner |
| Test execution | Yes | Tests ran (via attestation map) |
| Test correctness | No | Tests might miss bugs |
| Code security | No | No vulnerability scanning |
| Business logic | No | No semantic verification |
| Runtime behavior | No | Only build-time |
| Upstream images | No | Referenced images not verified |
| Dependencies | No | External chart repos not verified |
| Future changes | No | Attestation is point-in-time |

## The Trust Boundary

```
┌───────────────────────────────────────────────────────────────────────────┐
│                           TRUST BOUNDARY                                   │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│   INSIDE (Attested)              │    OUTSIDE (Not Attested)              │
│   ─────────────────              │    ──────────────────────              │
│                                  │                                        │
│   • This repository's code       │    • External chart dependencies       │
│   • GitHub Actions workflows     │    • Referenced container images       │
│   • Build process execution      │    • Helm repository index.yaml        │
│   • Test execution (recorded)    │    • User-provided values              │
│   • Package creation             │    • Deployment environment            │
│   • Cosign signature             │    • Runtime behavior                  │
│   • GitHub artifact attestation  │    • Network connections               │
│                                  │    • Data handling                     │
│                                  │                                        │
└───────────────────────────────────────────────────────────────────────────┘
```

## Recommendations for Complete Security

### 1. Verify Attestations (What We Provide)

```bash
cosign verify ghcr.io/arustydev/helm-charts/cloudflared:1.0.0 \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp "github.com/aRustyDev/helm-charts"
```

### 2. Scan for Vulnerabilities (What You Must Do)

```bash
# Scan chart templates
trivy config charts/cloudflared/

# Scan referenced images
trivy image nginx:1.25

# Check Kubernetes security
kubescape scan charts/cloudflared/
```

### 3. Review Changes (For Critical Deployments)

```bash
# Get the source PR
gh pr view <pr-number> --repo aRustyDev/helm-charts

# Review the actual changes
gh pr diff <pr-number> --repo aRustyDev/helm-charts
```

### 4. Pin Dependencies

```yaml
# In values.yaml - pin by digest
image:
  repository: nginx
  digest: sha256:abc123...  # Instead of tag

# In Chart.yaml - pin versions
dependencies:
  - name: common
    version: "1.2.3"  # Exact version, not "1.x.x"
```

### 5. Use Admission Controllers

Deploy verification at cluster level:
- [Sigstore Policy Controller](https://docs.sigstore.dev/policy-controller/overview/)
- [Kyverno](https://kyverno.io/docs/writing-policies/verify-images/)
- [Connaisseur](https://github.com/sse-secure-systems/connaisseur)

## Summary

| Statement | True? |
|-----------|-------|
| "This chart was built by our GitHub Actions" | Yes |
| "This chart passed our CI tests" | Yes |
| "This chart is secure" | Not proven |
| "This chart has no vulnerabilities" | Not proven |
| "The referenced images are safe" | Not proven |
| "The chart will behave correctly at runtime" | Not proven |

**Attestations are necessary but not sufficient for security.** They should be part of a defense-in-depth strategy that includes vulnerability scanning, code review, runtime monitoring, and least-privilege deployment.
