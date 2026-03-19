<instructions>

# CRITICAL: Never add *.meta to .gitignore. Meta files MUST be tracked.
# CRITICAL: Scene/prefab files (.unity, .prefab) cannot merge. One owner at a time.

# Unity Project Notes

Set up at Bootstrap (step 7 or earlier) before first commit. Applies to all Unity projects.

## Git LFS (mandatory)

```bash
git lfs install
git lfs track "*.png" "*.jpg" "*.tga" "*.psd" "*.tif"
git lfs track "*.fbx" "*.obj" "*.blend" "*.max" "*.ma"
git lfs track "*.wav" "*.mp3" "*.ogg" "*.aif"
git lfs track "*.anim" "*.controller" "*.overrideController"
git lfs track "*.ttf" "*.otf"
git lfs track "*.asset" "*.cubemap" "*.lighting"
git commit .gitattributes -m "chore: configure Git LFS for Unity binary assets"
```

Rule: any binary file > 100KB should be LFS-tracked.

## .gitignore (mandatory)

```gitignore
[Ll]ibrary/
[Tt]emp/
[Oo]bj/
[Bb]uild/
[Bb]uilds/
[Ll]ogs/
[Uu]ser[Ss]ettings/
[Mm]emoryCaptures/
.vs/
.idea/
*.csproj
*.sln
*.suo
*.user
.DS_Store
Thumbs.db
```

## .meta Files

Every asset has a .meta file (GUID + import settings). MUST be tracked. Never add `*.meta` to .gitignore.

## Scene & Prefab Ownership

.unity and .prefab files are YAML but practically unmergeable.

Rules (team):
1. One scene, one owner. Assign at Roadmap: `- [ ] CORE-045 (@dev-a) [scenes: InventoryUI, Shop]`
2. IF file overlap detection finds .unity or .prefab: STOP. One person finishes and merges first.
3. Shared scenes: extract into separate prefabs/ScriptableObjects. One person edits scene file.
4. .cs and text-serialized .asset files merge normally. No ownership restriction.

Solo: implicit ownership. Rules apply when adding collaborators.

## Project Settings

`ProjectSettings/` = shared config. Track in git. One person edits at a time, commit + push immediately.

## sprint-audit.sh Patterns

Add at Bootstrap step 7:
```bash
EXT="cs"
check "HOT_ALLOC" "new List<\|new Dictionary<\|new HashSet<"
check "UNCACHED" "Camera\.main\|GetComponent<\|FindObjectOfType<\|FindObjectsOfType<"
check "ANTIPATTERN" "AppendStructuredBuffer\|SetFloats\|SendMessage(\|BroadcastMessage("
check "RESOURCE" "new WWW(\|new UnityWebRequest("
```

# CRITICAL: Never add *.meta to .gitignore. Scene/prefab = one owner at a time.

</instructions>
