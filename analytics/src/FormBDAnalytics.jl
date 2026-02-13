# SPDX-License-Identifier: PMPL-1.0-or-later
"""
FormBD-Analytics: OLAP analytics layer for FormBD

Provides columnar storage and analytical queries over FormBD documents.
"""
module FormBDAnalytics

using Arrow
using CSV
using Dates
using DataFrames
using HTTP
using JSON3
using Oxygen
using Parquet2
using Tables
using TOML
using UUIDs

export Config, load_config
export FormBDClient, Document, fetch_collection, fetch_document, extract_prompt_scores, extract_timestamp, health_check
export ColumnarStore, sync!, load!, query, stats, prompt_stats, prompt_distribution, time_series, contributors
export serve

include("config.jl")
include("formbd_client.jl")
include("columnar_store.jl")
include("analytics.jl")
include("api.jl")

end # module
