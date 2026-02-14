# Contributing to SwiftCMS

## Getting Started
1. Fork the repository
2. Create a branch: `wave-{N}/agent-{N}-{short-desc}`
3. Make your changes following the coding standards
4. Write tests (minimum 1 per public function)
5. Submit a PR

## Coding Standards
- Swift 5.10+, async/await only
- UpperCamelCase for types, lowerCamelCase for properties/functions
- `///` doc comments on all public types and methods
- No force unwraps, no print() in production code
- Imports sorted alphabetically

## Commit Messages
`[Agent-N] Module: Description`

Example: `[Agent-3] CMSSchema: Add content_entries migration`

## Module Ownership
Each directory is owned by a specific agent. Only create/edit files in your assigned directories.
Need a change elsewhere? Write it in HANDOFF.md.
