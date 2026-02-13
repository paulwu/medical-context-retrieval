---
agent: agent
model: Claude Opus 4.5 (copilot)
description: 'Delete a wiki page and update all references throughout the project'
---
<!--
HOW TO USE:
1) Clear your context window to avoid hallucinations. [Ctrl+N] starts a New Chat
2) Switch to Agent mode instead of Ask mode for best results.
3) Use "Add Context" (paperclip icon or # in chat) to attach the page you want to remove.
4) Run the prompt:
   /RemovePage
   /RemovePage --confirm (skip confirmation prompt)
-->

# Wiki Page Deletion

Delete a wiki page and update all references to it throughout the project.

## Context Requirement

The **page to delete** must be attached via "Add Context" before running this prompt. The attached file provides:
- The full file path (determines the page to delete)
- If no file is attached, stop and instruct the user: _"Please attach the page you want to delete using Add Context (paperclip icon or #) and run this prompt again."_

## Variables

- `${{confirm}}` - Optional: If `--confirm` is provided, skip the confirmation prompt

## Instructions

Execute the following steps in order:

### 1. Validate Inputs

- Extract the **source file path** from the attached context file
- Extract the **file name** (without `.md` extension)
- Extract the **parent folder path**
- If no file is attached, stop and instruct the user to attach a page

### 2. Confirm Deletion

Unless `--confirm` flag is provided:
- Display the page to be deleted: _"You are about to delete `<filename>.md` from `<parent-folder>`. This action cannot be undone."_
- Ask user to confirm: _"Type 'yes' to proceed or 'no' to cancel."_
- Wait for user response before proceeding
- If user does not confirm, abort the operation

### 3. Scan for References

Search the entire project for references to the page being deleted in these patterns:
- Wiki-style links: `[[Page-Name]]`
- Markdown links: `[text](Page-Name.md)` or `[text](path/Page-Name.md)`
- Relative links: `](../Page-Name.md)` or `](./Page-Name.md)`
- Table links: `| [text](Page-Name.md) |`

Search locations:
- `Wiki-Staging/**/*.md`
- `EXPDOCS-Staging/**/*.md`
- Any other `.md` files in the project root

Report how many references were found before proceeding.

### 4. Handle References

For each file containing references to the deleted page:
- **Option A (Recommended)**: Comment out the link with a note:
  - Replace `[Link Text](Page-Name.md)` with `<!-- DELETED: [Link Text](Page-Name.md) -->`
  - This preserves the reference for manual review
- **Option B**: Remove the entire line if it's a TOC table entry
- Track which files were updated and how

### 5. Update Parent Folder Index

- Locate the parent folder's index page (e.g., if page is in `04-Govern-and-Compliance/`, find `04-Govern-and-Compliance.md`)
- Remove the TOC table entry pointing to the deleted page
- If other index pages reference this page, update or remove those entries

### 6. Handle Folder Pages (Special Case)

If the deleted page is a **folder index page** (e.g., `Folder-Name.md` that corresponds to `Folder-Name/`):
- Warn the user: _"This is a folder index page. Deleting it will orphan the folder contents."_
- Ask user to confirm whether to:
  - **A**: Delete only the index page (leave folder and contents)
  - **B**: Delete the entire folder and all contents
  - **C**: Cancel the operation
- If option B is selected, recursively scan all files in the folder and update references for each

### 7. Delete the File

- Use terminal command to delete: `rm "<filePath>"`
- Confirm the deletion was successful
- If folder removal was selected (step 6 option B), use `rm -rf "<folderPath>"`

### 8. Verify Cleanup

- Re-scan for any remaining references to the deleted page
- Report any orphaned references that may need manual cleanup

## Output

Provide a summary including:
1. **Removed**: `<filename>.md` from `<parent-folder>`
2. **References Updated**: List of files where references were updated (with count)
3. **TOC Entries Removed**: List of index pages updated
4. **Orphaned References**: Any references that could not be automatically updated
5. **Manual Review Suggested**: Flag any complex references that may need manual review

## Example

```
Removed: Deprecated-Feature.md from 04-Govern-and-Compliance/

References Updated (2 files):
- README.md (1 reference commented out)
- Azure-Policy.md (1 reference commented out)

TOC Entries Removed (1 file):
- 04-Govern-and-Compliance.md (1 row removed from table)

No orphaned references found.
```

## Safety Features

- **Confirmation required**: User must confirm before deletion (unless --confirm flag)
- **Reference preservation**: Links are commented out rather than deleted for audit trail
- **Folder protection**: Extra confirmation required for folder index pages
- **Dry-run awareness**: All references are scanned and reported before any deletion occurs
