# Web Recon Framework

An automated web reconnaissance framework for **authorized penetration testing, security research, and bug bounty reconnaissance**.

The framework automates the repetitive parts of web reconnaissance while leaving vulnerability validation, authentication testing, authorization testing, business-logic testing, and impact assessment to manual analysis.

---

## Features

The framework performs reconnaissance in a structured pipeline:

```text
Subdomain Enumeration
        ↓
DNS Resolution
        ↓
HTTP Probing
        ↓
Technology Fingerprinting
        ↓
Web Crawling
        ↓
Historical URL Discovery
        ↓
JavaScript Discovery
        ↓
JavaScript Endpoint Analysis
        ↓
Secret Pattern Analysis
        ↓
Interesting Parameter Filtering
        ↓
Parameter Discovery
        ↓
Structured Reconnaissance Report
```

---

## Reconnaissance Workflow

### Stage 1 — Attack Surface Discovery

The framework identifies potential assets belonging to the target domain.

Tools used:

* Subfinder
* Assetfinder
* Amass
* crt.sh

Output:

```text
01-subdomains.txt
```

---

### Stage 2 — DNS Resolution

Discovered subdomains are checked for DNS records and resolved addresses.

Tool:

* dnsx

Output:

```text
02-dns.txt
```

This helps distinguish discovered names from hosts that currently resolve.

---

### Stage 3 — HTTP Probing and Fingerprinting

The framework checks discovered hosts for HTTP/HTTPS services and collects:

* HTTP status code
* Page title
* Technologies
* Web server information
* Redirect behavior
* Live URLs

Tool:

* ProjectDiscovery httpx

Output:

```text
03-http.txt
03-live.txt
```

ProjectDiscovery's `httpx` binary is explicitly referenced by the script to avoid conflicts with the Python package also named `httpx`.

---

### Stage 4 — Web Crawling

Live websites are crawled to identify accessible URLs and application paths.

Tool:

* Katana

Output:

```text
04-crawl.txt
```

The crawler is configured with controlled depth and concurrency to reduce unnecessary traffic and execution time.

---

### Stage 5 — Historical URL Discovery

Previously indexed URLs are collected from public sources.

Tools:

* GAU
* Waybackurls

Output:

```text
05-historical.txt
05-all-urls.txt
```

Historical URLs can reveal:

* Older application paths
* Legacy endpoints
* Deprecated functionality
* Previously exposed parameters
* Old JavaScript files

---

### Stage 6 — JavaScript Discovery

JavaScript URLs are extracted from discovered URLs.

Output:

```text
06-js.txt
```

JavaScript files can contain references to:

* API endpoints
* Application routes
* Internal paths
* Parameters
* Client-side functionality

---

### Stage 7 — JavaScript Endpoint Analysis

LinkFinder is used to identify endpoints and paths referenced inside JavaScript resources.

Tool:

* LinkFinder

Output:

```text
07-linkfinder.txt
```

---

### Stage 8 — Secret Pattern Analysis

SecretFinder is used to identify potentially interesting patterns within JavaScript resources.

Tool:

* SecretFinder

Output:

```text
08-secretfinder.txt
```

Results require manual verification. A detected string or pattern is **not automatically considered a vulnerability or valid secret**.

---

### Stage 9 — Interesting Parameter Filtering

Discovered URLs are filtered using GF patterns.

Tool:

* GF

Patterns include categories such as:

```text
interestingparams
redirect
ssrf
sqli
xss
lfi
rce
ssti
idor
```

Output:

```text
09-gf.txt
```

GF is used for prioritization and filtering, not automatic vulnerability confirmation.

---

### Stage 10 — Parameter Discovery

Arjun is used against a limited set of prioritized URLs to identify potentially undocumented parameters.

Tool:

* Arjun

Output:

```text
10-arjun.txt
```

The number of automated targets is intentionally limited to prevent excessive requests and unnecessarily long scans.

---

# HTTP Status Prioritization

The framework categorizes HTTP responses to help prioritize manual testing.

| Status | Meaning                          | Manual Priority |
| ------ | -------------------------------- | --------------- |
| 200    | Successful response              | High            |
| 201    | Resource created                 | High            |
| 204    | Successful response without body | Medium          |
| 301    | Permanent redirect               | Medium          |
| 302    | Temporary redirect               | Medium          |
| 307    | Temporary redirect               | Medium          |
| 308    | Permanent redirect               | Medium          |
| 401    | Authentication required          | High            |
| 403    | Access denied                    | High            |
| 404    | Not found                        | Medium          |
| 405    | Method not allowed               | Medium          |
| 429    | Rate limited                     | Low/Medium      |
| 500    | Server error                     | High            |
| 502    | Bad gateway                      | Medium          |
| 503    | Service unavailable              | Medium          |

