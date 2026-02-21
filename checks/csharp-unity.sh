#!/usr/bin/env bash
# checks/csharp-unity.sh — C#/Unity audit checks
#
# Source this file from sprint-audit.sh when EXT=cs or detected language is C#/Unity.
# Requires: common.sh sourced first, SRC_DIR and EXT set.

echo ""
echo "── C#/Unity Checks ──"

# Hot path allocations
check "HOT_ALLOC" "new List<\|new Dictionary<\|new NativeArray"

# Cached reference violations
check "UNCACHED" "Camera\\.main\|GetComponent<\|FindObjectOfType"

# Framework anti-patterns
check "ANTIPATTERN" "AppendStructuredBuffer\|SetFloats\|ComputeBufferType\\.Append"

# Resource guard — NativeArray/ComputeBuffer without Dispose/Release
check "RESOURCE" "new NativeArray\|new ComputeBuffer\|new FileStream\|new SqlConnection\|new StreamReader"

# String allocations in hot paths
check "STRING_ALLOC" '\$".*{'

# Unity-specific: missing ProfilerMarker on Dispatch/Upload
check "OBSERVABILITY" "Dispatch\|Upload\|Evaluate"
