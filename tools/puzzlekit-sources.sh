#!/bin/sh
# Prints the directory holding PuzzleKit's sources, for the bare-swiftc engine
# builds. Uses the revision Xcode pins (Package.resolved) and keeps a checkout
# in .build/PuzzleKit, so nothing has to sit beside this repo.
# PUZZLEKIT=../PuzzleKit overrides it while working on the kit itself.
set -e
cd "$(dirname "$0")/.."
if [ -n "$PUZZLEKIT" ]; then echo "$PUZZLEKIT/Sources/PuzzleKit"; exit 0; fi
resolved=$(ls *.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved)
rev=$(sed -n 's/.*"revision" *: *"\([0-9a-f]*\)".*/\1/p' "$resolved" | head -1)
dir=.build/PuzzleKit
if [ ! -d "$dir/.git" ]; then
  git clone --quiet https://github.com/justpuzzles/PuzzleKit "$dir" >&2
fi
if [ "$(git -C "$dir" rev-parse HEAD)" != "$rev" ]; then
  git -C "$dir" fetch --quiet origin >&2
  git -C "$dir" checkout --quiet "$rev" >&2
fi
echo "$PWD/$dir/Sources/PuzzleKit"
