#!/usr/bin/env python3
"""Pure helpers for the release workflow (C42): the next version, the Sparkle appcast and the
legacy version.json. They never touch the network; the workflow passes everything in.

Usage:
  release_tools.py next-version --tags "<tags>" --project-version 1.0.0 --bump patch
  release_tools.py build-number --commit-count 220 --project-build 116
  release_tools.py bump-from-labels --labels "release:minor,docs"
  release_tools.py merged-pull-request --base main < pulls.json
  release_tools.py project-setting --name MARKETING_VERSION \
      --bundle-id com.didisouzacosta.CleanerXcode < project.pbxproj
  release_tools.py appcast --existing appcast.xml --version 1.0.1 --build 221 \
      --url https://downloads.example.com/CleanerXcode-1.0.1-221.zip --length 123 \
      --signature <base64> --notes-file notes.md --minimum-system 26.0 --output appcast.xml
  release_tools.py version-json --version 1.0.1 --build 221 --url <dmg url> --output version.json
"""

import argparse
import html
import json
import re
import sys
import xml.etree.ElementTree as ET
from email.utils import formatdate
from typing import List, Optional, Tuple

SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
DC_NS = "http://purl.org/dc/elements/1.1/"
SEMVER = re.compile(r"^v?(\d+)\.(\d+)\.(\d+)$")
BUMPS = ("patch", "minor", "major")
DEFAULT_KEEP = 10

ET.register_namespace("sparkle", SPARKLE_NS)
ET.register_namespace("dc", DC_NS)


def parse_version(text: str) -> Optional[Tuple[int, int, int]]:
    match = SEMVER.match(text.strip())
    return tuple(int(part) for part in match.groups()) if match else None


def format_version(version: Tuple[int, int, int]) -> str:
    return "%d.%d.%d" % version


def bump(version: Tuple[int, int, int], kind: str) -> Tuple[int, int, int]:
    major, minor, patch = version
    if kind == "major":
        return (major + 1, 0, 0)
    if kind == "minor":
        return (major, minor + 1, 0)
    return (major, minor, patch + 1)


def next_version(tags: List[str], project_version: str, kind: str) -> str:
    """The latest semantic tag bumped by `kind`, unless the project already names a newer version
    (the first release of a new line, such as 1.0.0 after v0.7.0)."""
    if kind not in BUMPS:
        raise ValueError("unknown bump: %s" % kind)

    released = [version for version in (parse_version(tag) for tag in tags) if version]
    project = parse_version(project_version)

    if not released:
        return format_version(project or (1, 0, 0))

    latest = max(released)
    candidate = bump(latest, kind)

    if project and project > latest:
        return format_version(max(project, candidate))

    return format_version(candidate)


def build_number(commit_count: int, project_build: int) -> int:
    """Sparkle compares CFBundleVersion, so it only grows: the commits on main, never at or below
    the build already in the project."""
    return max(commit_count, project_build + 1)


def bump_from_labels(labels: List[str]) -> str:
    """`skip` for `skip-release`, then the biggest `release:<kind>` label, else `patch`."""
    names = {label.strip().lower() for label in labels if label.strip()}

    if "skip-release" in names:
        return "skip"

    for kind in ("major", "minor"):
        if "release:%s" % kind in names:
            return kind

    return "patch"


def project_setting(pbxproj: str, name: str, bundle_id: str) -> str:
    """A build setting of the target with `bundle_id`, the same in all its configurations;
    anything else fails, so the release never takes the test target's value by accident."""
    blocks = re.findall(r"buildSettings = \{(.*?)\n\t\t\t\};", pbxproj, re.S)
    owned = [block for block in blocks if re.search(r"\bPRODUCT_BUNDLE_IDENTIFIER = \"?%s\"?;" % re.escape(bundle_id), block)]
    values = {match.strip().strip('"') for block in owned for match in re.findall(r"\b%s = ([^;]+);" % re.escape(name), block)}

    if len(values) != 1:
        raise ValueError("%s: expected one value, found %s" % (name, sorted(values)))

    return values.pop()


def merged_pull_request(pulls, base: str) -> Tuple[Optional[int], List[str]]:
    """The pull request merged into `base` among those GitHub lists for a commit (it also lists
    open ones that contain it). Anything but a list is an API error: fail instead of releasing."""
    if not isinstance(pulls, list):
        raise ValueError("unexpected answer from the GitHub API: %r" % (pulls,))

    for pull in pulls:
        if pull.get("merged_at") and (pull.get("base") or {}).get("ref") == base:
            labels = [label.get("name", "") for label in pull.get("labels") or []]
            return pull.get("number"), labels

    return None, []


def notes_html(markdown: str) -> str:
    """A small, safe rendering of the PR notes for Sparkle's window: escaped text, `- ` bullets
    as a list and other lines as paragraphs."""
    blocks: List[str] = []
    bullets: List[str] = []

    def flush() -> None:
        if bullets:
            blocks.append("<ul>%s</ul>" % "".join("<li>%s</li>" % item for item in bullets))
            bullets.clear()

    for raw in markdown.splitlines():
        line = raw.strip()

        if line.startswith(("- ", "* ")):
            bullets.append(html.escape(line[2:].strip()))
            continue

        flush()

        if line:
            blocks.append("<p>%s</p>" % html.escape(line.lstrip("#").strip()))

    flush()

    return "".join(blocks) or "<p>Bug fixes and improvements.</p>"


