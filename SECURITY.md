# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.x.x   | :white_check_mark: (development) |

## Reporting a Vulnerability

If you discover a security vulnerability in FormDB, please report it responsibly:

1. **Do NOT** open a public GitHub issue
2. Email security concerns to the maintainers
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

## Security Considerations

FormDB is designed with security as a core principle:

### Auditability
- All mutations are journaled before commitment
- Full provenance tracking for all data
- Deterministic rendering for human verification

### Reversibility
- Every operation has a defined inverse
- Irreversible operations are explicitly marked
- Complete history is preserved

### Constraint Enforcement
- Constraints are enforced at the bridge layer
- Rejections include explanations
- No silent failures

## Development Security

- Dependencies are pinned to specific versions/SHAs
- All workflows use SHA-pinned GitHub Actions
- SPDX license headers on all source files
