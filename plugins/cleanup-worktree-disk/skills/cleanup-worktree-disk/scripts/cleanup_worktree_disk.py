#!/usr/bin/env python3
"""Implementation for the cleanup-worktree-disk command wrappers."""

from __future__ import annotations

import argparse
import dataclasses
import fnmatch
import getpass
import json
import os
import pathlib
import platform
import shlex
import shutil
import subprocess
import sys
import time
import typing


@dataclasses.dataclass
class Config:
    repos: list[str]
    bazel_root: pathlib.Path
    fresh_hours: int
    protect: list[str]
    extras: dict[str, str]
    config_path: pathlib.Path


def run(args: list[str], *, cwd: str | None = None, check: bool = True) -> str:
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True, check=False)
    if check and result.returncode:
        message = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(message or f"command failed: {shlex.join(args)}")
    return result.stdout.strip()


def load_config() -> Config:
    config_path = pathlib.Path(os.environ.get("XDG_CONFIG_HOME", pathlib.Path.home() / ".config")) / "cleanup-worktree-disk" / "config"
    values: dict[str, str] = {}
    extras: dict[str, str] = {}
    if config_path.exists():
        for line in config_path.read_text().splitlines():
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                raise ValueError(f"invalid config line: {line}")
            key, value = line.split("=", 1)
            if key.startswith("extra.") and len(key) > 6:
                extras[key[6:]] = value
            elif key in {"repos", "bazel_output_root", "protect", "fresh_hours"}:
                values[key] = value
            else:
                raise ValueError(f"Unknown config key: {key}")
    fresh = values.get("fresh_hours", "24")
    if not fresh.isdigit():
        raise ValueError("fresh_hours must be a non-negative integer")
    if values.get("bazel_output_root"):
        bazel_root = pathlib.Path(values["bazel_output_root"])
    elif os.environ.get("CLEANUP_WORKTREE_BAZEL_ROOT"):
        bazel_root = pathlib.Path(os.environ["CLEANUP_WORKTREE_BAZEL_ROOT"])
    elif platform.system() == "Darwin":
        bazel_root = pathlib.Path("/private/var/tmp") / f"_bazel_{getpass.getuser()}"
    elif platform.system() == "Linux":
        cache = pathlib.Path(os.environ.get("XDG_CACHE_HOME", pathlib.Path.home() / ".cache"))
        bazel_root = cache / "bazel" / f"_bazel_{getpass.getuser()}"
    else:
        raise ValueError(f"Unsupported operating system: {platform.system()}")
    repos = values.get("repos", "").split(":") if values.get("repos") else [run(["git", "rev-parse", "--show-toplevel"])]
    return Config(repos, bazel_root, int(fresh), values.get("protect", "").split(":") if values.get("protect") else [], extras, config_path)


def is_protected(path: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatchcase(path, pattern) for pattern in patterns if pattern)


def file_size(path: str) -> int:
    try:
        return sum(p.stat().st_size for p in pathlib.Path(path).rglob("*") if p.is_file()) // 1024
    except OSError:
        return 0


def disk_free_kb() -> int:
    volume = "/System/Volumes/Data" if platform.system() == "Darwin" else "/"
    return shutil.disk_usage(volume).free // 1024


