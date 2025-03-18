# Rust Docs to Wiki

This GitHub Action automatically extracts documentation from Rust source code and publishes it to your repository's GitHub Wiki.

## Features

- Extracts module-level documentation (//! comments)
- Documents all public items (structs, enums, traits, functions, etc.)
- Preserves documentation comments (/// comments)
- Creates table of contents with links to items
- Publishes to GitHub Wiki automatically
- Customizable with several configuration options

## Usage

Add the following to your GitHub workflow file (e.g., `.github/workflows/wiki.yml`):

```yaml
name: Update Wiki Documentation

on:
  push:
    branches: [ main, master ]
    paths:
      - '**/*.rs'
      - 'Cargo.toml'
  workflow_dispatch:  # Allow manual triggering

jobs:
  update-wiki:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Generate Rust Wiki Docs
        uses: tristanpoland/rust-docs-to-wiki-action@v1
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          # Optional customizations:
          # source_path: 'src'
          # wiki_path: 'wiki-content'
          # commit_message: 'Update documentation from Rust code'
          # excluded_paths: 'src/generated,src/tests'
          # extract_private: 'false'
          # max_definition_lines: '50'
```

### Token Permissions

To allow the action to push to your wiki, you need to provide a token with the appropriate permissions. The default `GITHUB_TOKEN` should work for most cases.

For private repositories or if you encounter permission issues, you might need to create a Personal Access Token (PAT) with the `repo` scope and store it as a repository secret.

## Configuration Options

| Input | Description | Default |
|-------|-------------|---------|
| `token` | GitHub token for wiki access | `${{ github.token }}` |
| `source_path` | Directory containing Rust source files | `src` |
| `wiki_path` | Directory to store generated wiki content before publishing | `wiki-content` |
| `commit_message` | Commit message for wiki updates | `Update documentation from Rust code` |
| `excluded_paths` | Comma-separated list of paths to exclude | `''` (empty) |
| `extract_private` | Whether to extract private items (true/false) | `false` |
| `max_definition_lines` | Maximum number of lines to extract for each definition | `50` |

## Output Structure

The action generates:

- A `Home.md` page with links to all documented files
- Individual pages for each Rust file with:
  - Module-level documentation
  - Table of contents
  - Documentation for all public items
  - Code definitions with syntax highlighting
  - Formatted documentation comments

## License

Apache-2.0 license
