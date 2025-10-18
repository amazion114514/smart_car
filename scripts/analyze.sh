#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
OUT_DIR="$ROOT_DIR/docs/metrics"
mkdir -p "$OUT_DIR"

# 1) 语言/规模统计
if command -v cloc >/dev/null 2>&1; then
  echo "[info] Running cloc..."
  cloc "$ROOT_DIR/电磁四轮/软件" > "$OUT_DIR/cloc.txt" || true
else
  echo "[warn] cloc not found. Install: sudo apt-get install -y cloc" | tee "$OUT_DIR/cloc.txt"
fi

# 2) C 静态分析（cppcheck）
if command -v cppcheck >/dev/null 2>&1; then
  echo "[info] Running cppcheck..."
  cppcheck \
    --enable=warning,style,performance,portability \
    --inline-suppr \
    --force \
    --language=c \
    --suppress=missingIncludeSystem \
    -I "$ROOT_DIR/电磁四轮/软件/Libraries/libraries" \
    -I "$ROOT_DIR/电磁四轮/软件/Libraries/seekfree_libraries" \
    -I "$ROOT_DIR/电磁四轮/软件/Libraries/seekfree_peripheral" \
    -I "$ROOT_DIR/电磁四轮/软件/Project/MDK" \
    "$ROOT_DIR/电磁四轮/软件" 2> "$OUT_DIR/cppcheck.txt" || true
else
  echo "[warn] cppcheck not found. Install: sudo apt-get install -y cppcheck" | tee "$OUT_DIR/cppcheck.txt"
fi

# 3) clang-tidy（可选）
if command -v clang-tidy >/dev/null 2>&1; then
  echo "[info] Running clang-tidy (best-effort)..."
  find "$ROOT_DIR/电磁四轮/软件/Project/MDK" -maxdepth 1 -name '*.c' \
    -print0 | xargs -0 -I{} bash -lc 'clang-tidy {} -- -I"$ROOT_DIR/电磁四轮/软件/Libraries/libraries" -I"$ROOT_DIR/电磁四轮/软件/Libraries/seekfree_libraries" -I"$ROOT_DIR/电磁四轮/软件/Libraries/seekfree_peripheral" -I"$ROOT_DIR/电磁四轮/软件/Project/MDK"' \
    > "$OUT_DIR/clang-tidy.txt" 2>&1 || true
else
  echo "[warn] clang-tidy not found. Install: sudo apt-get install -y clang-tidy" | tee "$OUT_DIR/clang-tidy.txt"
fi

# 4) semgrep（安全/通用规则）
if command -v semgrep >/dev/null 2>&1; then
  echo "[info] Running semgrep..."
  semgrep --config p/c \
    --error \
    --skip-unknown-extensions \
    --exclude "**/硬件/**" \
    --exclude "**/Out_File/**" \
    "$ROOT_DIR" > "$OUT_DIR/semgrep.txt" 2>&1 || true
else
  echo "[warn] semgrep not found. Install: pipx install semgrep (or pip install semgrep)" | tee "$OUT_DIR/semgrep.txt"
fi

# 5) 简易 secrets 扫描
RG_OUT="$OUT_DIR/secrets.txt"
if command -v rg >/dev/null 2>&1; then
  echo "[info] Running ripgrep-based secrets scan..."
  rg -n --no-heading -S "(AKIA|ASIA|SECRET|TOKEN|PASSWORD|PWD|PRIVATE KEY|-----BEGIN|api_key|access_key|secret_key)" "$ROOT_DIR" > "$RG_OUT" || true
else
  echo "[warn] ripgrep not found. Install: sudo apt-get install -y ripgrep" | tee "$RG_OUT"
fi

echo "[done] Reports saved under $OUT_DIR"