def inventory(config: Config) -> list[dict[str, typing.Any]]:
    worktrees: list[dict[str, typing.Any]] = []
    for repo in config.repos:
        if not pathlib.Path(repo).is_dir():
            raise RuntimeError(f"Configured repo is not a git checkout: {repo}")
        root = run(["git", "-C", repo, "rev-parse", "--show-toplevel"])
        if run(["git", "-C", root, "remote", "get-url", "origin"], check=False):
            try:
                run(["git", "-C", root, "fetch", "origin", "-q"])
            except RuntimeError as err:
                raise RuntimeError(f"Could not refresh origin refs for {root}") from err
        raw = run(["git", "-C", root, "worktree", "list", "--porcelain"])
        paths = [line[9:] for line in raw.splitlines() if line.startswith("worktree ")]
        for path in paths:
            details = run(["git", "-C", root, "worktree", "list", "--porcelain"])
            chunks = details.split("\n\n")
            entry = next((chunk for chunk in chunks if chunk.startswith(f"worktree {path}\n")), "")
            locked = any(line.startswith("locked") for line in entry.splitlines())
            branch = run(["git", "-C", path, "symbolic-ref", "--quiet", "--short", "HEAD"], check=False) or "DETACHED"
            remote, state, unpushed = "", "NO-PR", "?"
            if branch != "DETACHED":
                remote = run(["git", "-C", path, "rev-parse", "--abbrev-ref", f"{branch}@{{upstream}}"], check=False)
                if remote:
                    unpushed = run(["git", "-C", path, "rev-list", "--count", f"{remote}..HEAD"], check=False) or "?"
                    try:
                        pr_json = run(["gh", "pr", "list", "--head", remote.split("/", 1)[-1], "--state", "all", "--json", "state"])
                    except (RuntimeError, FileNotFoundError) as err:
                        raise RuntimeError(f"gh failed to query PR state for {path}") from err
                    prs = json.loads(pr_json)
                    state = prs[0].get("state", "NO-PR") if prs else "NO-PR"
                else:
                    unpushed = "NO-REMOTE"
            dirty = len(run(["git", "-C", path, "status", "--porcelain"], check=False).splitlines())
            worktrees.append({"kind": "worktree", "path": path, "repo": root, "primary": path == root, "branch": branch, "remote": remote, "state": state, "unpushed": unpushed, "locked": locked, "dirty": dirty, "size_kb": file_size(path)})

    bases: list[dict[str, typing.Any]] = []
    if config.bazel_root.is_dir():
        for path in config.bazel_root.iterdir():
            if not path.is_dir() or path.name in {"install", "cache"}:
                continue
            marker_file = path / "DO_NOT_BUILD_HERE"
            try:
                workspace = marker_file.read_text().strip()
            except OSError:
                workspace = ""
            marker = "UNMAPPED" if not workspace else ("LIVE" if pathlib.Path(workspace).is_dir() else "ORPHAN")
            age = max(0, int((time.time() - path.stat().st_mtime) / 3600))
            bases.append({"kind": "output_base", "path": str(path), "workspace": workspace, "marker": marker, "age_hours": age, "size_kb": file_size(str(path)), "symlink": path.is_symlink()})
    return worktrees + bases


def make_plan(items: list[dict[str, typing.Any]], config: Config, before: int) -> dict[str, typing.Any]:
    worktrees = []
    for wt in (item for item in items if item["kind"] == "worktree"):
        if wt["primary"]:
            decision = ("keep", "primary checkout")
        elif wt["locked"]:
            decision = ("keep", "worktree is locked")
        elif wt["unpushed"] != "0":
            decision = ("ask", "un-pushed or unknown commits require review")
        elif wt["state"] == "OPEN":
            decision = ("keep", "pull request is open")
        elif wt["state"] == "MERGED" and wt["dirty"] == 0:
            decision = ("remove", "pull request is merged and worktree is clean and pushed")
        else:
            decision = ("ask", "pull request state is not safely removable")
        worktrees.append({**wt, "class": decision[0], "reasons": [decision[1]], "id": f"worktree:{wt['path']}"})
    branches = [{"kind": "branch", "path": wt["branch"], "repo": wt["repo"], "size_kb": 0, "class": "remove", "reasons": ["branch belongs to removable worktree"], "worktree_id": wt["id"], "id": f"branch:{wt['repo']}:{wt['branch']}"} for wt in worktrees if wt["class"] == "remove" and wt["branch"] != "DETACHED"]
    bases = []
    for base in (item for item in items if item["kind"] == "output_base"):
        owner = next((wt for wt in worktrees if wt["path"] == base["workspace"]), {})
        if base["symlink"]:
            decision = ("keep", "output base is a symbolic link")
        elif base["marker"] == "ORPHAN":
            decision = ("remove", "workspace no longer exists")
        elif base["marker"] == "UNMAPPED" and base["age_hours"] < config.fresh_hours:
            decision = ("keep", "unmapped output base is fresh")
        elif base["marker"] == "UNMAPPED":
            decision = ("ask", "unmapped output base is old")
        elif owner.get("class") == "remove":
            decision = ("remove", "belongs to removable worktree")
        else:
            decision = ("keep", "belongs to a live worktree")
        bases.append({**base, "repo": owner.get("repo", ""), "class": decision[0], "reasons": [decision[1]], "id": f"output_base:{base['path']}"})
    result = {"items": worktrees + branches + bases, "extras": [], "disk_before_kb": before}
    for name, command in config.extras.items():
        result["extras"].append({"id": f"extra:{name}", "kind": "extra", "path": name, "size_kb": None, "class": "ask", "reasons": ["configured extra command; estimate unavailable"], "command": command})
    for item in result["items"]:
        if is_protected(item["path"], config.protect):
            item["class"] = "keep"
            item["reasons"].append("matched protect pattern or protected owner")
            for child in result["items"]:
                if child.get("worktree_id") == item["id"] or (child["kind"] == "output_base" and child.get("workspace") == item["path"]):
                    child["class"] = "keep"
                    child["reasons"].append("matched protect pattern or protected owner")
    return result


