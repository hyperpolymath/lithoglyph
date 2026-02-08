#!/usr/bin/env julia
# SPDX-License-Identifier: AGPL-3.0-or-later
"""
FormBD-Analytics entry point
"""

using Pkg
Pkg.activate(@__DIR__ |> dirname)

using FormBDAnalytics

function main()
    # Parse arguments
    config_path = "config.toml"

    for (i, arg) in enumerate(ARGS)
        if arg == "--config" && i < length(ARGS)
            config_path = ARGS[i + 1]
        elseif arg == "--help"
            println("""
FormBD-Analytics - OLAP analytics layer for FormBD

Usage:
    julia src/main.jl [options]

Options:
    --config PATH    Path to config file (default: config.toml)
    --help           Show this help message
            """)
            return
        end
    end

    # Load configuration
    config = load_config(config_path)

    # Start server
    serve(config)
end

main()
