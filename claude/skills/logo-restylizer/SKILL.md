---
name: logo-restylizer
category: UI & Design
description: Restylize, retheme, or transform an existing logo or icon into a new visual variant. Use this skill whenever the user wants to: create a variation of an existing logo, change logo colors or style, apply a new theme or effect to an icon, make a dark/light/neon/flat/outlined version, apply new branding to an existing mark, generate a restyled copy of any SVG or image file, or modify a logo's visual treatment. Triggers on phrases like "restyle logo", "transform icon", "make a dark version", "change the colors on", "apply X style to", "create a variant of", or any request that combines an existing image with a desired visual outcome. Always invoke before attempting to modify an image file manually.
---

# Logo Restylizer

Creates styled variants of existing logos and icons, previews the result with the user, iterates on feedback, and optionally propagates the accepted design across all logo usages in the codebase.

---

## Step 1 — Extract Intent from the Prompt

Read the user's message carefully and extract:

| Signal | What to look for |
|--------|-----------------|
| **Source image** | An explicit file path, a file name, a description like "the branding logo", or a reference to a recently-discussed file |
| **Transformation intent** | Color palette change, style shift (neon → flat, outlined → filled), theme (dark mode, amber, pastel), effect (glow, shadow, monochrome), or any described visual outcome |

**Both signals are required.** If either is clearly absent and cannot be inferred from recent context, use the `AskUserQuestion` tool to ask — never ask inline as plain text. Ask only once, combining all missing questions into a single call.

If the source image path cannot be determined at all (no path, no name, no recent context), respond with a brief explanation of what information is needed and end the turn — do not proceed.

> **Re-entry point for revision loop:** When returning to this step after user feedback, the "source image" is now the current working file (the restylized copy being refined), and the "transformation intent" is the user's change request. Treat the working file as the new base — changes accumulate rather than restart from the original.

---

## Step 2 — Locate and Read the Source File

Find the source file using `Glob` or `Read`. If the path is ambiguous, search `assets/` recursively.

Determine the file type:
- **SVG** → read the full file contents. You will transform it directly.
- **PNG/JPG/WebP/other raster** → note the format. You will need to use a Python script (see Step 3b).

---

## Step 3 — Apply the Transformation

### 3a. SVG files (preferred path)

SVG is XML text. Edit it directly:

- **Color changes** — find and replace `fill`, `stroke`, `flood-color`, `stop-color` values. Use regex-aware substitution to avoid partial matches.
- **Style changes** — modify `filter` elements, `opacity`, `rx`/`ry` for corner radius, gradient stops.
- **Neon/glow effects** — add or modify `<filter>` with `feGaussianBlur` + `feMerge` nodes (see the existing homeradar neon filters as a reference for the pattern).
- **Dark/light variants** — swap background fills, invert foreground/accent colors while keeping shapes intact.
- **Theme changes** — systematically replace the color palette while preserving structural elements.

Preserve:
- The `viewBox` and `xmlns` attributes
- All shape geometry (paths, circles, rects) unless the user explicitly asked to change shapes
- Filter `id` references — if you add or rename filters, update all `filter="url(#...)"` references

### 3b. Raster files (PNG/JPG/WebP)

Write a minimal Python script using Pillow to apply the transformation. Common operations:

```python
from PIL import Image, ImageOps, ImageFilter
img = Image.open("source.png")
# apply transformation...
img.save("output.png")
```

Run the script with `Bash`. If Pillow is not available, inform the user and suggest converting to SVG first or installing it with `pip install Pillow`.

---

## Step 4 — Determine Output Path

**First pass (new file):** Default output path is the same directory as the source file, with a descriptive suffix if the style label is clear, otherwise `-restyled`:
- `homeradar-logo.svg` + "dark mode" → `homeradar-logo-dark.svg`
- `homeradar-logo.svg` + "amber neon" → `homeradar-logo-amber-neon.svg`
- `app-icon.png` (ambiguous style) → `app-icon-restyled.png`

Use `AskUserQuestion` to confirm the output location only if the user seems likely to want a non-default path (e.g., they mentioned deploying to a specific location). Otherwise write to the default and state the path in your response.

**Revision passes (loop iterations):** Overwrite the existing working file — do not create a new copy per revision. The working file is the current restylized copy being refined.

---

## Step 5 — Write the Output File

Write the transformed file using the `Write` tool (or overwrite with `Write` on revision passes). For raster files, run the Python script and verify the output was created.

Briefly describe what was changed (e.g., "Changed background to dark slate #1a1a2e, removed glow filters, set all shapes to flat white").

---

## Step 6 — Update the Assets Registry

Locate `docs/assets.md` in the project root.

### If `docs/assets.md` exists:

Add, update, or remove entries as needed:
- **New file** → add a new row to the appropriate category table
- **Replaces a file** → update that file's row
- **New category** → add a new `## Category` section

Use this table format:

```markdown
| File | Full Path | Intended Use | Not Used For |
|------|-----------|-------------|--------------|
| `homeradar-logo-dark.svg` | `assets/branding/homeradar-logo-dark.svg` | Dark-mode UI, dark backgrounds | Light backgrounds, print |
```

### If `docs/assets.md` does not exist:

Create it. Enumerate all subfolders under `assets/` and list every file. Structure:

```markdown
# Assets Registry

This file catalogs all assets in the `assets/` directory. Update it whenever files are added, moved, renamed, or removed.

---

## Branding (`assets/branding/`)
...

### Archived (`assets/branding/archived/`)
...

## Screenshots (`assets/screenshots/`)
...

## Data (`assets/data/`)
...
```