def print_plan(plan: dict[str, typing.Any], config: Config, had_config: bool) -> None:
    print(f"{'KIND':<12} {'CLASS':<8} {'SIZE':>10}  {'PATH':<48} REASONS", file=sys.stderr)
    for item in [*plan["items"], *plan["extras"]]:
        size = "n/a" if item["size_kb"] is None else f"{item['size_kb']} KB"
        print(f"{item['kind']:<12} {item['class']:<8} {size:>10}  {item['path']:<48} {'; '.join(item['reasons'])}", file=sys.stderr)
    reclaimed = sum(item["size_kb"] for item in plan["items"] if item["class"] == "remove")
    print(f"Estimated reclaim: {reclaimed} KB", file=sys.stderr)
    if not had_config:
        print("\nNo config found. Suggested config (save only after user approval with --write-config):", file=sys.stderr)
        print(f"repos={':'.join(config.repos)}", file=sys.stderr)
        if config.bazel_root.is_dir():
            print(f"bazel_output_root={config.bazel_root}", file=sys.stderr)
        print(f"protect=\nfresh_hours={config.fresh_hours}", file=sys.stderr)


def plan_command(args: argparse.Namespace) -> int:
    config = load_config()
    had_config = config.config_path.exists()
    if args.write_config:
        if had_config:
            raise RuntimeError("Config already exists; refusing to overwrite it")
        config.config_path.parent.mkdir(parents=True, exist_ok=True)
        lines = [f"repos={run(['git', 'rev-parse', '--show-toplevel'])}"]
        if config.bazel_root.is_dir():
            lines.append(f"bazel_output_root={config.bazel_root}")
        lines.extend(["protect=", f"fresh_hours={config.fresh_hours}"])
        config.config_path.write_text("\n".join(lines) + "\n")
        print(f"Saved config to {config.config_path}")
        return 0
    plan = make_plan(inventory(config), config, disk_free_kb())
    print_plan(plan, config, had_config)
    print(json.dumps(plan, separators=(",", ":")))
    return 0


def git_worktree_exists(repo: str, path: str) -> bool:
    output = run(["git", "-C", repo, "worktree", "list", "--porcelain"], check=False)
    return any(line == f"worktree {path}" for line in output.splitlines())


def report(results: list[dict[str, str]], item_id: str, status: str, reason: str) -> None:
    results.append({"id": item_id, "status": status, "reason": reason})
    print(f"{item_id}: {status} ({reason})")


