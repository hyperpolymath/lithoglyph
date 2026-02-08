-- SPDX-License-Identifier: AGPL-3.0-or-later
-- FormBD Debugger Core Library

import Lake
open Lake DSL

package «lithoglyph-debugger-core» where
  leanOptions := #[
    ⟨`pp.unicode.fun, true⟩,
    ⟨`autoImplicit, false⟩
  ]

@[default_target]
lean_lib «FormBDDebugger» where
  roots := #[`FormBDDebugger]
