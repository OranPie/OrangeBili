#!/usr/bin/env bash
set -euo pipefail

# Probe watchOS video-render related API availability by type-checking tiny snippets.
# No network, no cloud stream, no audio playback required.

TARGET="${1:-arm64_32-apple-watchos10.0}"
SDK_PATH="$(xcrun --sdk watchos --show-sdk-path)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PROBE_SWIFT="$TMP_DIR/probe.swift"
OUT_TXT="$TMP_DIR/probe.out"

cat > "$PROBE_SWIFT" <<'EOF'
import AVFoundation
import SpriteKit

func probeUnavailable(player: AVPlayer, asset: AVAsset, item: AVPlayerItem) {
    // Candidate frame extraction / rendering APIs people usually try.
    _ = AVPlayerItemVideoOutput(pixelBufferAttributes: nil)
    _ = AVAssetImageGenerator(asset: asset)
    _ = try? AVAssetReader(asset: asset)
    _ = AVSampleBufferDisplayLayer()
    _ = AVPlayerLayer(player: player)
}

func probeSpriteKit(player: AVPlayer) {
    // SpriteKit path used by custom UI overlays.
    let node = SKVideoNode(avPlayer: player)
    _ = node
}
EOF

echo "== watchOS video capability probe =="
echo "Target : $TARGET"
echo "SDK    : $SDK_PATH"
echo

set +e
xcrun swiftc -target "$TARGET" -sdk "$SDK_PATH" -typecheck "$PROBE_SWIFT" >"$OUT_TXT" 2>&1
STATUS=$?
set -e

if [[ $STATUS -eq 0 ]]; then
  echo "Type-check passed unexpectedly. All probed APIs appear available."
  exit 0
fi

echo "Type-check failed as expected; extracting key diagnostics..."
echo

grep -E "error: .*unavailable in watchOS|note: '.*' has been explicitly marked unavailable here|no such module" "$OUT_TXT" || true
echo

echo "Full compiler output:"
cat "$OUT_TXT"

