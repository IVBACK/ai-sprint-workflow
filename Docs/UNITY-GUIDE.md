# Unity Project Notes

Unity projects have binary-heavy assets and non-mergeable files that require extra git
configuration. Set these up at Bootstrap (step 7 or earlier) before the first commit.

These notes apply to **all Unity projects** — solo or team.

---

## Git LFS (mandatory)

Binary assets (textures, models, audio, animations, fonts) bloat the git repo if stored
normally. Configure Git LFS at project setup:
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
Add more patterns as needed — any file type that is binary and > 100KB should be LFS-tracked.

## `.gitignore` (mandatory)

Unity regenerates `Library/`, `Temp/`, `Logs/`, `obj/` per machine. Never track these:
```gitignore
# Unity generated
[Ll]ibrary/
[Tt]emp/
[Oo]bj/
[Bb]uild/
[Bb]uilds/
[Ll]ogs/
[Uu]ser[Ss]ettings/
[Mm]emoryCaptures/

# IDE
.vs/
.idea/
*.csproj
*.sln
*.suo
*.user

# OS
.DS_Store
Thumbs.db
```

## `.meta` files (must track)

Every asset in Unity has a companion `.meta` file containing the asset's GUID and import
settings. These MUST be git-tracked — without them, references between assets break.
Never add `*.meta` to `.gitignore`.

## Scene and Prefab ownership (critical for team)

Unity scene files (`.unity`) and prefabs (`.prefab`) are serialized YAML but practically
**cannot be merged** — git merge produces broken files that Unity cannot load.

Rules for team (Pair / Small Team):
1. **One scene, one owner at a time.** At Roadmap planning, assign scene ownership:
   `- [ ] CORE-045 (@dev-a) Inventory system [scenes: InventoryUI, Shop]`
   `- [ ] CORE-050 (@dev-b) Combat system [scenes: Arena, BossRoom]`
2. **File overlap detection catches scene conflicts.** If overlap detection reveals
   `.unity` or `.prefab` files → **do not proceed**. One person must finish and merge first.
   Scene overlap cannot be resolved with scope boundaries — the whole file must be owned
   by one person.
3. **Shared scenes (e.g., MainMenu both need to touch):** Extract functionality into
   separate prefabs or ScriptableObjects. Each person edits their own prefab, both are
   referenced by the shared scene. Only one person edits the scene file itself.
4. **ScriptableObjects and code files** are text-based and merge normally — no ownership
   restriction needed for `.cs` or `.asset` (text-serialized) files.

Solo developers: scene ownership is implicit (you own everything). The rules above become
relevant if you later add a collaborator.

## Project Settings

`ProjectSettings/` contains shared config (input, quality, physics, tags/layers).
Track it in git. Coordinate edits — two people changing `ProjectSettings/TagManager.asset`
simultaneously will cause merge conflicts. Treat like a shared scene: one person edits
at a time, commit and push immediately.

## Unity-specific sprint-audit.sh patterns

Bootstrap step 7 should uncomment/add these checks:
```bash
EXT="cs"
check "HOT_ALLOC" "new List<\|new Dictionary<\|new HashSet<"
check "UNCACHED" "Camera\.main\|GetComponent<\|FindObjectOfType<\|FindObjectsOfType<"
check "ANTIPATTERN" "AppendStructuredBuffer\|SetFloats\|SendMessage(\|BroadcastMessage("
check "RESOURCE" "new WWW(\|new UnityWebRequest(" # check for using/dispose pattern
```
