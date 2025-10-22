# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a personal blog and portfolio site built with [Zola](https://getzola.org), a fast static site generator written in Rust. The repository contains the site's content (blog posts, talks, projects), configuration, and uses the Apollo theme as a git submodule.

**Site URL:** https://not-matthias.github.io

## Development Commands

### Building and Running
- `zola serve` - Start development server with live reload at http://localhost:1111
- `zola build` - Build production-ready site into `public/` directory
- `zola check` - Validate site for broken links and build issues

### Development Environment Setup
The project uses `devenv` for environment management:
- `.envrc` - Direnv configuration that activates devenv
- `devenv.nix` - Declares zola as the primary dependency
- Auto-loads zola when entering the directory (with direnv)

### Pre-commit Hooks
- `taplo` - TOML file formatting (enabled in git hooks)
- Pre-commit hooks auto-run on commits via devenv's git-hooks configuration

## Architecture

### Repository Structure
```
├── config.toml              # Main site configuration (base_url, theme, menu, etc.)
├── content/                 # Zola content directory
│   ├── _index.md           # Homepage
│   ├── now.md              # /now page
│   ├── posts/              # Blog posts
│   ├── projects/           # Projects listing
│   └── talks/              # Conference talks and presentations
├── themes/apollo           # Apollo theme (git submodule)
│   └── CLAUDE.md           # Guidance for theme development
├── static/
│   ├── images/             # Source images
│   ├── processed_images/   # Pre-processed images for web
│   └── *.css               # Syntax highlighting stylesheets
├── templates/              # Site-specific template overrides
│   └── home.html           # Custom homepage template
├── devenv.nix              # Development environment declaration
└── lighthouserc.json       # Lighthouse CI configuration
```

### Configuration System
**config.toml** contains all site-wide settings:
- `base_url` - The site domain (https://not-matthias.github.io)
- `theme` - Apollo theme reference
- `markdown.highlight_code` - Syntax highlighting enabled
- `build_search_index` - Currently disabled (search not used)
- `generate_feeds` - Atom and RSS feeds enabled
- `[extra]` section - Theme-specific customizations:
  - `menu` - Navigation menu items with weights
  - `socials` - Social media links (Twitter, GitHub, RSS)
  - `theme = "toggle"` - Light/dark theme toggle enabled
  - `[extra.analytics]` - GoatCounter and Umami analytics

### Content Organization
- **Posts** (`content/posts/`): Blog articles with metadata
- **Talks** (`content/talks/`): Conference talks and presentation information
- **Projects** (`content/projects/`): Project listings
- **Pages** (`content/*.md`): Standalone pages like /now

Each markdown file uses Zola front matter (TOML between `+++`) for metadata:
- `title` - Page title
- `date` - Publication date
- `draft` - Draft status
- `tags` - Content taxonomy (configured as "tags" in config)

### Theme Integration (Apollo Submodule)
The Apollo theme is maintained as a separate repository and included as a git submodule:
- Located at `themes/apollo/`
- Contains all templates, styling, and theme-specific JavaScript
- Has its own CLAUDE.md documenting theme development
- Update with: `git submodule update --remote themes/apollo`
- To work on theme: clone the Apollo repository separately and update the submodule reference

### Custom Site Assets
- `templates/home.html` - Optional homepage override (if present, overrides theme's homepage)
- `static/` - Custom CSS and images at site level

## Key Features

### Multi-page Content
- Homepage with custom layout
- Blog posts section
- Talks section for conference presentations
- Projects listing
- Individual /now page

### Analytics Integration
Two analytics providers configured:
- **GoatCounter** (privacy-focused): `user = "not-matthias"` in config
- **Umami**: `website_id = "74344cd8-1e87-4c38-8acd-f96049b8f07e"` in config

Both are optional and defined in the theme's config handling.

### Feed Generation
- Atom feed: `/atom.xml`
- RSS feed: `/rss.xml`
- Configured to auto-generate from content

### Syntax Highlighting
- Dark theme: `syntax-theme-dark.css` (Ayu Dark)
- Light theme: `syntax-theme-light.css` (Ayu Light)
- Theme switcher in UI controlled by Apollo theme

## Deployment

### GitHub Actions Workflow
The `.github/workflows/zola.yml` handles automatic deployment:

**Lighthouse Job** (Performance auditing)
- Runs `zola build --output-dir ./dist`
- Executes Lighthouse CI checks against built site
- Uses configuration from `lighthouserc.json`
- Artifacts uploaded for audit trail

**Build Job** (Deployment)
- Uses `shalzz/zola-deploy-action@master`
- Automatically builds and deploys to GitHub Pages
- Triggered on push to `main` branch
- Can be manually triggered via `workflow_dispatch`

The workflow checks out with:
- `lfs: true` - Git LFS support for large files
- `submodules: "recursive"` - Fetches the Apollo theme submodule

## Common Development Tasks

### Adding a New Blog Post
1. Create `content/posts/my-post/index.md` or `content/posts/my-post.md`
2. Include front matter:
   ```toml
   +++
   title = "Post Title"
   date = 2024-10-22
   tags = ["rust", "web"]
   +++
   ```
3. Run `zola serve` to preview
4. Build with `zola build` when ready

### Adding a New Talk
1. Create `content/talks/talk-title.md`
2. Include appropriate metadata in front matter
3. Similar structure to blog posts

### Updating the Apollo Theme
The theme is a separate repository used as a submodule. To update:
```bash
git submodule update --remote themes/apollo
git add themes/apollo
git commit -m "chore: update theme"
```

### Checking for Issues
```bash
zola check
```

This validates:
- Internal links
- Link integrity
- Configuration issues
- Build problems

## Image Handling

**Image Assets:**
- Source images: `static/images/`
- Pre-processed/optimized images: `static/processed_images/`

Images are referenced in content and served from the `static/` directory.

## Git Workflow

**Branch Protection:**
- Main branch is `main`
- GitHub Pages deployment happens automatically on push to main

**Important Files to Not Modify Lightly:**
- `config.toml` - Site configuration (affects all pages)
- `.github/workflows/zola.yml` - CI/CD pipeline
- `devenv.nix` - Development environment

**Submodule Awareness:**
- The `themes/apollo` directory is a git submodule
- Changes to theme should be made in the Apollo repository, not here
- Only update the submodule reference when pulling theme updates

## Performance and Quality

### Lighthouse CI
The Lighthouse CI job in the workflow ensures performance standards:
- Configuration in `lighthouserc.json`
- Tests performance, accessibility, best practices
- Reports available in GitHub Actions artifacts

### Link Checking
Zola's built-in link checker configured with:
- `[link_checker] internal_level = "warn"` - Warns about broken internal links

## Notes for Theme Customization

Since Apollo is a submodule:
- Don't modify files in `themes/apollo/` directly in this repo
- Custom site-level template overrides go in `templates/`
- Custom site-level styles would go in `static/` with appropriate CSS
- Theme documentation available in `themes/apollo/CLAUDE.md`

To modify the theme itself:
1. Clone the Apollo repository separately
2. Make changes there
3. Update the submodule reference in this repository
4. Or configure fork/branch in `.gitmodules`
