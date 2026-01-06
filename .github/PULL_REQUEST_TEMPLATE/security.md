## Security Fix

**Severity:** <!-- Critical / High / Medium / Low -->
**CVE (if applicable):** <!-- e.g., CVE-2024-XXXXX -->
**Affected Chart(s):** <!-- e.g., holmes, mdbook-htmx -->
**Affected Versions:** <!-- e.g., < 0.2.0 -->

### Vulnerability Description

<!-- Describe the security issue being fixed -->

### Impact

<!-- What could an attacker do? What is the blast radius? -->

### Fix Description

<!-- Describe how this PR fixes the vulnerability -->

### Verification

<!-- How can reviewers verify the fix works? -->

```bash
# Commands to verify the fix
```

### Testing

- [ ] Vulnerability no longer exploitable
- [ ] `helm lint` passes
- [ ] `helm template` renders correctly
- [ ] No regression in functionality
- [ ] Tested installation on local cluster

### Disclosure

- [ ] Coordinated with upstream (if applicable)
- [ ] Security advisory drafted (for Critical/High)
- [ ] Users notified through appropriate channels

### Checklist

- [ ] Chart version bumped appropriately
- [ ] CHANGELOG documents security fix
- [ ] Commit message references CVE (if applicable)

Fixes #<!-- issue number -->
