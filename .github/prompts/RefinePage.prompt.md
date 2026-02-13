---
agent: agent
model: Claude Opus 4.5 (copilot)
description: 'Refine a wiki page for spelling, grammar, fluency, link validity, and technical accuracy'
---
<!--
HOW TO USE:
1) Clear your context window to avoid hallucinations. [Ctrl+N] starts a New Chat
2) Switch to Agent mode instead of Ask mode for best results.
3) Use "Add Context" (paperclip icon or # in chat) to attach the page you want refined.
4) Run the prompt:
   /RefinePage
   /RefinePage this page covers Azure Policy design for the EXP environment
-->

# Page Refinement

Refine an attached wiki page for correctness, readability, and link integrity.

## Context Requirement

The **page to refine** must be attached via "Add Context" before running this prompt. The attached file provides:
- The full file path (used for relative link validation)
- The file content (used for all refinement tasks)

Do NOT ask the user for the page — it is already in your context. If no file is attached, stop and instruct the user: _"Please attach the page you want refined using Add Context (paperclip icon or #) and run this prompt again."_

## Variables

- `${{pageContext}}` - Optional: User-provided description or context about what the page should cover

## Tasks

Execute the following checks in order. Apply fixes directly to the file.

### 1. Spelling

- Fix all misspellings including technical terms and product names
- Use correct casing for proper nouns and product names:
  - Azure, Microsoft, OneMTC, PowerShell, GitHub, VS Code, Terraform, Bicep, Entra ID, etc.
- Do not alter code blocks, URLs, or filenames

### 2. Grammar

- Correct subject-verb agreement, tense consistency, and punctuation
- Fix sentence fragments and run-on sentences
- Ensure correct use of articles (a/an/the), prepositions, and conjunctions
- Standardize list formatting (parallel structure, consistent punctuation)

### 3. Fluency

- Improve readability and professional tone without changing technical meaning
- Remove filler phrases ("it should be noted that", "basically", "in order to")
- Tighten verbose passages — prefer concise, direct language
- Ensure logical flow between paragraphs and sections
- {{#if pageContext}}Evaluate content completeness based on: {{pageContext}}{{/if}}

### 4. Link Validation

- **Internal links**: Verify all relative paths (`[text](path.md)` and `[[Page Name]]` formats) resolve to existing files in the workspace
- **External links**: Verify URLs point to valid, reachable resources — fix or flag unreachable links
- **Image references**: Verify all `![alt](path)` references point to existing files in `.attachments/`
- **Anchors**: Check that heading-based anchors (`#section-name`) match actual headings
- Remove or flag any broken links with a `<!-- BROKEN LINK: reason -->` comment if a replacement cannot be determined

### 5. Technical Accuracy

- Verify accuracy of Azure, CAF, WAF, and ADO-related content against current Microsoft Learn documentation
- Correct outdated terminology (e.g., "Azure AD" → "Microsoft Entra ID")
- Validate CLI commands, API references, and configuration examples
- Ensure architectural guidance aligns with current Microsoft best practices
- Flag any claims that cannot be verified with a `<!-- VERIFY: description -->` comment

## Output

- Apply all corrections directly to the attached file
- After applying changes, provide a brief summary listing:
  - Number of spelling/grammar fixes
  - Any broken or updated links
  - Any technical accuracy corrections
  - Any items flagged for manual review
- Do NOT rewrite content beyond what is needed for the five tasks above
