#!/usr/bin/env python3
"""CI guard script for theMQL.

Checks:
1. All TOML files parse successfully.
2. Every crate in specs/*.toml has a matching workspace member.
3. Every workspace member crate has a matching spec file.
4. Crate names in Cargo.toml match the directory name.
5. The auth path cannot silently make the ignored jsonwebtoken advisory
   GHSA-h395-gr6q-cpjc reachable.
6. The unblock conditions recorded in deny.toml's advisory ignores are still
   unmet (delegated to scripts/check-advisory-rationales.sh).

Checks 5 and 6 exist because a waiver written in a config file cannot notice
when its own justification stops being true. Both are static analysis over
source and lock data, so they run here rather than in a linked test binary:
`themql-desktop` pulls polars and tch, and linking its test binary is
expensive enough to be a real cost on a small builder.

Exit code 0 = all checks pass. Non-zero = failure.
"""

import pathlib
import re
import subprocess
import sys
import tomllib

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
SPECS_DIR = REPO_ROOT / "specs"
CRATES_DIR = REPO_ROOT / "crates"


def check_toml_parse() -> list[str]:
    """Check all TOML files parse."""
    errors = []
    for p in REPO_ROOT.rglob("*.toml"):
        if ".git" in p.parts or "target" in p.parts:
            continue
        try:
            tomllib.loads(p.read_text())
        except Exception as e:
            errors.append(f"  TOML parse error in {p.relative_to(REPO_ROOT)}: {e}")
    return errors


def check_crate_name_matches_dir() -> list[str]:
    """Check that crate names in Cargo.toml match directory names."""
    errors = []
    for cargo_toml in CRATES_DIR.glob("*/Cargo.toml"):
        data = tomllib.loads(cargo_toml.read_text())
        name = data.get("package", {}).get("name", "")
        dir_name = cargo_toml.parent.name
        if name != dir_name:
            errors.append(
                f"  Crate name mismatch: {cargo_toml.relative_to(REPO_ROOT)} "
                f"has name='{name}' but dir='{dir_name}'"
            )
    return errors


def check_spec_crate_names() -> list[str]:
    """Check that spec crate names match workspace members."""
    errors = []
    workspace_toml = tomllib.loads((REPO_ROOT / "Cargo.toml").read_text())
    members = workspace_toml.get("workspace", {}).get("members", [])
    member_names = set()
    for m in members:
        member_path = REPO_ROOT / m / "Cargo.toml"
        if member_path.exists():
            data = tomllib.loads(member_path.read_text())
            member_names.add(data.get("package", {}).get("name", ""))

    spec_crate_names = set()
    for spec in SPECS_DIR.glob("*.toml"):
        data = tomllib.loads(spec.read_text())
        crate_name = data.get("subsystem", {}).get("crate", "")
        if crate_name:
            spec_crate_names.add(crate_name)

    for name in spec_crate_names - member_names:
        errors.append(
            f"  Spec references crate '{name}' but no workspace member found"
        )
    for name in member_names - spec_crate_names:
        errors.append(
            f"  Workspace member '{name}' has no matching spec file"
        )

    return errors


