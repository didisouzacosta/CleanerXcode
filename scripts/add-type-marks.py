#!/usr/bin/env python3
"""Drafts the opening MARK required by SwiftLint's required_type_mark rule.

Usage: scripts/add-type-marks.py FILE...  (scripts/lint-swift.sh --add-marks passes the gate paths)

The name is a draft for human review:
- extensions declaring conformances use the protocol names;
- `Type+Feature.swift` extensions of `Type` use the feature name ("Back Frame Processing");
- otherwise the category of the first member: Cases, States, Environments, Bindables,
  Bindings, Body, Initializer, Public/Private Properties, Public/Private Methods,
  Nested Types or Tests.
A MARK already glued to the opening brace only gets the missing blank line.
"""
import json
import os
import re
import subprocess
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DECL = re.compile(
    r"^\s*(?:@[\w.]+(?:\([^()]*\))?\s+)*"
    r"(?:(?:public|private|fileprivate|internal|open|final|indirect|package|nonisolated)\s+)*"
    r"(class|struct|enum|actor|extension)\s+([A-Za-z_][\w.]*)"
)
ATTRIBUTE_LINE = re.compile(r"@[\w.]+(?:\(.*\))?")
LEADING_ATTRIBUTES = re.compile(r"^(?:@[\w.]+(?:\([^()]*\))?\s+)*")
MODIFIERS = re.compile(
    r"^(?:(?:public|private|fileprivate|internal|open|final|static|nonisolated|override|lazy|weak|"
    r"unowned|mutating|nonmutating|convenience|required|dynamic|indirect|package)(?:\([a-z]+\))?\s+)*"
)
WRAPPERS = {
    "State": "States",
    "FocusState": "States",
    "AppStorage": "States",
    "SceneStorage": "States",
    "Namespace": "States",
    "ScaledMetric": "States",
    "Environment": "Environments",
    "Bindable": "Bindables",
    "Binding": "Bindings",
    "Test": "Tests",
}


def split_words(name):
    return re.sub(r"(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])", " ", name).strip()


def category(code):
    wrapper = re.match(r"@(\w+)", code)

    if wrapper and wrapper.group(1) in WRAPPERS:
        return WRAPPERS[wrapper.group(1)]

    code = LEADING_ATTRIBUTES.sub("", code)
    is_private = re.match(r"(?:\w+(?:\([a-z]+\))?\s+)*?(private|fileprivate)\b", code) is not None
    keyword = MODIFIERS.sub("", code)

    if keyword.startswith("case "):
        return "Cases"

    if re.match(r"var body\b", keyword):
        return "Body"

    if re.match(r"init\b|init[?!<(]", keyword):
        return "Initializer"

    if keyword.startswith("deinit"):
        return "Deinitializer"

    if re.match(r"class\s+(?:func|var|let|subscript)\b", keyword):
        keyword = keyword[len("class"):].lstrip()

    if re.match(r"(?:let|var)\b", keyword):
        return "Private Properties" if is_private else "Public Properties"

    if re.match(r"(?:func|subscript)\b", keyword):
        return "Private Methods" if is_private else "Public Methods"

    if re.match(r"(?:struct|enum|class|actor|typealias|protocol)\b", keyword):
        return "Nested Types"

    return None


def first_member(lines, body_start):
    attributes = []

    for line in lines[body_start:]:
        stripped = line.strip()

        if stripped == "" or stripped.startswith(("//", "/*", "*")):
            continue

        if ATTRIBUTE_LINE.fullmatch(stripped):
            attributes.append(stripped)
            continue

        return " ".join(attributes + [stripped])

    return None


def mark_name(path, lines, decl_index, body_start):
    decl_text = " ".join(lines[decl_index:body_start])
    decl = DECL.match(decl_text)
    kind, name = decl.group(1), decl.group(2)
    base = os.path.basename(path)[: -len(".swift")]

    if kind == "extension":
        conformance = re.search(
            r"extension\s+[\w.]+(?:<[^>]*>)?\s*:\s*([^{]+?)\s*(?:where\b[^{]*)?\{", decl_text
        )

        if conformance:
            return " & ".join(p.strip().split("<")[0] for p in conformance.group(1).split(","))

        if "+" in base and base.split("+")[0] == name.split(".")[-1]:
            feature = base.split("+")[-1]
            return split_words(re.sub(r"(?:Part|Group)\d+$", "", feature) or feature)

    code = first_member(lines, body_start)
    return (category(code) if code else None) or split_words(name.split(".")[-1])


def fix_file(path, reported_lines):
    with open(path, encoding="utf-8") as handle:
        lines = handle.read().split("\n")

    # Bottom-up so insertions do not shift the lines still to be processed.
    for reported in sorted(reported_lines, reverse=True):
        decl_index = reported - 1
        brace_index = decl_index

        while brace_index < len(lines) and not lines[brace_index].rstrip().endswith("{"):
            brace_index += 1

        if brace_index >= len(lines):
            continue

        body_start = brace_index + 1
        indent = re.match(r"^(\s*)", lines[decl_index]).group(1) + "    "

        if lines[body_start].strip().startswith("// MARK: - "):
            lines.insert(body_start, "")
            continue

        name = mark_name(path, lines, decl_index, body_start)

        while body_start < len(lines) and lines[body_start].strip() == "":
            del lines[body_start]

        lines[body_start:body_start] = ["", f"{indent}// MARK: - {name}", ""]
        print(f"{path}:{reported}: // MARK: - {name}")

    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))


def main(paths):
    if not paths:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2

    result = subprocess.run(
        ["swiftlint", "lint", "--quiet", "--no-cache", "--config", os.path.join(ROOT, ".swiftlint.yml"),
         "--reporter", "json", *paths],
        capture_output=True,
        text=True,
    )
    violations = defaultdict(set)

    for violation in json.loads(result.stdout or "[]"):
        if violation.get("rule_id") == "required_type_mark":
            violations[violation["file"]].add(violation["line"])

    for path, reported_lines in sorted(violations.items()):
        fix_file(path, reported_lines)

    total = sum(len(lines) for lines in violations.values())
    print(f"Drafted {total} MARK sections in {len(violations)} files; review the names before committing.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
