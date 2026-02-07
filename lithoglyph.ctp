# Cerro Torre Package Manifest for Lithoglyph
# Immutable Content-Addressable Block Storage for Pimcore Fortress

ctp_version = "1.0"

[metadata]
name = "lithoglyph"
version = "0.1.0"
revision = 1
kind = "container_image"
summary = "Immutable block storage with content addressing"
description = """
Lithoglyph provides append-only, immutable block storage with 4 KiB blocks,
CRC32C checksums, and SHA-256 content addressing. Designed for Pimcore Fortress
to provide cryptographic proof of asset immutability for journalists.
"""
license = "PMPL-1.0-or-later"
homepage = "https://github.com/hyperpolymath/lithoglyph"
maintainer = "Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>"

[upstream]
family = "alpine"
suite = "3.21"
registry = "docker.io/library/alpine"

[provenance]
import_date = 2026-02-07T00:00:00Z
source_repo = "https://github.com/hyperpolymath/lithoglyph"
source_commit = "HEAD"

# ============================================================================
# SECURITY — Crypto suite commitment
# ============================================================================

[security]
suite_id = "CT-SIG-01"
payload_binding = "manifest.canonical_bytes_sha256"

[security.algorithms]
[security.algorithms.hash]
id = "sha256"
output_bits = 256

[[security.algorithms.signatures]]
id = "ed25519"
required = true

# ============================================================================
# INPUTS — Binary sources
# ============================================================================

[[inputs.sources]]
id = "lithoglyph_binary"
type = "local_binary"
name = "demo-server"
path = "/mnt/eclipse/repos/lithoglyph/demo-server"

[[inputs.sources]]
id = "libbridge"
type = "local_library"
name = "libbridge.so"
path = "/mnt/eclipse/repos/lithoglyph/zig-out/lib/libbridge.so"

[[inputs.sources]]
id = "alpine_base"
type = "oci_image"
image = "docker.io/library/alpine:3.21"
# SHA256 would be fetched dynamically

# ============================================================================
# BUILD — Simple binary packaging
# ============================================================================

[build]
system = "cerro_image"

[build.environment]
arch = "amd64"
os = "linux"
reproducible = true

[[build.plan]]
step = "import_base"
using = "oci"
source = "alpine_base"

[[build.plan]]
step = "copy_binary"
source = "lithoglyph_binary"
dest = "/usr/local/bin/demo-server"
mode = "0755"

[[build.plan]]
step = "copy_library"
source = "libbridge"
dest = "/usr/local/lib/libbridge.so"
mode = "0755"

[[build.plan]]
step = "add_user"
username = "lithoglyph"
uid = 1000
home = "/data"

[[build.plan]]
step = "emit_oci_image"

[build.plan.image]
entrypoint = ["/usr/local/bin/demo-server"]
cmd = []
user = "lithoglyph"
workingdir = "/data"
expose = [8080]

[build.plan.image.env]
LITHOGLYPH_PORT = "8080"
LITHOGLYPH_HOST = "0.0.0.0"

[build.plan.image.labels]
"org.opencontainers.image.title" = "lithoglyph"
"org.opencontainers.image.source" = "https://github.com/hyperpolymath/lithoglyph"
"org.opencontainers.image.description" = "Immutable block storage for Pimcore Fortress"
"org.opencontainers.image.authors" = "Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>"
"org.opencontainers.image.licenses" = "PMPL-1.0-or-later"

# ============================================================================
# OUTPUTS — Artifacts produced
# ============================================================================

[outputs]
primary = "lithoglyph"

[[outputs.artifacts]]
type = "oci_image"
name = "lithoglyph"
tag = "0.1.0"

[[outputs.artifacts]]
type = "sbom_spdx_json"
name = "lithoglyph.sbom.spdx.json"

[[outputs.artifacts]]
type = "in_toto_provenance"
name = "lithoglyph.provenance.jsonl"

# ============================================================================
# POLICY — Attestation requirements
# ============================================================================

[policy.provenance]
require_source_hashes = true
require_reproducible_build = false  # Binaries already built

[policy.attestations]
emit = ["in_toto", "sbom_spdx_json"]

# ============================================================================
# ATTESTATIONS — Requirements
# ============================================================================

[attestations]
require = ["binary-integrity"]
recommend = ["sbom-complete", "slsa-level-2"]
