#!/usr/bin/env bash

# Default test URL (provided by the user)
URL="${1:-https://theprint.in/tech/ai-wont-revive-rapid-productivity-growth-nobel-economist-christopher-pissarides-warns/2979698/}"
IMPL_NAME="${2:-Baseline (Flat Text)}"
LOG_FILE="benchmark_log.md"
RAW_FILE="raw_test.html"
CLEAN_FILE="clean_test.txt"

echo "=== HTML Content Extraction Benchmark ==="
echo "Target URL: $URL"
echo "Implementation: $IMPL_NAME"
echo ""

# Ensure release binary is compiled to avoid including compile time in output
cargo build --release --quiet

# 1. Fetch raw HTML via the Rust parser's headless browser / network engine
echo "Downloading raw HTML using Rust --test-raw..."
cargo run --quiet --release -- --test-raw "$URL" 2>/dev/null > "$RAW_FILE"

if [ ! -s "$RAW_FILE" ]; then
    echo "Error: Failed to fetch raw HTML (file is empty)."
    exit 1
fi

# Measure raw metrics
RAW_BYTES=$(wc -c < "$RAW_FILE" | xargs)
RAW_WORDS=$(wc -w < "$RAW_FILE" | xargs)
RAW_CHARS=$(wc -m < "$RAW_FILE" | xargs)

# 2. Run Rust binary for cleaning
echo "Extracting cleaned content using Rust --test-url..."
cargo run --quiet --release -- --test-url "$URL" 2>/dev/null > "$CLEAN_FILE"

if [ ! -s "$CLEAN_FILE" ]; then
    echo "Error: Rust output is empty."
    rm -f "$RAW_FILE" "$CLEAN_FILE"
    exit 1
fi

# Strip the metadata trailer line ([Content info: ...]) to avoid counting it
grep -v "^---$" "$CLEAN_FILE" | grep -v "^\[Content info:" > "${CLEAN_FILE}.tmp"
mv "${CLEAN_FILE}.tmp" "$CLEAN_FILE"

CLEAN_BYTES=$(wc -c < "$CLEAN_FILE" | xargs)
CLEAN_WORDS=$(wc -w < "$CLEAN_FILE" | xargs)
CLEAN_CHARS=$(wc -m < "$CLEAN_FILE" | xargs)

# 3. Calculations
if [ $RAW_BYTES -gt 0 ]; then
    # Size and word reductions
    RED_BYTES_PCT=$(awk "BEGIN {print (($RAW_BYTES - $CLEAN_BYTES) / $RAW_BYTES) * 100}")
    RED_WORDS_PCT=$(awk "BEGIN {print (($RAW_WORDS - $CLEAN_WORDS) / $RAW_WORDS) * 100}")
    DENSITY_PCT=$(awk "BEGIN {print ($CLEAN_CHARS / $RAW_CHARS) * 100}")
else
    RED_BYTES_PCT=0
    RED_WORDS_PCT=0
    DENSITY_PCT=0
fi

# Estimated tokens (words * 1.33)
RAW_TOKENS=$(awk "BEGIN {print int($RAW_WORDS * 1.33)}")
CLEAN_TOKENS=$(awk "BEGIN {print int($CLEAN_WORDS * 1.33)}")
SAVED_TOKENS=$((RAW_TOKENS - CLEAN_TOKENS))
if [ $RAW_TOKENS -gt 0 ]; then
    SAVED_TOKENS_PCT=$(awk "BEGIN {print ($SAVED_TOKENS / $RAW_TOKENS) * 100}")
else
    SAVED_TOKENS_PCT=0
fi

# Format values for display (2 decimal places)
RED_BYTES_PCT_FMT=$(printf "%.2f" "$RED_BYTES_PCT")
RED_WORDS_PCT_FMT=$(printf "%.2f" "$RED_WORDS_PCT")
DENSITY_PCT_FMT=$(printf "%.2f" "$DENSITY_PCT")
SAVED_TOKENS_PCT_FMT=$(printf "%.2f" "$SAVED_TOKENS_PCT")

# Convert sizes to KB for display
RAW_KB=$(awk "BEGIN {printf \"%.2f\", $RAW_BYTES/1024}")
CLEAN_KB=$(awk "BEGIN {printf \"%.2f\", $CLEAN_BYTES/1024}")

# Print report to stdout
echo ""
echo "--- Results ---"
printf "%-25s : %s KB (%s words, ~%s tokens)\n" "Raw HTML" "$RAW_KB" "$RAW_WORDS" "$RAW_TOKENS"
printf "%-25s : %s KB (%s words, ~%s tokens)\n" "Cleaned Output" "$CLEAN_KB" "$CLEAN_WORDS" "$CLEAN_TOKENS"
printf "%-25s : %s%%\n" "Size Reduction" "$RED_BYTES_PCT_FMT"
printf "%-25s : %s%%\n" "Word Count Reduction" "$RED_WORDS_PCT_FMT"
printf "%-25s : %s (~%s%% saved)\n" "Est. Token Savings" "$SAVED_TOKENS" "$SAVED_TOKENS_PCT_FMT"
printf "%-25s : %s%%\n" "Text Density Index" "$DENSITY_PCT_FMT"
echo "----------------"

# 4. Log to benchmark_log.md
DATE=$(date "+%Y-%m-%d %H:%M:%S")

if [ ! -f "$LOG_FILE" ]; then
    echo "# HTML Content Extraction & Noise Reduction Journey Log" > "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    echo "This file documents our progress in refining HTML extraction, boilerplate stripping, and formatting." >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    echo "| Date & Time | Version / Milestone | Target URL | Raw Size (KB) | Clean Size (KB) | Size Red. % | Words (Raw / Clean) | Est. Token Savings | Text Density |" >> "$LOG_FILE"
    echo "| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |" >> "$LOG_FILE"
fi

echo "| $DATE | $IMPL_NAME | $URL | $RAW_KB | $CLEAN_KB | ${RED_BYTES_PCT_FMT}% | $RAW_WORDS / $CLEAN_WORDS | $SAVED_TOKENS (${SAVED_TOKENS_PCT_FMT}%) | ${DENSITY_PCT_FMT}% |" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

echo "Results appended to $LOG_FILE"

# Clean up temp files
rm -f "$RAW_FILE" "$CLEAN_FILE"
