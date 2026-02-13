---
agent: agent
model: Claude Opus 4.5 (copilot)
description: 'Rename a wiki page and update all references throughout the project'
argument-hint: 'new_name'
---
<!--
HOW TO USE:
1) Clear your context window to avoid hallucinations. [Ctrl+N] starts a New Chat
2) Switch to Agent mode instead of Ask mode for best results.
3) Use "Add Context" (paperclip icon or # in chat) to attach the page you want to rename.
4) Run the prompt with the new name:
   /RenamePage New-Page-Name
   /RenamePage Azure-Policy-Overview
   /RenamePage  (will prompt for new name if not provided)
-->

# Wiki Page Rename

Rename a wiki page and update all references to the old name throughout the project.

## Context Requirement

The **source page** must be attached via "Add Context" before running this prompt. The attached file provides:
- The full file path (determines the current name and location)
- If no file is attached, stop and instruct the user: _"Please attach the page you want to rename using Add Context (paperclip icon or #) and run this prompt again."_

## Variables

- `${{newName}}` - The new page name (without `.md` extension). If not provided, prompt the user to supply one.

## Instructions

Execute the following steps in order:

### 1. Validate Inputs

- Extract the **source file path** from the attached context file
- Extract the **current file name** (without `.md` extension)
- Extract the **parent folder path**
- If `${{newName}}` is empty or not provided:
  - Ask the user: _"What should the new page name be? (Use kebab-case, e.g., `Azure-Policy-Overview`)"_
  - Wait for user response before proceeding
- Validate the new name:
  - Must use kebab-case (words separated by hyphens)
  - No spaces or special characters except hyphens
  - If invalid, suggest a corrected version and confirm

### 2. Check for Conflicts

- Verify no file with `${{newName}}.md` already exists in the same folder
- If conflict exists, stop and inform user: _"A file named `<newName>.md` already exists in this folder. Please choose a different name."_

### 3. Rename the File

- Use terminal command to rename: `mv "<oldPath>" "<newPath>"`
- Confirm the rename was successful

### 4. Scan for References

Search the entire project for references to the old page name in these patterns:
- Wiki-style links: `[[Old-Page-Name]]`
- Markdown links: `[text](Old-Page-Name.md)` or `[text](path/Old-Page-Name.md)`
- Relative links: `](../Old-Page-Name.md)` or `](./Old-Page-Name.md)`
- Table links: `| [text](Old-Page-Name.md) |`

Search locations:
- `Wiki-Staging/**/*.md`
- `EXPDOCS-Staging/**/*.md`
- Any other `.md` files in the project root

### 5. Update References

For each file containing references to the old page name:
- Replace `[[Old-Page-Name]]` with `[[New-Page-Name]]`
- Replace `Old-Page-Name.md` with `New-Page-Name.md` in all link formats
- Preserve the surrounding link text and path structure
- Track which files were updated

### 6. Update Parent Folder Index

- Locate the parent folder's index page (e.g., if page is in `04-Govern-and-Compliance/`, find `04-Govern-and-Compliance.md`)
- Update any TOC table entries pointing to the old name
- Update any inline references to the old name

### 7. Handle Folder Pages (Special Case)

If the renamed page is a **folder index page** (e.g., `Folder-Name.md` that corresponds to `Folder-Name/`):
- Also rename the corresponding folder using `mv`
- Update all paths that referenced the old folder name
- This is a more complex operation—confirm with user before proceeding

## Output

Provide a summary including:
1. **Renamed**: `<old-name>.md` → `<new-name>.md`
2. **References Updated**: List of files where references were updated (with count)
3. **No References Found**: Confirmation if no other files referenced the old name
4. **Manual Review Suggested**: Flag any complex references that may need manual review

## Example

```
Renamed: Resource-Consistency-Naming-&-Tagging-Standards.md → Naming-Tagging-Standard.md

References Updated (3 files):
- 04-Govern-and-Compliance.md (2 references)
- Azure-Policy.md (1 reference)
- README.md (1 reference)

No manual review needed.
```