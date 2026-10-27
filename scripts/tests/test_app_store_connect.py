import importlib.machinery
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

loader = importlib.machinery.SourceFileLoader("app_store_connect", str(Path(__file__).resolve().parents[1] / "app-store-connect"))
spec = importlib.util.spec_from_loader(loader.name, loader)
asc = importlib.util.module_from_spec(spec)
loader.exec_module(asc)


class ScreenshotProcessingTests(unittest.TestCase):
    def test_ready_placements_need_no_further_processing(self):
        for state in ("ACTIVE", "PARENT_PREPARE_FOR_SUBMISSION", "PARENT_READY_FOR_REVIEW",
                      "PARENT_WAITING_FOR_REVIEW", "PARENT_IN_REVIEW", "PARENT_APPROVED"):
            with self.subTest(state=state), patch.object(asc, "api", return_value={"attributes": {"state": state}}), \
                 patch.object(asc.time, "sleep", side_effect=AssertionError("A ready placement must not wait")):
                asc.wait_for_screenshots(["screenshot"])

    def test_unknown_and_processing_states_wait_until_the_deadline(self):
        for state in ("ASSET_PROCESSING", "PENDING", "UPLOAD_COMPLETE", "PARENT_FUTURE_STATE"):
            with self.subTest(state=state), patch.object(asc, "api", return_value={"attributes": {"state": state}}), \
                 patch.object(asc, "DEADLINE", 1), patch.object(asc.time, "monotonic", return_value=2):
                with self.assertRaisesRegex(SystemExit, f"40 minutes.*screenshot.*{state}"):
                    asc.wait_for_screenshots(["screenshot"])

    def test_pending_placements_are_polled_until_every_screenshot_is_ready(self):
        with patch.object(asc, "api", side_effect=[
            {"attributes": {"state": "ACTIVE"}}, {"attributes": {"state": "PENDING"}},
            {"attributes": {"state": "ACTIVE"}}, {"attributes": {"state": "ACTIVE"}},
        ]), patch.object(asc, "DEADLINE", 1), patch.object(asc.time, "monotonic", return_value=0), \
             patch.object(asc.time, "sleep") as sleep:
            asc.wait_for_screenshots(["ipad", "iphone"])
            sleep.assert_called_once_with(20)

    def test_failed_processing_reports_the_apple_failure(self):
        with patch.object(asc, "api", return_value={"attributes": {"state": "FAILED", "stateDetails": "Invalid image"}}):
            with self.assertRaisesRegex(SystemExit, "Invalid image"):
                asc.wait_for_screenshots(["screenshot"])


class BuildIdentityTests(unittest.TestCase):
    def test_pending_uploads_count_toward_the_next_global_build(self):
        with patch.object(asc, "api", side_effect=[
            [{"attributes": {"version": "10"}}],
            [{"attributes": {"cfBundleVersion": "12"}}],
        ]):
            self.assertEqual(13, asc.next_build_number("app"))

    def test_a_dotted_pending_upload_sets_the_next_global_build(self):
        with patch.object(asc, "api", side_effect=[
            [{"attributes": {"version": "30"}}],
            [{"attributes": {"cfBundleVersion": "42.9.1"}}],
        ]):
            self.assertEqual(43, asc.next_build_number("app"))

    def test_unrecognized_build_versions_stop_allocation(self):
        for version in ("", "1.2.3.4", "1.beta", "１"):
            with self.subTest(version=version), patch.object(asc, "api", side_effect=[
                [{"attributes": {"version": version}}], [],
            ]):
                with self.assertRaisesRegex(SystemExit, "CFBundleVersion"):
                    asc.next_build_number("app")

    def test_acceptance_filters_the_exact_uploaded_build(self):
        with patch.object(asc, "api", return_value=[]) as api:
            self.assertIsNone(asc.processed_build("app", "1.3.2", "11"))
            self.assertEqual("11", api.call_args.kwargs["filter[version]"])
            self.assertEqual("1.3.2", api.call_args.kwargs["filter[preReleaseVersion.version]"])

    def test_all_pages_are_read_before_selecting_a_build_number(self):
        pages = [
            {"data": [{"id": "first"}], "links": {"next": asc.API + "builds?cursor=next"}},
            {"data": [{"id": "last"}], "links": {"next": None}},
        ]
        with patch.object(asc, "token", return_value="fixture"), patch.object(asc, "send", side_effect=[json.dumps(p).encode() for p in pages]):
            self.assertEqual([{"id": "first"}, {"id": "last"}], asc.api("GET", "builds"))


class UploadFenceTests(unittest.TestCase):
    def test_a_build_already_uploaded_for_the_version_is_reused(self):
        with patch.object(asc, "uploaded_build_numbers", return_value=["9", "12"]), patch.object(asc, "next_build_number") as reserve:
            self.assertEqual(("12", True), asc.reserve_build("app", "1.3.2", fenced=False))
            reserve.assert_not_called()

    def test_a_dotted_build_is_reused_with_its_exact_apple_version(self):
        with patch.object(asc, "uploaded_build_numbers", return_value=["9", "12.2", "12.7.2"]), \
             patch.object(asc, "next_build_number") as reserve:
            self.assertEqual(("12.7.2", True), asc.reserve_build("app", "1.3.2", fenced=True))
            reserve.assert_not_called()

    def test_a_first_attempt_without_an_upload_reserves_the_next_number(self):
        with patch.object(asc, "uploaded_build_numbers", return_value=[]), patch.object(asc, "next_build_number", return_value=13), \
             patch.object(asc.time, "sleep") as sleep:
            self.assertEqual((13, False), asc.reserve_build("app", "1.3.2", fenced=False))
            sleep.assert_not_called()

    def test_a_fenced_rerun_waits_for_the_build_and_never_reserves_a_second_number(self):
        with patch.object(asc, "uploaded_build_numbers", side_effect=[[], [], ["12"]]), patch.object(asc, "next_build_number") as reserve, \
             patch.object(asc.time, "sleep"):
            self.assertEqual(("12", True), asc.reserve_build("app", "1.3.2", fenced=True))
            reserve.assert_not_called()

    def test_a_fenced_rerun_fails_when_no_build_appears(self):
        with patch.object(asc, "uploaded_build_numbers", return_value=[]), patch.object(asc, "next_build_number") as reserve, \
             patch.object(asc.time, "sleep"), patch.object(asc.time, "monotonic", side_effect=[0, 1, 1000]):
            with self.assertRaisesRegex(SystemExit, "do not upload again"):
                asc.reserve_build("app", "1.3.2", fenced=True)
            reserve.assert_not_called()


class UploadCleanupTests(unittest.TestCase):
    def test_a_failed_transfer_reclaims_its_reserved_image(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "display").mkdir()
            (root / "display/01.png").write_bytes(b"fixture image")
            reservation = {"id": "reserved", "attributes": {"uploadOperations": [
                {"url": "https://example.com/upload", "offset": 0, "length": 13, "method": "PUT", "requestHeaders": []}
            ]}}
            with patch.object(asc, "draft_version", return_value=("version", False)), \
                 patch.object(asc, "api", side_effect=[{"id": "library"}, reservation]), \
                 patch.object(asc, "send", side_effect=asc.RequestFailed("transfer failed")), \
                 patch.object(asc, "delete_unplaced") as cleanup:
                with self.assertRaisesRegex(asc.RequestFailed, "transfer failed"):
                    asc.app_store("app", "1.3.2", "11", root, "notes")
                cleanup.assert_called_once_with(["reserved"])
