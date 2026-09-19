#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Point this clone's git hooks at .github/hooks/ so the local Dogfood Gate runs
# on push. Idempotent; safe to re-run.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git config core.hooksPath .github/hooks
chmod +x .github/hooks/pre-push .github/hooks/validate-a2ml.sh .github/hooks/validate-k9.sh 2>/dev/null || true
echo "Installed: core.hooksPath -> .githooks (pre-push A2ML+K9 gate active)."
