#!/bin/bash
set -Eeuo pipefail

# ============================================================
# WEB RECON FRAMEWORK v2
# Authorized penetration testing / bug bounty / labs only
#
# Pipeline:
#   Subdomain Enumeration
#       ↓
#   DNS Resolution
#       ↓
#   HTTP Probing + Fingerprinting
#       ↓
#   Crawling
#       ↓
#   Historical URLs
#       ↓
#   JavaScript Discovery
#       ↓
#   LinkFinder / SecretFinder
#       ↓
#   GF Parameter Filtering
#       ↓
#   Arjun Parameter Discovery
#       ↓
#   Structured Report
#
# No exploitation is performed by this script.
# ============================================================


# ============================================================
# DEFAULT CONFIGURATION
# ============================================================

BASE_OUTPUT="$HOME/recon"

KATANA_DEPTH=2
KATANA_TIMEOUT=60
KATANA_CONCURRENCY=10

HTTPX_THREADS=25
HTTPX_TIMEOUT=10

ARJUN_THREADS=5
ARJUN_TIMEOUT=10

MAX_FUZZ_TARGETS=20

# Explicit ProjectDiscovery binaries
HTTPX="$HOME/go/bin/httpx"
KATANA="$HOME/go/bin/katana"
DNSX="$HOME/go/bin/dnsx"
SUBFINDER="$HOME/go/bin/subfinder"
AMASS="$HOME/go/bin/amass"
GAU="$HOME/go/bin/gau"
WAYBACKURLS="$HOME/go/bin/waybackurls"
GF="$HOME/go/bin/gf"

ASSETFINDER="$(command -v assetfinder 2>/dev/null || true)"
FFUF="$(command -v ffuf 2>/dev/null || true)"
ARJUN="$(command -v arjun 2>/dev/null || true)"

LINKFINDER="$HOME/LinkFinder/linkfinder.py"
SECRETFINDER="$HOME/SecretFinder/SecretFinder.py"


# ============================================================
# COLORS
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'


# ============================================================
# FUNCTIONS
# ============================================================

usage() {
    cat <<EOF

Usage:
    $0 --domain example.com

Options:
    -d, --domain DOMAIN     Target domain
    -o, --output DIR        Output directory
    -h, --help              Show help

Example:
    $0 --domain example.com

Output:
    ~/recon/example.com/

EOF
}


log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}


success() {
    echo -e "${GREEN}[+]${NC} $1" | tee -a "$LOG_FILE"
}


warn() {
    echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"
}


error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" >&2
}


count_lines() {
    if [ -f "$1" ]; then
        wc -l < "$1" | tr -d ' '
    else
        echo "0"
    fi
}


require_file() {
    if [ ! -f "$1" ]; then
        touch "$1"
    fi
}


# ============================================================
# ARGUMENT PARSING
# ============================================================

DOMAIN=""

while [[ $# -gt 0 ]]; do

    case "$1" in

        -d|--domain)
            if [[ -z "${2:-}" ]]; then
                echo "[ERROR] --domain requires a value"
                exit 1
            fi

            DOMAIN="$2"
            shift 2
            ;;

        -o|--output)
            if [[ -z "${2:-}" ]]; then
                echo "[ERROR] --output requires a directory"
                exit 1
            fi

            BASE_OUTPUT="$2"
            shift 2
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        *)
            echo "[ERROR] Unknown option: $1"
            usage
            exit 1
            ;;

    esac

done


# ============================================================
# TARGET VALIDATION
# ============================================================

if [[ -z "$DOMAIN" ]]; then
    echo "[ERROR] Target domain not specified."
    usage
    exit 1
fi


# Remove protocol if supplied
DOMAIN="${DOMAIN#http://}"
DOMAIN="${DOMAIN#https://}"

# Remove trailing slash
DOMAIN="${DOMAIN%/}"

