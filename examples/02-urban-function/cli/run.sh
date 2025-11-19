#!/bin/bash
# Urban Function Example - CLI
#
# This script demonstrates:
# - Building LXR packages from complex schemas
# - Handling schema location mappings via CLI
# - Searching large schema sets
# - Type resolution in complex schemas
#
# Usage:
#   bash examples/02-urban-function/cli/run.sh

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_PATH="$EXAMPLE_DIR/config.yml"
OUTPUT_PATH="$EXAMPLE_DIR/urban_function.lxr"

echo "================================================================================"
echo "02-URBAN-FUNCTION: CLI Example"
echo "================================================================================"
echo

# Step 1: Build LXR Package
# -------------------------
echo "Step 1: Building LXR package from i-UR urban function schema"
echo "--------------------------------------------------------------------------------"
echo "Config: $CONFIG_PATH"
echo "Output: $OUTPUT_PATH"
echo "(This may take a moment due to schema complexity...)"
echo

bundle exec exe/lutaml-xsd build from-config "$CONFIG_PATH" \
  --output "$OUTPUT_PATH" \
  --xsd-mode include_all \
  --resolution-mode resolved \
  --serialization-format marshal \
  --name "i-UR Urban Function Schemas" \
  --version "3.2.0" \
  --description "Japanese international Urban Revitalization standard schemas"

echo
echo "✓ Package created successfully"
echo

# Step 2: Inspect Package
# -----------------------
echo "Step 2: Inspecting package contents"
echo "--------------------------------------------------------------------------------"
echo

bundle exec exe/lutaml-xsd pkg stats "$OUTPUT_PATH"

echo

# Step 3: Search for Urban Planning Types
# ----------------------------------------
echo "Step 3: Searching for GML types"
echo "--------------------------------------------------------------------------------"
echo

echo "Searching for 'gml':"
bundle exec exe/lutaml-xsd pkg search gml "$OUTPUT_PATH" --limit 5

echo
echo "Searching for 'Coverage':"
bundle exec exe/lutaml-xsd pkg search Coverage "$OUTPUT_PATH" --limit 5

echo
echo "Searching for 'Geometry':"
bundle exec exe/lutaml-xsd pkg search Geometry "$OUTPUT_PATH" --limit 5

echo

# Step 4: Resolve Urban Function Types
# -------------------------------------
echo "Step 4: Resolving GML types"
echo "--------------------------------------------------------------------------------"
echo

echo "Resolving 'gml:AbstractGMLType':"
bundle exec exe/lutaml-xsd pkg type find gml:AbstractGMLType "$OUTPUT_PATH"

echo
echo "Resolving 'gml:PointType':"
bundle exec exe/lutaml-xsd pkg type find gml:PointType "$OUTPUT_PATH"

echo
echo "Resolving 'gml:FeaturePropertyType':"
bundle exec exe/lutaml-xsd pkg type find gml:FeaturePropertyType "$OUTPUT_PATH"

echo

# Step 5: List Namespaces
# ------------------------
echo "Step 5: Listing namespaces"
echo "--------------------------------------------------------------------------------"
echo

bundle exec exe/lutaml-xsd pkg namespace list "$OUTPUT_PATH"

echo

# Step 6: View Package Tree
# --------------------------
echo "Step 6: Viewing package structure (first 20 lines)"
echo "--------------------------------------------------------------------------------"
echo

bundle exec exe/lutaml-xsd pkg tree "$OUTPUT_PATH" | head -20
echo "... (truncated)"

echo

# Summary
echo "================================================================================"
echo "Example completed successfully!"
echo
echo "Key concepts demonstrated:"
echo "  ✓ Building packages from complex schemas with imports"
echo "  ✓ Schema location mapping via configuration"
echo "  ✓ Handling large schema sets (100+ types)"
echo "  ✓ Namespace-aware searching"
echo "  ✓ Package tree inspection"
echo
echo "Output files:"
echo "  - $OUTPUT_PATH"
echo "================================================================================"