Populate every known file:
- Use `Glob` with `assets/**/*` to enumerate all files recursively
- Include root-level files under a `## Reference` section
- Include archived subdirectories as subsections under their parent category
- Omit `.gitkeep` files

Skip Step 6 on revision passes — the registry entry already exists. Only update it after the user accepts (Step 7 → satisfied branch).

---

## Step 7 — Preview and Review Loop

### 7a. Launch the file

Open the output file with the system's default viewer using `Bash`:

```bash
# Detect platform and launch
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || -n "$WINDIR" ]] || command -v cmd.exe &>/dev/null; then
  cmd.exe /c start "" "$(wslpath -w "$OUTPUT_PATH" 2>/dev/null || echo "$OUTPUT_PATH")"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  open "$OUTPUT_PATH"
else
  xdg-open "$OUTPUT_PATH" &
fi
```

Replace `$OUTPUT_PATH` with the actual absolute path of the output file. On Windows with a bash shell, if `wslpath` is unavailable just use the native Windows path directly: `cmd.exe /c start "" "C:\path\to\file.svg"`.

### 7b. Ask for feedback

After launching, use `AskUserQuestion` with this prompt and these three choices:

> **"The file has been opened — take a look and let me know:"**
> - "Looks good — I'm happy with it"
> - "I'd like some changes" (describe what you'd like in your reply)
> - "Abandon — delete this file"

### 7c. Handle each response

**If "Looks good":**
- Proceed to Step 8 (propagation prompt)

**If "I'd like changes":**
- Read the user's description of what they want changed
- Return to **Step 1** (re-entry point), treating the current working file as the source and the change description as the new transformation intent
- Apply the revision (Step 2 → 3 → 4 → 5), skipping Step 6 (registry stays as-is during iteration)
- Return to **Step 7a** — launch the updated file and ask again
- Repeat until the user accepts or abandons

**If "Abandon":**
- Delete the output file using `Bash` (`rm "$OUTPUT_PATH"` / PowerShell `Remove-Item`)
- Remove its entry from `docs/assets.md` if it was added there
- Respond: "Deleted. No changes were kept." and end the turn.

---

## Step 8 — Propagate to All Usages (optional)

Ask the user (via `AskUserQuestion`):

> **"Would you like me to update the rest of the project to use the new logo?"**
> - "Yes — replace all logo usages"
> - "No — keep the new file as a standalone variant"

**If "No":** End the turn. The new file stands as an additional variant.

**If "Yes":** Proceed with propagation:

### 8a. Find all logo references

Search the codebase for references to the original source logo filename (and common logo aliases) using `Grep`:

```bash
# Example: searching for the original filename stem
grep -r "homeradar-logo" . --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
  --include="*.json" --include="*.html" --include="*.css" --include="*.md" -l
```

Also check:
- `manifest.json` / `manifest.webmanifest` — icon arrays with explicit `sizes`
- Vite/webpack config files — asset references
- Extension `manifest.json` — `icons` object with multiple size keys (16, 32, 48, 128)
- `public/` directory — any logo files served as static assets
- Import statements: `import Logo from '...'`, `import logoUrl from '...'`

### 8b. For each reference, determine the required output format

| Reference context | Output needed |
|-------------------|--------------|
| `<img src="logo.svg">` or SVG import | SVG — copy the accepted restylized SVG |
| PNG reference with size hint (e.g., `icons/logo-128.png`) | PNG at that size |
| Manifest `icons` array with `sizes` field | PNG at each declared size |
| Favicon (`.ico`) | Inform user — ICO generation requires a dedicated tool; suggest `imagemagick` or a web converter |
| CSS `background-image: url(...)` | Match the format of the existing reference |

### 8c. Generate each required variant

**SVG → SVG replacement:** The accepted restylized SVG file is already the correct output. If the reference points to a different path, copy the file there.

**SVG → PNG (required size):** Write and run a Python script:

```python
# Requires cairosvg: pip install cairosvg
import cairosvg
cairosvg.svg2png(url="path/to/logo.svg", write_to="path/to/output.png", output_width=128, output_height=128)
```

If `cairosvg` is unavailable, try `Pillow` with the SVG read as a vector fallback, or note the limitation and ask the user to handle that specific format manually.

**Raster → raster resize:** Use Pillow to resize while preserving aspect ratio.

### 8d. Update references in source files

For each file identified in 8a:
- Replace the reference to the old logo path with the new one (if the path changed)
- If the new file is in the same location with the same name (overwrite scenario), no reference update is needed — just confirm the file was replaced

### 8e. Update the assets registry

Update `docs/assets.md` to reflect any new files created during propagation and mark the original logo as superseded if it was overwritten.

---

## Handling Edge Cases

| Situation | Action |
|-----------|--------|
| Source file not found | Use `Glob` to search; if still not found, use `AskUserQuestion` |
| Transformation is ambiguous (e.g., "make it better") | Use `AskUserQuestion` — ask what visual direction they have in mind |
| User asks to overwrite the original | Confirm with `AskUserQuestion` before doing so |
| File is a binary raster and Pillow is unavailable | Inform the user; suggest SVG conversion or manual Pillow install |
| Multiple reasonable interpretations of the style | Pick the most literal/direct one, apply it, and note the interpretation in your response |
| `cairosvg` unavailable during propagation | Notify the user for that specific format; continue with formats that are achievable |
| File is opened but user can't see it (headless/remote env) | Note that the file was saved at `$PATH` and they can open it manually; continue with the review prompt |

## Diagram

[View diagram](diagram.html)