# Basic domain validation
if [[ ! "$DOMAIN" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    echo "[ERROR] Invalid domain: $DOMAIN"
    exit 1
fi


# Prevent accidental wildcard / path input
if [[ "$DOMAIN" == *"*"* || "$DOMAIN" == *"/"* ]]; then
    echo "[ERROR] Please provide a domain only."
    exit 1
fi


# ============================================================
# OUTPUT DIRECTORY
# ============================================================

TARGET_DIR="$BASE_OUTPUT/$DOMAIN"

mkdir -p "$TARGET_DIR"

LOG_FILE="$TARGET_DIR/recon.log"

touch "$LOG_FILE"


# ============================================================
# OUTPUT FILES
# ============================================================

SUBDOMAINS="$TARGET_DIR/01-subdomains.txt"
DNS="$TARGET_DIR/02-dns.txt"
HTTP="$TARGET_DIR/03-http.txt"
LIVE="$TARGET_DIR/03-live.txt"

CRAWL="$TARGET_DIR/04-crawl.txt"
HISTORICAL="$TARGET_DIR/05-historical.txt"

JS="$TARGET_DIR/06-js.txt"

LINKFINDER_OUT="$TARGET_DIR/07-linkfinder.txt"
SECRETFINDER_OUT="$TARGET_DIR/08-secretfinder.txt"

GF_OUT="$TARGET_DIR/09-gf.txt"
ARJUN_OUT="$TARGET_DIR/10-arjun.txt"

REPORT="$TARGET_DIR/recon-report.txt"


# ============================================================
# CLEANUP / ERROR HANDLING
# ============================================================

START_TIME=$(date +%s)

cleanup() {
    true
}

trap cleanup EXIT


# ============================================================
# HEADER
# ============================================================

echo
echo "============================================================"
echo "                 WEB RECON FRAMEWORK v2"
echo "============================================================"
echo "Target       : $DOMAIN"
echo "Output       : $TARGET_DIR"
echo "Started      : $(date)"
echo "HTTPX        : $HTTPX"
echo "============================================================"
echo


# ============================================================
# DEPENDENCY CHECK
# ============================================================

log "[0/10] Checking dependencies..."


REQUIRED_BINARIES=(
    "$SUBFINDER"
    "$DNSX"
    "$HTTPX"
    "$KATANA"
    "$GAU"
    "$WAYBACKURLS"
    "$GF"
    "$ARJUN"
    "$ASSETFINDER"
)

MISSING=0

for binary in "${REQUIRED_BINARIES[@]}"; do

    if [[ -z "$binary" || ! -x "$binary" ]]; then
        warn "Missing dependency: $binary"
        MISSING=1
    else
        success "Found: $binary"
    fi

done


if [[ ! -f "$LINKFINDER" ]]; then
    warn "LinkFinder not found: $LINKFINDER"
fi


if [[ ! -f "$SECRETFINDER" ]]; then
    warn "SecretFinder not found: $SECRETFINDER"
fi


if [[ "$MISSING" -eq 1 ]]; then
    error "Required dependencies are missing."
    error "Install/fix the missing tools and run again."
    exit 1
fi


# ============================================================
# TOOL VERSIONS
# ============================================================

{
    echo "Tool Versions"
    echo "-------------"

    "$SUBFINDER" -version 2>/dev/null || true
    "$DNSX" -version 2>/dev/null || true
    "$HTTPX" -version 2>/dev/null || true
    "$KATANA" -version 2>/dev/null || true
    "$GAU" --version 2>/dev/null || true
    "$GF" -list 2>/dev/null || true
    "$ARJUN" --version 2>/dev/null || true

} > "$TARGET_DIR/tool-versions.txt" 2>&1 || true


# ============================================================
# 1 — SUBDOMAIN ENUMERATION
# ============================================================

log "[1/10] Subdomain enumeration..."

TMP_SUBS="$TARGET_DIR/.subdomains.tmp"

: > "$TMP_SUBS"


"$SUBFINDER" \
    -d "$DOMAIN" \
    -silent \
    >> "$TMP_SUBS" 2>> "$LOG_FILE" || true


"$ASSETFINDER" \
    --subs-only "$DOMAIN" \
    >> "$TMP_SUBS" 2>> "$LOG_FILE" || true


"$AMASS" \
    enum \
    -passive \
    -d "$DOMAIN" \
    -silent \
    >> "$TMP_SUBS" 2>> "$LOG_FILE" || true


# Certificate Transparency
curl \
    -L \
    -s \
    --max-time 30 \
    -A "Mozilla/5.0" \
    "https://crt.sh/?q=%25.$DOMAIN" \
    | grep -oE "([A-Za-z0-9_-]+\.)+$DOMAIN" \
    >> "$TMP_SUBS" 2>/dev/null || true


# Include root domain
echo "$DOMAIN" >> "$TMP_SUBS"


# Normalize and validate scope
sed 's/^\*\.//' "$TMP_SUBS" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/\.$//' \
    | grep -E "(^|\.)${DOMAIN//./\\.}$" \
    | sort -u \
    > "$SUBDOMAINS"


rm -f "$TMP_SUBS"


success "Subdomains discovered: $(count_lines "$SUBDOMAINS")"


# ============================================================
# 2 — DNS RESOLUTION
# ============================================================

log "[2/10] DNS resolution..."


"$DNSX" \
    -l "$SUBDOMAINS" \
    -a \
    -resp \
    -silent \
    > "$DNS" \
    2>> "$LOG_FILE" || true


success "DNS results: $(count_lines "$DNS")"


# ============================================================
# 3 — HTTP PROBING + FINGERPRINTING
# ============================================================

log "[3/10] HTTP probing and technology fingerprinting..."


"$HTTPX" \
    -l "$SUBDOMAINS" \
    -silent \
    -threads "$HTTPX_THREADS" \
    -timeout "$HTTPX_TIMEOUT" \
    -status-code \
    -title \
    -tech-detect \
    -web-server \
    -follow-redirects \
    -o "$HTTP" \
    2>> "$LOG_FILE" || true


# Plain live URLs
"$HTTPX" \
    -l "$SUBDOMAINS" \
    -silent \
    -threads "$HTTPX_THREADS" \
    -timeout "$HTTPX_TIMEOUT" \
    -follow-redirects \
    -o "$LIVE" \
    2>> "$LOG_FILE" || true


success "HTTP results: $(count_lines "$HTTP")"
success "Live URLs: $(count_lines "$LIVE")"


# ============================================================
# 4 — CONTROLLED CRAWLING
# ============================================================

log "[4/10] Crawling live websites with Katana..."


if [[ -s "$LIVE" ]]; then

    "$KATANA" \
        -list "$LIVE" \
        -silent \
        -depth "$KATANA_DEPTH" \
        -jc \
        -c "$KATANA_CONCURRENCY" \
        -timeout "$KATANA_TIMEOUT" \
        -o "$CRAWL" \
        2>> "$LOG_FILE" || true

else

    : > "$CRAWL"
    warn "No live URLs available for crawling."

fi


sort -u "$CRAWL" -o "$CRAWL"


success "Crawled URLs: $(count_lines "$CRAWL")"


# ============================================================
# 5 — HISTORICAL URL DISCOVERY
# ============================================================

log "[5/10] Collecting historical URLs..."


: > "$HISTORICAL"


# GAU
"$GAU" \
    --subs \
    "$DOMAIN" \
    >> "$HISTORICAL" \
    2>> "$LOG_FILE" || true


# Wayback
"$WAYBACKURLS" \
    "$DOMAIN" \
    >> "$HISTORICAL" \
    2>> "$LOG_FILE" || true


# Keep only URLs belonging to target scope
grep -E "^https?://([^/]+\.)?${DOMAIN//./\\.}(/|$)" \
    "$HISTORICAL" \
    | sort -u \
    > "${HISTORICAL}.tmp" || true


mv "${HISTORICAL}.tmp" "$HISTORICAL"


success "Historical URLs: $(count_lines "$HISTORICAL")"


# ============================================================
# MERGE URL SOURCES
# ============================================================

ALL_URLS="$TARGET_DIR/05-all-urls.txt"


cat \
    "$LIVE" \
    "$CRAWL" \
    "$HISTORICAL" \
    2>/dev/null \
    | grep -E "^https?://" \
    | sort -u \
    > "$ALL_URLS" || true


success "Unique URLs: $(count_lines "$ALL_URLS")"


# ============================================================
# 6 — JAVASCRIPT DISCOVERY
# ============================================================

log "[6/10] Extracting JavaScript URLs..."


grep -Ei '\.js([?#].*)?$' \
    "$ALL_URLS" \
    | sort -u \
    > "$JS" || true


success "JavaScript URLs: $(count_lines "$JS")"


# ============================================================
# 7 — LINKFINDER
# ============================================================

log "[7/10] Running LinkFinder..."


: > "$LINKFINDER_OUT"


if [[ -f "$LINKFINDER" && -s "$JS" ]]; then

    while IFS= read -r url; do

        python3 "$LINKFINDER" \
            -i "$url" \
            -o cli \
            >> "$LINKFINDER_OUT" \
            2>> "$LOG_FILE" || true

    done < "$JS"


    sort -u "$LINKFINDER_OUT" -o "$LINKFINDER_OUT"

else

    warn "LinkFinder skipped."

fi


success "LinkFinder results: $(count_lines "$LINKFINDER_OUT")"


# ============================================================
# 8 — SECRET FINDER
# ============================================================

log "[8/10] Running SecretFinder..."


: > "$SECRETFINDER_OUT"


if [[ -f "$SECRETFINDER" && -s "$JS" ]]; then

    # Limit automated processing to avoid extremely long scans.
    JS_LIMIT="$TARGET_DIR/.secretfinder-input.txt"

    head -n 100 "$JS" > "$JS_LIMIT"


    while IFS= read -r url; do

        python3 "$SECRETFINDER" \
            -i "$url" \
            -o cli \
            >> "$SECRETFINDER_OUT" \
            2>> "$LOG_FILE" || true

    done < "$JS_LIMIT"


    rm -f "$JS_LIMIT"

else

    warn "SecretFinder skipped."

fi


sort -u "$SECRETFINDER_OUT" -o "$SECRETFINDER_OUT"


success "SecretFinder results: $(count_lines "$SECRETFINDER_OUT")"


# ============================================================
# 9 — GF PARAMETER FILTERING
# ============================================================

log "[9/10] Filtering interesting parameters with GF..."


: > "$GF_OUT"


if [[ -s "$ALL_URLS" ]]; then

    # General interesting parameter patterns.
    for pattern in \
        interestingparams \
        redirect \
        ssrf \
        sqli \
        xss \
        lfi \
        rce \
        ssti \
        idor
    do

        if "$GF" -list 2>/dev/null | grep -qx "$pattern"; then

            "$GF" "$pattern" \
                < "$ALL_URLS" \
                >> "$GF_OUT" \
                2>> "$LOG_FILE" || true

        fi

    done


    sort -u "$GF_OUT" -o "$GF_OUT"

fi


success "GF results: $(count_lines "$GF_OUT")"


# ============================================================
# 10 — ARJUN PARAMETER DISCOVERY
# ============================================================

log "[10/10] Parameter discovery with Arjun..."


: > "$ARJUN_OUT"


# Prioritize URLs that already contain parameters or were
# identified by GF.

ARJUN_TARGETS="$TARGET_DIR/.arjun-targets.txt"


cat "$GF_OUT" "$ALL_URLS" \
    | grep -E "^https?://" \
    | sort -u \
    | head -n 30 \
    > "$ARJUN_TARGETS" || true


if [[ -s "$ARJUN_TARGETS" ]]; then

    while IFS= read -r url; do

        echo
        echo "URL: $url" >> "$ARJUN_OUT"

        "$ARJUN" \
            -u "$url" \
            -t "$ARJUN_THREADS" \
            -q \
            --stable \
            >> "$ARJUN_OUT" \
            2>> "$LOG_FILE" || true

    done < "$ARJUN_TARGETS"

fi


rm -f "$ARJUN_TARGETS"


success "Arjun results collected."


# ============================================================
# STATUS SUMMARY
# ============================================================

STATUS_SUMMARY="$TARGET_DIR/status-summary.txt"


{
    echo "HTTP STATUS SUMMARY"
    echo "==================="
    echo

    for code in \
        200 201 204 \
        301 302 307 308 \
        400 401 403 404 405 \
        429 \
        500 502 503
    do

        count=$(grep -c "\[$code\]" "$HTTP" 2>/dev/null || true)

        if [[ "$count" -gt 0 ]]; then
            printf "%-5s : %s hosts\n" "$code" "$count"
        fi

    done

} > "$STATUS_SUMMARY"


# ============================================================
# INTERESTING HOSTS
# ============================================================

INTERESTING="$TARGET_DIR/interesting-hosts.txt"


{
    echo "INTERESTING HOSTS"
    echo "================="
    echo

    echo "[200] Full application candidates"
    grep "\[200\]" "$HTTP" 2>/dev/null || true
    echo

    echo "[301/302] Redirect candidates"
    grep -E "\[(301|302|307|308)\]" "$HTTP" 2>/dev/null || true
    echo

    echo "[401] Authentication candidates"
    grep "\[401\]" "$HTTP" 2>/dev/null || true
    echo

    echo "[403] Authorization candidates"
    grep "\[403\]" "$HTTP" 2>/dev/null || true
    echo

    echo "[404] Not-found candidates"
    grep "\[404\]" "$HTTP" 2>/dev/null || true
    echo

    echo "[500+] Server-error candidates"
    grep -E "\[(500|502|503)\]" "$HTTP" 2>/dev/null || true

} > "$INTERESTING"


# ============================================================
# FINAL REPORT
# ============================================================

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))


