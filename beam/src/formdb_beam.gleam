// SPDX-License-Identifier: AGPL-3.0-or-later
// FormDB BEAM - Main module

/// Re-export client API
pub fn version() -> #(Int, Int, Int) {
  formdb_beam/client.version()
}
