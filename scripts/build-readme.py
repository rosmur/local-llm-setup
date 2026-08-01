#!/usr/bin/env python3
"""
Build README.md from the canonical docs/ pages.

Usage:
    python3 scripts/build-readme.py

Run from the repo root. The script reads each docs page, applies
Markdown transformations (admonitions → GitHub-compatible, heading
level adjustments, link rewrites), assembles them in order, generates
a Table of Contents, and writes README.md.
"""

import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DOCS = REPO_ROOT / "docs"

# ---------------------------------------------------------------------------
# Section descriptors
# ---------------------------------------------------------------------------
# Each entry is a dict with keys:
#   source  – Path to docs/ file, or None for static content
#   num     – section number string, or None (for intro/glossary)
#   title   – section title, or None
#   static  – literal markdown (only used when source is None)

SECTIONS = [
    # Numbered sections (content from docs/ pages)
    dict(source="quick-start.md",        num="1", title="Quick Start"),
    dict(source="whats-installed.md",    num="2", title="What's installed"),
    dict(source="requirements.md",       num="3", title="Requirements"),
    dict(source="model-choices.md",      num="4", title="Model Choices"),
    dict(source="usage.md",              num="5", title="Usage"),
    dict(source="uninstallation.md",     num="6", title="Uninstallation"),
    # Static section 7
    dict(source=None, num="7", title="Manual Installation",
         static=(
             "Manual installation is recommended if you:\n\n"
             "- Are familiar with the terminal, bash, config files etc.\n"
             "- Wish to install only a subset of items\n"
             "- Want to make modifications not supported by the script "
             "like alternate models, usage of docker etc.\n\n"
             "See [here for step by step installation instructions]"
             "(docs/script-manual.md)\n"
         )),
    # Static section 8
    dict(source=None, num="8", title="Additional Info",
         static=(
             "| Doc | Description |\n"
             "| ------ | -------- |\n"
             "| [Troubleshooting](docs/TROUBLESHOOTING.md) | "
             "Common issues and gotchas, along with known gaps/caveats |\n"
             "| [Legacy Instructions]("
             "https://gist.github.com/rosmur/"
             "84f0a77404bd901263de26566ab06f08"
             ") | Previous version |\n"
         )),
    # Glossary
    dict(source="glossary.md",           num=None, title="Glossary"),
]

# ---------------------------------------------------------------------------
# Transformations
# ---------------------------------------------------------------------------

def _admonition_replacement(m: re.Match) -> str:
    """Convert a MkDocs !!! admonition into a GitHub blockquote."""
    kind = m.group(1).lower()
    quoted_title = m.group(2)         # e.g. "Exploring other models" or None
    raw_content = m.group(3)          # indented body (may be empty)

    label_map = {
        "note": "Note",
        "warning": "Warning",
        "tip": "Tip",
        "danger": "Danger",
        "info": "Info",
    }
    label = quoted_title if quoted_title else label_map.get(kind, kind.capitalize())

    # Strip 4-space indent from body lines
    body_lines = []
    for line in raw_content.split("\n"):
        if line.startswith("    "):
            body_lines.append(line[4:])
        elif line.strip() == "":
            body_lines.append("")
        else:
            body_lines.append(line)
    body = "\n".join(body_lines).strip()

    if not body:
        return f"> **{label}**\n"

    # Turn each body line into a blockquote line
    quoted_lines = [f"> {l}" if l else ">" for l in body.split("\n")]
    quoted = "\n".join(quoted_lines)

    # Merge label into first line
    first = quoted.split("\n")[0]
    rest = "\n".join(quoted.split("\n")[1:])
    merged = f"> **{label}.** {first[2:]}".rstrip()
    if rest:
        return merged + "\n" + rest + "\n"
    return merged + "\n"


def convert_admonitions(text: str) -> str:
    """Convert MkDocs !!! admonitions to GitHub blockquotes."""
    # The directive line, then optional blank lines, then indented content lines
    pattern = re.compile(
        r"^!!!\s+(\w+)\s*(?:\"([^\"]*)\")?\n"
        r"(?:[ \t]*\n)*"       # blank lines between directive and content
        r"((?:(?:    .*)\n?)*)",  # indented content
        re.MULTILINE,
    )
    return pattern.sub(_admonition_replacement, text)


def remove_grid_cards(text: str) -> str:
    """Strip <div class="grid cards" markdown> wrappers, keep inner content."""
    text = re.sub(
        r'<div\s+class="grid\s+cards"\s+markdown>\s*\n?', "", text,
    )
    text = re.sub(r"</div>\s*\n?", "", text)
    return text


def convert_internal_links(text: str) -> str:
    """Convert .md internal links to README anchor links."""
    LINK_MAP = {
        "quick-start.md": "#1-quick-start",
        "whats-installed.md": "#2-whats-installed",
        "requirements.md": "#3-requirements",
        "model-choices.md": "#4-model-choices",
        "usage.md": "#5-usage",
        "uninstallation.md": "#6-uninstallation",
        "glossary.md": "#glossary",
        "script-manual.md": "#7-manual-installation",
    }

    def _link_replace(m: re.Match) -> str:
        full = m.group(0)           # [text](path.md)
        label = m.group(1)          # [text]
        path = m.group(2)           # path.md
        anchor = LINK_MAP.get(path)
        if anchor:
            return f"{label}({anchor})"
        return full                 # leave unknown links unchanged

    # Match [text](path.md) — closing paren is NOT consumed here
    return re.sub(r"(\[[^\]]*\])\s*\(([^)]+\.md)\)", _link_replace, text)