{
    echo "============================================================"
    echo "              WEB RECON FRAMEWORK v2"
    echo "============================================================"
    echo
    echo "TARGET"
    echo "------"
    echo "$DOMAIN"
    echo
    echo "STARTED"
    echo "-------"
    date -d "@$START_TIME" 2>/dev/null || true
    echo
    echo "FINISHED"
    echo "--------"
    date
    echo
    echo "DURATION"
    echo "--------"
    echo "${DURATION} seconds"
    echo
    echo "============================================================"
    echo "SUMMARY"
    echo "============================================================"
    echo
    echo "Subdomains discovered : $(count_lines "$SUBDOMAINS")"
    echo "DNS results            : $(count_lines "$DNS")"
    echo "HTTP results           : $(count_lines "$HTTP")"
    echo "Live URLs              : $(count_lines "$LIVE")"
    echo "Crawled URLs           : $(count_lines "$CRAWL")"
    echo "Historical URLs        : $(count_lines "$HISTORICAL")"
    echo "Unique URLs            : $(count_lines "$ALL_URLS")"
    echo "JavaScript URLs        : $(count_lines "$JS")"
    echo "LinkFinder results     : $(count_lines "$LINKFINDER_OUT")"
    echo "SecretFinder results   : $(count_lines "$SECRETFINDER_OUT")"
    echo "GF results             : $(count_lines "$GF_OUT")"
    echo
    echo "============================================================"
    echo "HTTP STATUS SUMMARY"
    echo "============================================================"
    echo
    cat "$STATUS_SUMMARY"
    echo
    echo "============================================================"
    echo "INTERESTING HOSTS"
    echo "============================================================"
    echo
    cat "$INTERESTING"
    echo
    echo "============================================================"
    echo "FILES"
    echo "============================================================"
    echo
    echo "01 Subdomains      : $SUBDOMAINS"
    echo "02 DNS             : $DNS"
    echo "03 HTTP            : $HTTP"
    echo "03 Live URLs       : $LIVE"
    echo "04 Crawl           : $CRAWL"
    echo "05 Historical      : $HISTORICAL"
    echo "05 All URLs        : $ALL_URLS"
    echo "06 JavaScript      : $JS"
    echo "07 LinkFinder      : $LINKFINDER_OUT"
    echo "08 SecretFinder    : $SECRETFINDER_OUT"
    echo "09 GF              : $GF_OUT"
    echo "10 Arjun           : $ARJUN_OUT"
    echo "Status Summary     : $STATUS_SUMMARY"
    echo "Interesting Hosts  : $INTERESTING"
    echo "Tool Versions      : $TARGET_DIR/tool-versions.txt"
    echo "Log                : $LOG_FILE"
    echo
    echo "============================================================"
    echo "NEXT MANUAL PHASE"
    echo "============================================================"
    echo
    echo "Use Burp Suite for manual validation of interesting targets."
    echo
    echo "Priority:"
    echo "1. 200 — application functionality"
    echo "2. 301/302 — redirects"
    echo "3. 401 — authentication"
    echo "4. 403 — authorization/access control"
    echo "5. 404 — endpoint discovery"
    echo "6. 500/502/503 — server-side behavior"
    echo
    echo "Then investigate:"
    echo "- Authentication"
    echo "- Authorization"
    echo "- APIs"
    echo "- Business logic"
    echo "- Input validation"
    echo "- Security impact"
    echo
    echo "============================================================"
    echo "END OF REPORT"
    echo "============================================================"

} > "$REPORT"


# ============================================================
# CLEAN TEMPORARY FILES
# ============================================================

rm -f "$TARGET_DIR"/*.tmp
rm -f "$TARGET_DIR"/.subdomains.tmp


# ============================================================
# FINAL MESSAGE
# ============================================================

echo
echo "============================================================"
echo -e "${GREEN}[+] RECONNAISSANCE COMPLETED${NC}"
echo "============================================================"
echo
echo "Target        : $DOMAIN"
echo "Output        : $TARGET_DIR"
echo "Report        : $REPORT"
echo "Log           : $LOG_FILE"
echo
echo "Subdomains    : $(count_lines "$SUBDOMAINS")"
echo "DNS results   : $(count_lines "$DNS")"
echo "Live URLs     : $(count_lines "$LIVE")"
echo "Crawled URLs  : $(count_lines "$CRAWL")"
echo "Historical    : $(count_lines "$HISTORICAL")"
echo "JavaScript    : $(count_lines "$JS")"
echo
echo "============================================================"
echo
