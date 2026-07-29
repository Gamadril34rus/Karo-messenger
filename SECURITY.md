# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability in ЧАРО, please report it responsibly.

### How to Report

**Do NOT** open a public GitHub issue for security vulnerabilities.

Instead, please:

1. **Email**: Send details to security@charo.chat
2. **PGP**: Encrypt your report using our public key (available at https://charo.chat/.well-known/pgp-key.txt)
3. **Response time**: We will acknowledge receipt within 24 hours and provide a detailed response within 72 hours

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Affected versions
- Potential impact
- Any suggested fixes (optional)

### Our Commitment

- We will investigate all legitimate reports
- We will keep you informed of our progress
- We will credit you in our security advisories (unless you prefer anonymity)
- We will not take legal action against researchers who act in good faith

### Scope

**In scope:**
- ЧАРО server (Fastify API)
- ЧАРО client (Flutter)
- Authentication & authorization bypasses
- E2EE implementation flaws
- Data exposure vulnerabilities
- Denial of service vulnerabilities
- Injection vulnerabilities

**Out of scope:**
- Social engineering attacks
- Physical attacks
- Attacks requiring privileged access to server infrastructure
- Vulnerabilities in third-party services (report to them directly)

### Bug Bounty

We are currently evaluating a bug bounty program. Until then, we offer our gratitude and public acknowledgment for responsible disclosures.

## Security Best Practices

When deploying ЧАРО:

1. **Always** change default JWT secrets
2. **Always** use HTTPS in production
3. **Always** set strong database passwords
4. **Never** expose Redis or PostgreSQL ports to the public internet
5. **Always** keep dependencies up to date
6. **Always** enable rate limiting
7. **Review** your `.env` file for sensitive values before deployment