HTTP status codes are used for **prioritization only**. A status code by itself does not indicate a vulnerability.

---

# Output Structure

Each target receives its own directory.

Example:

```text
~/recon/example.com/
```

The directory contains:

```text
01-subdomains.txt
02-dns.txt
03-http.txt
03-live.txt
04-crawl.txt
05-historical.txt
05-all-urls.txt
06-js.txt
07-linkfinder.txt
08-secretfinder.txt
09-gf.txt
10-arjun.txt
status-summary.txt
interesting-hosts.txt
tool-versions.txt
recon.log
recon-report.txt
```

---

# Installation

The framework expects the required reconnaissance tools to already be installed.

Required tools:

```text
subfinder
assetfinder
amass
dnsx
httpx
katana
gau
waybackurls
gf
arjun
```

Additional tools:

```text
ffuf
LinkFinder
SecretFinder
```

The ProjectDiscovery tools should preferably be installed in:

```text
~/go/bin/
```

The script explicitly uses:

```text
~/go/bin/httpx
```

to avoid conflicts with the Python `httpx` command.

---

# Usage

Make the script executable:

```bash
chmod +x recon.sh
```

Run against an authorized target:

```bash
./recon.sh --domain example.com
```

Specify a custom output directory:

```bash
./recon.sh --domain example.com --output ~/recon
```

Example:

```bash
./recon.sh --domain example.com
```

Results will be stored in:

```text
~/recon/example.com/
```

---

# Final Report

The main report is:

```text
recon-report.txt
```

It provides:

* Target information
* Scan duration
* Subdomain count
* DNS results
* Live hosts
* Crawled URLs
* Historical URLs
* JavaScript count
* LinkFinder results
* SecretFinder results
* GF results
* HTTP status summary
* Interesting hosts
* Output file locations
* Recommended manual testing priorities

---

# Manual Testing Phase

Automated reconnaissance is only the beginning of a penetration test.

After reconnaissance, interesting targets should be manually investigated using tools such as Burp Suite.

Recommended workflow:

```text
Recon
 ↓
Identify Interesting Hosts
 ↓
Browse Application
 ↓
Map Application Functionality
 ↓
Intercept Requests
 ↓
Authentication Testing
 ↓
Authorization Testing
 ↓
API Testing
 ↓
Input Validation Testing
 ↓
Business Logic Testing
 ↓
Manual Vulnerability Validation
 ↓
Impact Assessment
 ↓
Report
```

The framework deliberately does **not** attempt to automatically exploit vulnerabilities.

---

# Responsible Use

This project is intended for:

* Authorized penetration testing
* Bug bounty programs within their published scope
* Security research
* CTFs
* Intentionally vulnerable environments
* Systems owned or explicitly authorized for testing

Do not use this framework against systems without permission.

The user is responsible for ensuring that all testing is authorized and complies with applicable laws, rules, and program policies.

---

# Limitations

Automated reconnaissance cannot reliably determine whether a finding is a vulnerability.

For example:

```text
403 ≠ vulnerability
200 ≠ vulnerability
Interesting parameter ≠ vulnerability
SecretFinder match ≠ valid secret
GF result ≠ confirmed vulnerability
Arjun parameter ≠ vulnerable parameter
```

All potentially interesting results require manual verification.

Network conditions, rate limits, WAFs, application behavior, DNS changes, and third-party services can also affect results.

---

# Project Goals

The goals of this project are:

1. Reduce repetitive reconnaissance tasks.
2. Organize reconnaissance results.
3. Improve attack-surface visibility.
4. Prioritize interesting hosts and URLs.
5. Produce consistent reports.
6. Provide a foundation for future reconnaissance automation.
7. Keep vulnerability validation under human control.

---

# Future Improvements

Possible future versions may include:

* Better scope validation
* Configurable rate limiting
* Improved URL normalization
* Screenshot collection
* Asset categorization
* API endpoint classification
* Better JavaScript processing
* Technology-specific wordlists
* Improved report formatting
* JSON output
* CSV output
* HTML reporting
* Docker support
* Configuration file support
* Resume capability for interrupted scans
* Better error handling
* Performance optimization

---

# Author

**Deepanshu Deswal**

Cybersecurity Student | Security Researcher

---

# Disclaimer

This tool is provided for educational and authorized security testing purposes.

Only scan systems for which you have explicit permission or systems that are clearly within the scope of an authorized security program.

The author is not responsible for misuse of this software.



