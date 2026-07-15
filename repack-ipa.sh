#!/usr/bin/env bash
#
# repack-ipa.sh — fetch the latest CI-built .ipa, merge it over an asset directory,
# repack it into a new .ipa, sign it with your Apple ID (plumesign sign), then install
# it to the device (plumesign device --install) as a separate step.
#
# The CI build produces an .ipa that has the freshly-built binary but NOT the game
# assets (they aren't in the repo). This script overlays that build onto a directory
# that DOES have the assets (its Payload/…/*.app), overwriting the binary + built
# resources while keeping every asset, repacks it into an .ipa, then signs it.
#
# Usage:
#   ./repack-ipa.sh <merge-dir> [output.ipa]
#
#   <merge-dir>  Directory that contains the game assets laid out as an IPA root
#                (i.e. it contains a "Payload/<App>.app/…"). The freshly-built app
#                is copied in over the top; files already there are overwritten,
#                assets not in the build are kept. THIS DIRECTORY IS MODIFIED.
#   [output.ipa] Output path for the final (signed) IPA. Default: ./PopnRhythmin-signed.ipa
#
# Environment overrides:
#   REPO            GitHub repo (default: Tatsh/expert-rotary-phone)
#   ARTIFACT        Artifact name (default: PopnRhythmin-adhoc-ipa)
#   WORKFLOW        Workflow file that builds the .ipa (default: build.yml)
#   RUN_ID          Specific run id to pull (default: latest successful build run)
#   PLUMESIGN       Path to the plumesign binary (default: found on PATH / ./plumesign-linux-x86_64)
#   PLUMESIGN_ARGS  Extra args appended to `plumesign sign`
#   UDID            Device UDID for --register-and-install (default: the configured device)
#   NO_INSTALL=1    Sign only; do not register + install to the device.
#   SKIP_SIGN=1     Skip signing entirely; emit the unsigned repacked .ipa instead.
#
set -euo pipefail

REPO="${REPO:-Tatsh/expert-rotary-phone}"
ARTIFACT="${ARTIFACT:-PopnRhythmin-adhoc-ipa}"
# Only the build workflow produces the .ipa artifact; every other workflow
# (Prettier, Spelling, markdownlint, …) also has successful runs, so the run must
# be scoped to this workflow or `gh run download` may pick an unrelated run.
WORKFLOW="${WORKFLOW:-build.yml}"
UDID="${UDID:-1}"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ $# -ge 1 ] || die "usage: $0 <merge-dir> [output.ipa]"
MERGE_DIR="$1"
OUT_IPA="${2:-$PWD/PopnRhythmin-signed.ipa}"

[ -d "$MERGE_DIR" ] || die "merge dir does not exist: $MERGE_DIR"
command -v gh    >/dev/null || die "gh not found"
command -v unzip >/dev/null || die "unzip not found"
command -v zip   >/dev/null || die "zip not found"

# Resolve the signer up front so we fail fast before downloading anything.
if [ "${SKIP_SIGN:-0}" != "1" ]; then
    PLUMESIGN="${PLUMESIGN:-}"
    if [ -z "$PLUMESIGN" ]; then
        if   command -v plumesign-linux-x86_64 >/dev/null; then PLUMESIGN="plumesign-linux-x86_64"
        elif [ -x "$PWD/plumesign-linux-x86_64" ];         then PLUMESIGN="$PWD/plumesign-linux-x86_64"
        else die "plumesign-linux-x86_64 not found (set PLUMESIGN=/path/to/it, or SKIP_SIGN=1)"; fi
    fi
fi

# Resolve to absolute paths (we cd around later).
MERGE_DIR="$(cd "$MERGE_DIR" && pwd)"
case "$OUT_IPA" in /*) : ;; *) OUT_IPA="$PWD/$OUT_IPA" ;; esac

# Scratch space, always cleaned up.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 1) Pick the run.
RUN_ID="${RUN_ID:-}"
if [ -z "$RUN_ID" ]; then
    RUN_ID="$(gh run list -R "$REPO" --workflow "$WORKFLOW" --status success --limit 1 --json databaseId -q '.[0].databaseId')"
    [ -n "$RUN_ID" ] || die "no successful $WORKFLOW runs found for $REPO"
fi
echo ">> run $RUN_ID  ($REPO)  artifact: $ARTIFACT"

# 2) Download + extract the artifact (gh unzips the artifact zip into DL/).
DL="$WORK/dl"
mkdir -p "$DL"
gh run download "$RUN_ID" -R "$REPO" -n "$ARTIFACT" -D "$DL"

# 3) Locate the .ipa (handle either a bare .ipa or a nested .zip containing one).
IPA="$(find "$DL" -type f -iname '*.ipa' | head -1 || true)"
if [ -z "$IPA" ]; then
    NESTED_ZIP="$(find "$DL" -type f -iname '*.zip' | head -1 || true)"
    [ -n "$NESTED_ZIP" ] || die "no .ipa or .zip found in the artifact"
    unzip -q -o "$NESTED_ZIP" -d "$DL/nested"
    IPA="$(find "$DL/nested" -type f -iname '*.ipa' | head -1 || true)"
fi
[ -n "$IPA" ] || die "no .ipa found after extracting the artifact"
echo ">> ipa: $(basename "$IPA")"

# 4) Unpack the .ipa (it is a zip: Payload/<App>.app/…).
EXTRACT="$WORK/ipa"
mkdir -p "$EXTRACT"
unzip -q -o "$IPA" -d "$EXTRACT"

# 5) Copy the ipa's contents into the merge dir, overwriting existing files
#    (assets already in the merge dir that the build lacks are preserved).
echo ">> merging fresh build into: $MERGE_DIR"
cp -Rf "$EXTRACT"/. "$MERGE_DIR"/

# 6) Zip the merge dir into an (unsigned) .ipa (Payload/ at the archive root).
UNSIGNED="$WORK/unsigned.ipa"
if [ -d "$MERGE_DIR/Payload" ]; then
    ( cd "$MERGE_DIR" && zip -q -r -X "$UNSIGNED" Payload )
else
    ( cd "$MERGE_DIR" && zip -q -r -X "$UNSIGNED" . )
fi

# 7) Sign with the Apple ID (plumesign sign), producing the final .ipa.
rm -f "$OUT_IPA"
if [ "${SKIP_SIGN:-0}" = "1" ]; then
    cp -f "$UNSIGNED" "$OUT_IPA"
    echo ">> wrote (UNSIGNED, SKIP_SIGN=1): $OUT_IPA"
else
    echo ">> signing with Apple ID via $(basename "$PLUMESIGN") sign…"
    # shellcheck disable=SC2086
    "$PLUMESIGN" sign --package "$UNSIGNED" --apple-id -o "$OUT_IPA" ${PLUMESIGN_ARGS:-}
    echo ">> wrote (signed): $OUT_IPA"
fi

# 8) Install the signed .ipa to the device — a separate step (plumesign device).
#    Skipped when unsigned (SKIP_SIGN=1) or when NO_INSTALL=1.
if [ "${SKIP_SIGN:-0}" = "1" ] || [ "${NO_INSTALL:-0}" = "1" ]; then
    echo ">> skipping install"
else
    echo ">> installing to device $UDID via $(basename "$PLUMESIGN") device…"
    "$PLUMESIGN" device --udid "$UDID" --install "$OUT_IPA"
    echo ">> installed"
fi
