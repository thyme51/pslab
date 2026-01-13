# Photo organizer spec (Samsung Gallery / OneDrive)

## Context
Photos from a Samsung phone sync into a OneDrive folder:

- Camera source:
  `C:\Users\jorge\OneDrive\Billeder\Samsung Gallery\DCIM\Camera`

This folder grows large and consumes significant disk space on the laptop.

## Objectives
1. **Usability:** Browsing should be simpler by splitting older content into Year/Month folders.
2. **Space:** Keep only the latest **3–6 months** of content in the Camera folder locally.
3. **Safety:** Default to dry-run; changes only when explicitly enabled.
4. **Repeatability:** Script must be idempotent and produce logs for auditing.

## Non-goals (initially)
- No image editing or transcoding.
- No cloud-only automation to run without local review (first versions are manual runs).
- No external modules that require internet access.

## Definitions
- **Camera folder:** The folder that Samsung Gallery writes to (source).
- **Archive:** A folder tree organized as `C:\Users\jorge\OneDrive\Billeder\Albummer\2022`.
- **Cutoff date:** The oldest date that should remain in Camera (based on KeepMonths).
- Note: C:\Users\jorge is just the local drive
- Note: some folder names are localized fx is "C:\Users\jorge\OneDrive\Billeder" the same location as "C:\Users\jorge\OneDrive\Pictures"

## Folder design
- Source:
  `...\Samsung Gallery\DCIM\Camera`
- Archive root:
  `...\Samsung Gallery\Archive`
- Archive layout:
  `...\Albummer\2026\2026-01\...`

## File types in scope
Initial include list (can evolve):
- Images: `.jpg`, `.jpeg`, `.png`, `.heic`, `.gif`
- Video: `.mp4`, `.mov`, `.m4v`

## Date selection (photo date)
Priority order:
1. **EXIF / media metadata date** (when available)
2. **Filesystem fallback** (LastWriteTime or CreationTime — decide and document)

Decision for v1.0:
- Use EXIF DateTimeOriginal when available (primarily JPEG).
- Otherwise fallback to `LastWriteTime`.

## Phased plan
### Phase 1 — Scan + plan (no changes)
Deliverable:
- Script scans SourceCameraPath recursively.
- Produces:
  - `plan-<timestamp>.csv` listing each file, chosen date, target folder, and planned action.
  - `summary-<timestamp>.csv` grouping counts by YearMonth and by action.
- Must be safe to run on the real folder (still no changes).

Acceptance criteria:
- Running against a test folder produces correct grouping by YearMonth.
- Output is stable and readable; no exceptions on common files.

### Phase 2 — Archive (copy/move) gated by -Apply
Deliverable:
- For files older than cutoff:
  - copy by default, move when `-Move` is set.
- Create target folders as needed.
- Collision strategy:
  - If same name exists:
    - if identical (later phase: hash), skip
    - otherwise create a deterministic new name (e.g., `name (1).ext` or timestamp suffix)

Acceptance criteria:
- Dry-run still produces the plan only.
- With `-Apply`, older files end up in the correct `YYYY\YYYY-MM` folder.

### Phase 3 — Duplicate detection
Deliverable:
- Add SHA256 hashing to detect identical content.
- If destination exists and hash matches, skip as duplicate.
- If hash differs, rename new file deterministically.

Acceptance criteria:
- Re-run on same input does not create additional copies.
- Duplicate behavior is consistent and logged.

### Phase 4 — OneDrive disk usage policy (keep recent local)
Deliverable (optional switches):
- `-DehydrateArchive`: set older archive folders to **online-only** (free disk).
- `-PinRecent`: ensure last KeepMonths are **always available**.

Notes:
- Implement using filesystem attributes where possible (OneDrive Files On-Demand).

Acceptance criteria:
- Running the command changes pin state as expected on OneDrive content.
- Does not affect non-OneDrive paths.

    ## Logging requirements
    - Every run creates a plan CSV and a summary CSV in `.\logs\`.
    - CSV columns should include at least:
  - SourcePath, PhotoDate, YearMonth, CutoffDate, PlannedAction, TargetPath, Result, Notes
- Script prints a short console summary.

## Operational notes
- Initial execution is manual from VS Code terminal.
- Later enhancement: scheduled task / automation (out of scope for v1.0).

## Backlog / ideas
- Support “Events” folders (manual override rules)
- Better metadata extraction for HEIC and videos
- Config file (`.json`) for paths and settings
- Unit tests (Pester) for date parsing and path logic