def apply_item(item: dict[str, typing.Any], plan: dict[str, typing.Any], selected: list[str], config: Config, repo_root: str) -> tuple[str, str]:
    item_id, path, kind = item["id"], item["path"], item["kind"]
    repo = item.get("repo") or repo_root
    if item["class"] == "keep":
        return "skipped", "plan class is keep"
    if item["class"] not in {"remove", "ask"}:
        return "skipped", f"unknown plan class: {item['class']}"
    if is_protected(path, config.protect):
        return "skipped", "matches configured protect pattern"
    if kind == "worktree":
        if path == repo_root:
            return "skipped", "primary checkout"
        if not git_worktree_exists(repo, path):
            return "skipped", "worktree no longer exists"
        details = run(["git", "-C", repo, "worktree", "list", "--porcelain"])
        entry = next((part for part in details.split("\n\n") if part.startswith(f"worktree {path}\n")), "")
        if any(line.startswith("locked") for line in entry.splitlines()):
            return "skipped", "worktree is now locked"
        if run(["git", "-C", path, "status", "--porcelain"]).splitlines():
            return "skipped", "worktree is now dirty"
        branch = run(["git", "-C", path, "symbolic-ref", "--quiet", "--short", "HEAD"], check=False) or "DETACHED"
        remote = run(["git", "-C", path, "rev-parse", "--abbrev-ref", f"{branch}@{{upstream}}"], check=False) if branch != "DETACHED" else ""
        if branch == "DETACHED" or not remote:
            return "skipped", "detached or no upstream"
        unpushed = run(["git", "-C", path, "rev-list", "--count", f"{remote}..HEAD"], check=False) or "?"
        if unpushed != "0":
            return "skipped", "worktree has unpushed or unknown commits"
        try:
            prs = json.loads(run(["gh", "pr", "list", "--head", remote.split("/", 1)[-1], "--state", "all", "--json", "state"]))
        except (RuntimeError, FileNotFoundError, json.JSONDecodeError):
            prs = []
        state = prs[0].get("state", "NO-PR") if prs else "NO-PR"
        if state != "MERGED":
            return "skipped", f"pull request state is {state}"
        if run(["git", "-C", repo, "worktree", "remove", "--force", path], check=False) == "" and not pathlib.Path(path).exists():
            run(["git", "-C", repo, "worktree", "prune"], check=False)
            return "removed", "merged, clean worktree removed"
        return "failed", "git worktree remove failed"
    if kind == "branch":
        check = subprocess.run(["git", "check-ref-format", "--branch", path], capture_output=True, text=True)
        if check.returncode:
            return "skipped", "invalid branch name in plan"
        worktree_id = item.get("worktree_id", "")
        if not worktree_id or worktree_id not in selected:
            return "skipped", "select the associated worktree in the same apply run"
        wt = next((candidate for candidate in plan["items"] if candidate["id"] == worktree_id), None)
        if wt is None:
            return "skipped", "associated worktree is missing from plan"
        if git_worktree_exists(repo, wt["path"]):
            return "skipped", "associated worktree was not removed"
        if f"branch refs/heads/{path}" in run(["git", "-C", repo, "worktree", "list", "--porcelain"]):
            return "skipped", "branch is still checked out"
        exists = subprocess.run(["git", "-C", repo, "show-ref", "--verify", "--quiet", f"refs/heads/{path}"]).returncode == 0
        if not exists:
            return "skipped", "branch no longer exists"
        if subprocess.run(["git", "-C", repo, "branch", "-D", "--", path]).returncode == 0:
            return "removed", "local branch deleted"
        return "failed", "branch deletion failed"
    if kind == "output_base":
        try:
            path_obj = pathlib.Path(path)
            root_real, base_real = config.bazel_root.resolve(), path_obj.resolve()
            if base_real == root_real:
                return "skipped", "path is outside configured Bazel root"
            base_real.relative_to(root_real)
        except (OSError, ValueError):
            return "skipped", "path is outside configured Bazel root"
        if not path_obj.is_dir():
            return "skipped", "output base no longer exists"
        if path_obj.is_symlink():
            return "skipped", "output base is a symbolic link"
        marker = path_obj / "DO_NOT_BUILD_HERE"
        if marker.exists() and not os.access(marker, os.R_OK):
            return "skipped", "cannot read DO_NOT_BUILD_HERE"
        try:
            workspace = marker.read_text().strip()
        except OSError:
            workspace = ""
        if not workspace:
            age = max(0, int((time.time() - path_obj.stat().st_mtime) / 3600))
            if age < config.fresh_hours:
                return "skipped", "unmapped output base is fresh"
        elif pathlib.Path(workspace).is_dir():
            wt = next((candidate for candidate in plan["items"] if candidate["kind"] == "worktree" and candidate["path"] == workspace), None)
            if wt is None or wt["id"] not in selected:
                return "skipped", "select the associated worktree in the same apply run"
            if git_worktree_exists(wt["repo"], workspace):
                return "skipped", "associated worktree was not removed"
            return "skipped", "output base workspace is now live"
        try:
            for directory, subdirectories, files in os.walk(path_obj, topdown=False, followlinks=False):
                for name in files:
                    child = pathlib.Path(directory, name)
                    if not child.is_symlink():
                        child.chmod(child.stat().st_mode | 0o200)
                for name in subdirectories:
                    child = pathlib.Path(directory, name)
                    if not child.is_symlink():
                        child.chmod(child.stat().st_mode | 0o200)
                pathlib.Path(directory).chmod(pathlib.Path(directory).stat().st_mode | 0o200)
            path_obj.chmod(path_obj.stat().st_mode | 0o200)
            shutil.rmtree(path_obj)
            return "removed", "output base deleted"
        except OSError:
            return "failed", "could not remove output base"
    if kind == "extra":
        if subprocess.run(["bash", "-c", item["command"]]).returncode == 0:
            return "removed", "extra command completed"
        return "failed", "extra command failed"
    return "failed", f"unknown item kind: {kind}"