def sparkle(tag: str) -> str:
    return "{%s}%s" % (SPARKLE_NS, tag)


def build_item(args: argparse.Namespace, notes: str) -> ET.Element:
    item = ET.Element("item")
    ET.SubElement(item, "title").text = "Version %s" % args.version
    ET.SubElement(item, "pubDate").text = args.pub_date or formatdate(usegmt=True)
    ET.SubElement(item, sparkle("version")).text = str(args.build)
    ET.SubElement(item, sparkle("shortVersionString")).text = args.version
    ET.SubElement(item, sparkle("minimumSystemVersion")).text = args.minimum_system
    ET.SubElement(item, "description").text = notes_html(notes)
    ET.SubElement(
        item,
        "enclosure",
        {
            "url": args.url,
            "length": str(args.length),
            "type": "application/octet-stream",
            sparkle("edSignature"): args.signature,
        },
    )
    return item


def update_appcast(existing: Optional[str], args: argparse.Namespace, notes: str) -> str:
    """Adds the new item first, drops an older item with the same build, keeps the newest
    `keep` items, and leaves the rest of the feed as it was."""
    if existing and existing.strip():
        root = ET.fromstring(existing)
        channel = root.find("channel")
        if channel is None:
            raise ValueError("appcast without a channel")
    else:
        root = ET.Element("rss", {"version": "2.0"})
        channel = ET.SubElement(root, "channel")
        ET.SubElement(channel, "title").text = "CleanerXcode"

    items = channel.findall("item")

    for item in items:
        version = item.find(sparkle("version"))
        if version is not None and version.text == str(args.build):
            channel.remove(item)

    first_item_index = next(
        (index for index, child in enumerate(list(channel)) if child.tag == "item"),
        len(list(channel)),
    )
    channel.insert(first_item_index, build_item(args, notes))

    for stale in channel.findall("item")[args.keep:]:
        channel.remove(stale)

    ET.indent(root, space="  ")

    return '<?xml version="1.0" encoding="utf-8"?>\n' + ET.tostring(root, encoding="unicode") + "\n"


def version_json(version: str, build: int, url: str) -> str:
    return json.dumps({"version": version, "build": str(build), "downloadURL": url}, indent=4) + "\n"


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    commands = parser.add_subparsers(dest="command", required=True)

    next_parser = commands.add_parser("next-version")
    next_parser.add_argument("--tags", default="")
    next_parser.add_argument("--project-version", required=True)
    next_parser.add_argument("--bump", choices=BUMPS, default="patch")

    build_parser = commands.add_parser("build-number")
    build_parser.add_argument("--commit-count", type=int, required=True)
    build_parser.add_argument("--project-build", type=int, required=True)

    labels_parser = commands.add_parser("bump-from-labels")
    labels_parser.add_argument("--labels", default="")

    setting_parser = commands.add_parser("project-setting")
    setting_parser.add_argument("--name", required=True)
    setting_parser.add_argument("--bundle-id", required=True)

    pull_parser = commands.add_parser("merged-pull-request")
    pull_parser.add_argument("--base", default="main")

    appcast_parser = commands.add_parser("appcast")
    appcast_parser.add_argument("--existing")
    appcast_parser.add_argument("--version", required=True)
    appcast_parser.add_argument("--build", type=int, required=True)
    appcast_parser.add_argument("--url", required=True)
    appcast_parser.add_argument("--length", type=int, required=True)
    appcast_parser.add_argument("--signature", required=True)
    appcast_parser.add_argument("--notes-file")
    appcast_parser.add_argument("--minimum-system", default="26.0")
    appcast_parser.add_argument("--keep", type=int, default=DEFAULT_KEEP)
    appcast_parser.add_argument("--pub-date")
    appcast_parser.add_argument("--output", required=True)

    json_parser = commands.add_parser("version-json")
    json_parser.add_argument("--version", required=True)
    json_parser.add_argument("--build", type=int, required=True)
    json_parser.add_argument("--url", required=True)
    json_parser.add_argument("--output", required=True)

    args = parser.parse_args(argv)

    if args.command == "next-version":
        print(next_version(args.tags.split(), args.project_version, args.bump))
    elif args.command == "build-number":
        print(build_number(args.commit_count, args.project_build))
    elif args.command == "bump-from-labels":
        print(bump_from_labels(args.labels.split(",")))
    elif args.command == "project-setting":
        print(project_setting(sys.stdin.read(), args.name, args.bundle_id))
    elif args.command == "merged-pull-request":
        number, labels = merged_pull_request(json.load(sys.stdin), args.base)
        print("number=%s" % (number or ""))
        print("labels=%s" % ",".join(labels))
    elif args.command == "appcast":
        existing = None
        if args.existing:
            try:
                with open(args.existing, encoding="utf-8") as handle:
                    existing = handle.read()
            except FileNotFoundError:
                existing = None
        notes = ""
        if args.notes_file:
            with open(args.notes_file, encoding="utf-8") as handle:
                notes = handle.read()
        with open(args.output, "w", encoding="utf-8") as handle:
            handle.write(update_appcast(existing, args, notes))
    elif args.command == "version-json":
        with open(args.output, "w", encoding="utf-8") as handle:
            handle.write(version_json(args.version, args.build, args.url))

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
