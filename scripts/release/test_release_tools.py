#!/usr/bin/env python3
"""Tests for release_tools.py. Run: python3 -m unittest discover -s scripts/release"""

import argparse
import json
import unittest
import xml.etree.ElementTree as ET

import release_tools as tools

NS = {"sparkle": tools.SPARKLE_NS}


def appcast_args(version="1.0.1", build=221, keep=10):
    return argparse.Namespace(
        version=version,
        build=build,
        url="https://downloads.example.com/CleanerXcode-%s-%d.zip" % (version, build),
        length=1234,
        signature="c2lnbmF0dXJl",
        minimum_system="26.0",
        keep=keep,
        pub_date="Mon, 09 Nov 2026 12:00:00 GMT",
    )


class NextVersionTests(unittest.TestCase):

    def test_the_first_release_of_a_new_line_uses_the_project_version(self):
        self.assertEqual(tools.next_version(["v0.6.0", "v0.7.0"], "1.0.0", "patch"), "1.0.0")
        self.assertEqual(tools.next_version(["v0.7.0"], "1.0.0", "minor"), "1.0.0")

    def test_later_releases_bump_the_latest_tag(self):
        self.assertEqual(tools.next_version(["v0.7.0", "v1.0.0"], "1.0.0", "patch"), "1.0.1")
        self.assertEqual(tools.next_version(["v1.0.3"], "1.0.0", "minor"), "1.1.0")
        self.assertEqual(tools.next_version(["v1.4.2"], "1.0.0", "major"), "2.0.0")

    def test_tags_are_compared_as_numbers_and_others_are_ignored(self):
        self.assertEqual(tools.next_version(["v1.0.9", "v1.0.10", "nightly"], "1.0.0", "patch"), "1.0.11")

    def test_no_tags_starts_from_the_project(self):
        self.assertEqual(tools.next_version([], "1.0.0", "patch"), "1.0.0")

    def test_unknown_bump_fails(self):
        with self.assertRaises(ValueError):
            tools.next_version(["v1.0.0"], "1.0.0", "huge")


class BuildNumberTests(unittest.TestCase):

    def test_the_build_follows_the_commits_and_never_goes_back(self):
        self.assertEqual(tools.build_number(220, 116), 220)
        self.assertEqual(tools.build_number(50, 116), 117)


class LabelTests(unittest.TestCase):

    def test_skip_wins_then_the_biggest_bump(self):
        self.assertEqual(tools.bump_from_labels(["release:major", "skip-release"]), "skip")
        self.assertEqual(tools.bump_from_labels(["release:minor", "release:major"]), "major")
        self.assertEqual(tools.bump_from_labels(["Release:Minor"]), "minor")
        self.assertEqual(tools.bump_from_labels(["docs", ""]), "patch")
        self.assertEqual(tools.bump_from_labels([]), "patch")


class PullRequestTests(unittest.TestCase):

    def test_only_a_pull_request_merged_into_main_counts(self):
        pulls = [
            {"number": 7, "merged_at": None, "base": {"ref": "main"}, "labels": [{"name": "skip-release"}]},
            {"number": 8, "merged_at": "2026-11-09T10:00:00Z", "base": {"ref": "develop"}, "labels": []},
            {"number": 9, "merged_at": "2026-11-09T11:00:00Z", "base": {"ref": "main"}, "labels": [{"name": "release:minor"}]},
        ]

        self.assertEqual(tools.merged_pull_request(pulls, "main"), (9, ["release:minor"]))

    def test_a_direct_push_has_no_pull_request(self):
        self.assertEqual(tools.merged_pull_request([], "main"), (None, []))

    def test_an_unexpected_answer_fails(self):
        with self.assertRaises(ValueError):
            tools.merged_pull_request({"message": "API rate limit exceeded"}, "main")


class ProjectSettingTests(unittest.TestCase):

    APP = "com.didisouzacosta.CleanerXcode"

    @staticmethod
    def configuration(bundle_id, version, build):
        return (
            "\t\tA /* Release */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {\n"
            "\t\t\t\tCURRENT_PROJECT_VERSION = %s;\n\t\t\t\tMARKETING_VERSION = %s;\n"
            "\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = %s;\n\t\t\t};\n\t\t\tname = Release;\n\t\t};\n"
        ) % (build, version, bundle_id)

    def test_reads_the_app_target_and_ignores_the_test_target(self):
        pbxproj = (
            self.configuration(self.APP, "1.0.0", "116")
            + self.configuration(self.APP, "1.0.0", "116")
            + self.configuration("didisouzacosta.CleanerXcodeTests", "1.0", "1")
        )

        self.assertEqual(tools.project_setting(pbxproj, "MARKETING_VERSION", self.APP), "1.0.0")
        self.assertEqual(tools.project_setting(pbxproj, "CURRENT_PROJECT_VERSION", self.APP), "116")

    def test_different_values_or_none_fail(self):
        mixed = self.configuration(self.APP, "1.0.0", "116") + self.configuration(self.APP, "1.1.0", "116")

        with self.assertRaises(ValueError):
            tools.project_setting(mixed, "MARKETING_VERSION", self.APP)
        with self.assertRaises(ValueError):
            tools.project_setting("", "MARKETING_VERSION", self.APP)


class AppcastTests(unittest.TestCase):

    def test_a_new_feed_has_the_signed_item(self):
        feed = tools.update_appcast(None, appcast_args(), "- Faster cleanup\n- <b>Fix</b>")
        item = ET.fromstring(feed).find("channel/item")

        self.assertEqual(item.find("sparkle:version", NS).text, "221")
        self.assertEqual(item.find("sparkle:shortVersionString", NS).text, "1.0.1")
        self.assertEqual(item.find("sparkle:minimumSystemVersion", NS).text, "26.0")
        enclosure = item.find("enclosure")
        self.assertEqual(enclosure.get("{%s}edSignature" % tools.SPARKLE_NS), "c2lnbmF0dXJl")
        self.assertEqual(enclosure.get("length"), "1234")
        self.assertIn("&lt;b&gt;Fix&lt;/b&gt;", item.find("description").text)

    def test_the_newest_item_comes_first_and_old_ones_are_trimmed(self):
        feed = None
        for build in range(200, 205):
            feed = tools.update_appcast(feed, appcast_args("1.0.%d" % (build - 200), build, keep=3), "")

        builds = [node.text for node in ET.fromstring(feed).findall("channel/item/sparkle:version", NS)]

        self.assertEqual(builds, ["204", "203", "202"])

    def test_publishing_the_same_build_again_replaces_it(self):
        feed = tools.update_appcast(None, appcast_args(), "first")
        feed = tools.update_appcast(feed, appcast_args(), "second")

        items = ET.fromstring(feed).findall("channel/item")

        self.assertEqual(len(items), 1)
        self.assertIn("second", items[0].find("description").text)

    def test_empty_notes_get_a_default_text(self):
        self.assertEqual(tools.notes_html(""), "<p>Bug fixes and improvements.</p>")


class VersionJSONTests(unittest.TestCase):

    def test_the_legacy_file_keeps_its_keys(self):
        data = json.loads(tools.version_json("1.0.1", 221, "https://downloads.example.com/x.dmg"))

        self.assertEqual(data, {"version": "1.0.1", "build": "221", "downloadURL": "https://downloads.example.com/x.dmg"})


if __name__ == "__main__":
    unittest.main()
