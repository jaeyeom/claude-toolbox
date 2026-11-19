import importlib.util
import pathlib
import sys
import tempfile
import unittest
from unittest import mock

script_path = pathlib.Path(__file__).resolve().parents[1] / "scripts" / "cleanup_worktree_disk.py"
spec = importlib.util.spec_from_file_location("cleanup_worktree_disk", script_path)
if spec is None or spec.loader is None:
    raise ImportError(f"cannot load {script_path}")
cleanup = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = cleanup
spec.loader.exec_module(cleanup)


class ConfigTests(unittest.TestCase):
    def test_loads_config_and_selected_extra_commands(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            config_dir = root / "config"
            config_file = config_dir / "cleanup-worktree-disk" / "config"
            config_file.parent.mkdir(parents=True)
            config_file.write_text(
                f"repos={root}\nbazel_output_root={root / 'bazel'}\nprotect={root}/safe*\n"
                "fresh_hours=8\nextra.marker=echo selected\n"
            )
            with mock.patch.dict(
                cleanup.os.environ,
                {
                    "XDG_CONFIG_HOME": str(config_dir),
                    "USER": "fixture",
                    "CLEANUP_WORKTREE_BAZEL_ROOT": str(root / "environment-bazel"),
                },
            ):
                config = cleanup.load_config()
            self.assertEqual(config.repos, [str(root)])
            self.assertEqual(config.bazel_root, root / "bazel")
            self.assertEqual(config.fresh_hours, 8)
            self.assertEqual(config.protect, [f"{root}/safe*"])
            self.assertEqual(config.extras, {"marker": "echo selected"})

    def test_rejects_unknown_config_keys(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            config_dir = pathlib.Path(temporary)
            config_file = config_dir / "cleanup-worktree-disk" / "config"
            config_file.parent.mkdir(parents=True)
            config_file.write_text("unknown=value\n")
            with mock.patch.dict(cleanup.os.environ, {"XDG_CONFIG_HOME": str(config_dir)}):
                with self.assertRaisesRegex(ValueError, "Unknown config key: unknown"):
                    cleanup.load_config()


class PlanTests(unittest.TestCase):
    def test_classifies_worktrees_bases_extras_and_protected_paths(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            config = cleanup.Config([str(root)], root / "bazel", 24, [f"{root}/protected*"], {"marker": "true"}, root / "config")
            items = [
                {"kind": "worktree", "path": str(root / "main"), "repo": str(root / "main"), "primary": True, "branch": "main", "remote": "", "state": "NO-PR", "unpushed": "NO-REMOTE", "locked": False, "dirty": 0, "size_kb": 1},
                {"kind": "worktree", "path": str(root / "merged"), "repo": str(root / "main"), "primary": False, "branch": "merged", "remote": "origin/merged", "state": "MERGED", "unpushed": "0", "locked": False, "dirty": 0, "size_kb": 4},
                {"kind": "worktree", "path": str(root / "protected-wt"), "repo": str(root / "main"), "primary": False, "branch": "protected", "remote": "origin/protected", "state": "MERGED", "unpushed": "0", "locked": False, "dirty": 0, "size_kb": 4},
                {"kind": "output_base", "path": str(root / "orphan"), "workspace": "", "marker": "ORPHAN", "age_hours": 40, "size_kb": 9, "symlink": False},
            ]
            plan = cleanup.make_plan(items, config, 100)
        classes = {item["path"]: item["class"] for item in plan["items"]}
        self.assertEqual(classes[str(root / "main")], "keep")
        self.assertEqual(classes[str(root / "merged")], "remove")
        self.assertEqual(classes[str(root / "protected-wt")], "keep")
        self.assertEqual(classes[str(root / "orphan")], "remove")
        self.assertEqual(plan["extras"][0]["id"], "extra:marker")
        self.assertEqual(plan["items"][1]["id"], f"worktree:{root / 'merged'}")

    def test_apply_cannot_remove_the_bazel_root_itself(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            config = cleanup.Config([temporary], root, 24, [], {}, root / "config")
            item = {"id": f"output_base:{root}", "kind": "output_base", "class": "remove", "path": str(root)}
            status, reason = cleanup.apply_item(item, {"items": []}, [], config, temporary)
        self.assertEqual(status, "skipped")
        self.assertEqual(reason, "path is outside configured Bazel root")


if __name__ == "__main__":
    unittest.main()