def apply_command(plan_path: str, selected: list[str]) -> int:
    config = load_config()
    plan = json.loads(pathlib.Path(plan_path).read_text())
    if not isinstance(plan.get("items"), list):
        raise ValueError("plan items must be an array")
    repo_root = run(["git", "rev-parse", "--show-toplevel"])
    items = {item["id"]: item for item in [*plan["items"], *plan.get("extras", [])]}
    results: list[dict[str, str]] = []
    for item_id in selected:
        item = items.get(item_id)
        if item is None:
            report(results, item_id, "failed", "not present in plan")
            continue
        status, reason = apply_item(item, plan, selected, config, repo_root)
        report(results, item_id, status, reason)
    result_json = json.dumps(results, separators=(",", ":"))
    result_file = os.environ.get("RESULT_FILE")
    if result_file:
        pathlib.Path(result_file).write_text(result_json + "\n")
    else:
        print(result_json)
    return 1 if any(result["status"] == "failed" for result in results) else 0


def verify_command(plan_path: str) -> int:
    plan = json.loads(pathlib.Path(plan_path).read_text())
    if not isinstance(plan.get("items"), list):
        raise ValueError("plan items must be an array")
    print(f"Disk free (KB): before={plan.get('disk_before_kb', 'unknown')} after={disk_free_kb()}")
    print("Worktrees:")
    repos = sorted({item["repo"] for item in plan["items"] if item["kind"] == "worktree"})
    for repo in repos:
        print(run(["git", "-C", repo, "worktree", "list"]))
    leftovers = 0
    for item in plan["items"]:
        if item["class"] != "remove":
            continue
        path = item["path"]
        present = pathlib.Path(path).exists()
        if item["kind"] == "branch":
            present = subprocess.run(["git", "-C", item["repo"], "show-ref", "--verify", "--quiet", f"refs/heads/{path}"]).returncode == 0
        if present:
            print(f"LEFTOVER {item['kind']}: {path}")
            leftovers += 1
    print(f"Planned removal leftovers: {leftovers}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    plan_parser = subparsers.add_parser("plan")
    plan_parser.add_argument("--write-config", action="store_true")
    apply_parser = subparsers.add_parser("apply")
    apply_parser.add_argument("plan_file")
    apply_parser.add_argument("item_ids", nargs="+")
    verify_parser = subparsers.add_parser("verify")
    verify_parser.add_argument("plan_file")
    args = parser.parse_args(argv)
    try:
        if args.command == "plan":
            return plan_command(args)
        if args.command == "apply":
            return apply_command(args.plan_file, args.item_ids)
        return verify_command(args.plan_file)
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as err:
        print(str(err), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