def check_jsonwebtoken_advisory_still_unreachable() -> list[str]:
    """The ignored jsonwebtoken advisory must stay unreachable.

    `deny.toml` ignores GHSA-h395-gr6q-cpjc (jsonwebtoken type confusion in
    `nbf`/`exp` validation -> authorization bypass) because this workspace
    never issues or validates a JWT. That justification is load-bearing: if a
    JWT plugin is ever registered, an ignored authorization bypass becomes
    reachable and the ignore silently becomes a lie.
    """
    errors: list[str] = []

    main_rs = CRATES_DIR / "themql-desktop" / "src" / "main.rs"
    if not main_rs.exists():
        return [f"  {main_rs.relative_to(REPO_ROOT)} not found; cannot audit auth wiring"]

    src = main_rs.read_text()

    # Isolate the BetterAuth builder chain so an unrelated mention of "jwt"
    # elsewhere in the file cannot satisfy or defeat the scan.
    idx = src.find("AuthBuilder::new")
    if idx == -1:
        return [
            "  The BetterAuth builder was not found in themql-desktop/src/main.rs. "
            "The auth wiring changed shape; re-audit GHSA-h395-gr6q-cpjc in deny.toml."
        ]
    region = src[idx : idx + 1200]

    jwt_markers = ("jwt", "Jwt", "JWT", "JsonWebToken", "jsonwebtoken")
    for marker in jwt_markers:
        if marker in region:
            errors.append(
                f"  The auth builder references '{marker}', which can issue or validate a "
                f"JWT. That makes the ignored advisory GHSA-h395-gr6q-cpjc (jsonwebtoken "
                f"type confusion -> authorization bypass) REACHABLE. Remove the plugin, or "
                f"bump better-auth to >= 1.0.0-alpha.3 (jsonwebtoken ^11, patched) and drop "
                f"the ignore from deny.toml."
            )
            break

    registrations = region.count(".plugin(")
    if registrations != 1:
        errors.append(
            f"  Expected exactly one registered plugin (email/password) on the auth "
            f"builder, found {registrations}. A new plugin may reach jsonwebtoken; "
            f"re-audit GHSA-h395-gr6q-cpjc in deny.toml before merging."
        )
    elif "EmailPasswordPlugin" not in region:
        errors.append(
            "  EmailPasswordPlugin is no longer the registered plugin; re-audit "
            "GHSA-h395-gr6q-cpjc in deny.toml."
        )

    # Auth must stay opt-in. If it defaults to on, the reachability argument
    # weakens from "opt-in" to "always on".
    if not re.search(r"enable_auth:\s*bool", src) or "default_value_t = false" not in src:
        errors.append(
            "  `enable_auth` no longer defaults to false. The jsonwebtoken advisory's "
            "reachability rationale in deny.toml assumes the auth path is opt-in."
        )

    # The ignore and this guard must agree in both directions.
    deny = (REPO_ROOT / "deny.toml").read_text()
    if "GHSA-h395-gr6q-cpjc" not in deny:
        errors.append(
            "  GHSA-h395-gr6q-cpjc is no longer ignored, but this reachability guard "
            "still exists. If the dependency was genuinely fixed, delete check 5; if "
            "the ignore was removed by mistake, `cargo deny check advisories` will fail."
        )

    lock = (REPO_ROOT / "Cargo.lock").read_text()
    m = re.search(r'name = "jsonwebtoken"\nversion = "(\d+)\.', lock)
    if m and int(m.group(1)) >= 10:
        errors.append(
            f"  jsonwebtoken major is {m.group(1)}, at or above the patched 10.3.0. "
            f"Remove GHSA-h395-gr6q-cpjc from deny.toml and delete check 5."
        )

    return errors


def check_advisory_unblock_conditions() -> list[str]:
    """Delegate to the advisory-rationale checker.

    A config comment cannot notice when its own unblock condition is met, so
    the condition is re-checked. An unreachable registry index reports SKIPPED
    rather than failing, because an unreachable index is not evidence that a
    waiver is still correct.
    """
    script = REPO_ROOT / "scripts" / "check-advisory-rationales.sh"
    if not script.exists():
        return [f"  {script.relative_to(REPO_ROOT)} not found"]

    try:
        proc = subprocess.run(
            ["bash", str(script)], capture_output=True, text=True, check=False
        )
    except OSError as e:
        return [f"  could not run {script.name}: {e}"]

    if proc.returncode == 0:
        return []
    return [
        "  An advisory ignore in deny.toml is STALE (its unblock condition is now met):",
        *(f"    {line}" for line in proc.stdout.strip().splitlines()),
    ]


def main() -> int:
    all_errors: list[str] = []

    errors = check_toml_parse()
    if errors:
        print("FAIL: TOML parse errors:")
        for e in errors:
            print(e)
        all_errors.extend(errors)
    else:
        print("OK: All TOML files parse.")

    errors = check_crate_name_matches_dir()
    if errors:
        print("FAIL: Crate name mismatches:")
        for e in errors:
            print(e)
        all_errors.extend(errors)
    else:
        print("OK: All crate names match directory names.")

    errors = check_spec_crate_names()
    if errors:
        print("FAIL: Spec/workspace member mismatches:")
        for e in errors:
            print(e)
        all_errors.extend(errors)
    else:
        print("OK: All spec crate names match workspace members.")

    errors = check_jsonwebtoken_advisory_still_unreachable()
    if errors:
        print("FAIL: jsonwebtoken advisory is reachable or its guard is stale:")
        for e in errors:
            print(e)
        all_errors.extend(errors)
    else:
        print("OK: Ignored jsonwebtoken advisory is still unreachable.")

    errors = check_advisory_unblock_conditions()
    if errors:
        print("FAIL: Stale advisory waiver:")
        for e in errors:
            print(e)
        all_errors.extend(errors)
    else:
        print("OK: Advisory ignore unblock conditions are still unmet.")

    if all_errors:
        print(f"\n{len(all_errors)} error(s) found.")
        return 1
    print("\nAll checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())