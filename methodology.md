# Web Reconnaissance Methodology

## Overview

This project follows a structured reconnaissance methodology designed to identify and organize a web application's external attack surface before manual security testing.

The methodology is divided into two major areas:

```text
Automated Reconnaissance
        ↓
Manual Security Testing
```

---

# Phase 1 — Asset Discovery

## 1. Subdomain Enumeration

Multiple independent sources are used to increase discovery coverage.

Tools:

* Subfinder
* Assetfinder
* Amass
* Certificate Transparency via crt.sh

The results are normalized and deduplicated.

```text
subdomains
    ↓
normalize
    ↓
deduplicate
    ↓
01-subdomains.txt
```

---

# Phase 2 — Host Validation

## 2. DNS Resolution

Discovered subdomains are checked for DNS resolution.

Tool:

```text
dnsx
```

Purpose:

* Identify currently resolving hosts.
* Collect DNS/IP information.
* Separate discovered names from resolving infrastructure.

---

## 3. HTTP Probing

HTTP services are identified using ProjectDiscovery httpx.

Collected information includes:

* URL
* HTTP status
* Page title
* Technology detection
* Web server information
* Redirect behavior

The output is used to prioritize hosts for further investigation.

---

# Phase 3 — URL Discovery

## 4. Crawling

Live applications are crawled using Katana.

The goal is to identify:

* Application routes
* Links
* Forms
* API paths
* JavaScript references
* Parameters
* Additional URLs

---

## 5. Historical URLs

Public historical sources are queried using:

* GAU
* Waybackurls

Historical URLs can provide information about previous application functionality.

These URLs should be treated as leads rather than evidence that the endpoint still exists.

---

# Phase 4 — Client-Side Analysis

## 6. JavaScript Discovery

JavaScript URLs are extracted from the collected URL set.

JavaScript analysis may reveal:

* API routes
* Client-side endpoints
* Parameters
* Application logic
* References to external services

---

## 7. LinkFinder

LinkFinder is used to identify endpoints and paths referenced in JavaScript.

Results require manual verification.

---

## 8. SecretFinder

SecretFinder is used to identify potentially sensitive patterns.

Every result must be manually verified.

A pattern match does not automatically represent a credential, secret, or vulnerability.

---

# Phase 5 — Parameter Discovery

## 9. GF

GF is used to prioritize URLs containing interesting parameter patterns.

Examples:

```text
redirect
ssrf
sqli
xss
lfi
rce
ssti
idor
```

The purpose is prioritization rather than exploitation.

---

## 10. Arjun

Arjun is used to identify potentially undocumented HTTP parameters.

Results should be manually tested and validated.

---

# Phase 6 — Manual Testing

Automated reconnaissance ends before vulnerability validation.

Burp Suite is used to manually investigate interesting targets.

---

## Authentication

Investigate:

* Login mechanisms
* Session handling
* Access tokens
* Refresh tokens
* Password reset
* Account recovery
* MFA implementation
* Session invalidation

---

## Authorization

Investigate whether users can access resources or functionality they should not have access to.

Areas of interest include:

* Horizontal access control
* Vertical access control
* Object-level authorization
* Function-level authorization
* API authorization

---

## API Testing

Identify:

* REST APIs
* GraphQL endpoints
* API versions
* Hidden API routes
* API parameters
* Authentication mechanisms

Then manually assess their security controls.

---

## Business Logic

Automated tools are generally insufficient for understanding application-specific business rules.

Manual testing should investigate:

* Workflow manipulation
* State transitions
* Quantity manipulation
* Repeated actions
* Race conditions
* Trust boundaries
* Multi-step workflows

---

# Validation

Potential findings should be validated carefully.

The process should be:

```text
Observation
    ↓
Reproduce
    ↓
Understand Root Cause
    ↓
Determine Security Impact
    ↓
Confirm Scope
    ↓
Minimize Test Impact
    ↓
Document Evidence
    ↓
Report
```

---

# Reporting

A useful security report should clearly describe:

1. Vulnerability
2. Affected asset
3. Preconditions
4. Reproduction steps
5. Security impact
6. Evidence
7. Suggested remediation

---

# Important Principle

Reconnaissance identifies possibilities.

Manual testing determines whether those possibilities represent actual security issues.

Therefore:

```text
Automation → Discovery
Human analysis → Validation
```