def process_section(source: str | None, num: str | None,
                    title: str, static: str | None) -> str:
    """Load a docs page and transform it for README inclusion.

    Returns the full markdown block for one section, including its heading.
    """
    if source is None:
        # Static section
        heading = f"## {num}. {title}" if num else f"## {title}"
        return heading + "\n\n" + static.strip()

    path = DOCS / source
    text = path.read_text(encoding="utf-8")

    # Apply transformations
    text = remove_grid_cards(text)
    text = convert_admonitions(text)
    text = convert_internal_links(text)

    # --- Heading adjustment ---
    lines = text.split("\n")
    adjusted = []
    for line in lines:
        heading_match = re.match(r"^(#+)(\s+)(.*)", line)
        if not heading_match:
            adjusted.append(line)
            continue

        hashes, space, rest = heading_match.groups()
        level = len(hashes)

        # The top-level heading of each page
        if level == 1:
            if num:
                adjusted.append(f"## {num}. {rest}")
            else:
                adjusted.append(f"## {rest}")
        else:
            # Shift all other headings one level deeper
            adjusted.append(f"#{'#' * level} {rest}")
            # Actually shift: ## → ###, ### → ####, etc.
            # Let me redo — just prepend one #
            adjusted[-1] = "#" + hashes + space + rest

    text = "\n".join(adjusted)

    return text


# ---------------------------------------------------------------------------
# Intro block from index.md
# ---------------------------------------------------------------------------

def build_header() -> str:
    """Extract title, badge, intro paragraph, and motto from docs/index.md."""
    text = (DOCS / "index.md").read_text(encoding="utf-8")

    parts = []

    # Title — rewrite with em-dash normalized and omit-from-toc comment
    m = re.search(r"^(# .+)$", text, re.MULTILINE)
    if m:
        title = m.group(1).replace("—", "-")
        parts.append(f"{title} <!-- omit from toc -->")
    else:
        parts.append("# Local LLM Setup - Mac Edition <!-- omit from toc -->")

    parts.append("")
    parts.append(
        "[![Documentation](https://img.shields.io/badge/"
        "docs-mkdocs-blue?style=flat-square)]"
        "(https://rosmur.github.io/local-llm-setup/)"
    )
    parts.append("")

    # Intro paragraph (text between title and motto)
    m = re.search(r"\n\n(.+?)\n\n(\*\*.+?\*\*)", text, re.DOTALL)
    if m:
        parts.append(m.group(1).strip())

    # Motto (bold sentence with period inside the bold markers)
    m = re.search(r"(\*\*[^*]+\*\*)", text)
    if m:
        motto = m.group(1).replace("—", "-")
        parts.append("")
        parts.append(motto)

    return "\n".join(parts)


def build_reading_guide() -> str:
    """Extract the Reading Guide from docs/index.md and format it."""
    text = (DOCS / "index.md").read_text(encoding="utf-8")
    m = re.search(
        r"^## Reading Guide\n\n(.+?)(?=\n##|\Z)", text, re.MULTILINE | re.DOTALL,
    )
    if not m:
        return ""
    guide = m.group(1).strip()
    guide = convert_internal_links(guide)
    return f"**Reading guide.** {guide}"


# ---------------------------------------------------------------------------
# ToC
# ---------------------------------------------------------------------------

def generate_toc() -> str:
    """Generate the Table of Contents."""
    lines = ["## Table of Contents <!-- omit from toc -->", ""]
    for sec in SECTIONS:
        n, t = sec["num"], sec["title"]
        if n and t:
            slug = re.sub(r"[^a-zA-Z0-9\s-]", "", t.lower())
            slug = re.sub(r"[-\s]+", "-", slug).strip("-")
            lines.append(f"- [{n}. {t}](#{n}-{slug})")
        elif t == "Glossary":
            lines.append(f"- [{t}](#glossary)")
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# Assembly
# ---------------------------------------------------------------------------

def build_readme() -> str:
    """Assemble the full README.md."""
    blocks = []

    # Header
    blocks.append(build_header())
    blocks.append("")

    # ToC
    blocks.append(generate_toc())
    blocks.append("")

    # Reading guide
    rg = build_reading_guide()
    if rg:
        blocks.append(rg)
        blocks.append("")

    # Numbered sections + glossary
    for i, sec in enumerate(SECTIONS):
        content = process_section(
            sec["source"], sec["num"], sec["title"], sec.get("static"),
        )
        blocks.append(content)
        # Separator between sections (but not after the last one)
        if i < len(SECTIONS) - 1:
            blocks.append("")
            blocks.append("---")
            blocks.append("")

    return "\n".join(blocks) + "\n"


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    readme_path = REPO_ROOT / "README.md"
    content = build_readme()
    readme_path.write_text(content, encoding="utf-8")
    print(f"✓ Wrote {readme_path} ({len(content)} bytes, "
          f"{content.count(chr(10))} lines)")


if __name__ == "__main__":
    main()
