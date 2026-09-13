"""Validated manifest loading and repository-contained resource resolution."""

from pathlib import Path, PurePosixPath

from .schema import ManifestError, SchemaValidator, read_json


def safe_resource(root, relative, field="path"):
    """Resolve a manifest-declared path inside `root`, refusing absolute
    paths, traversal, and symlink escapes. Shared by every manifest that
    declares repository-relative paths."""
    root = Path(root).resolve()
    parts = PurePosixPath(relative).parts
    if not parts or relative.startswith("/") or ".." in parts or "." in relative.split("/") or "\\" in relative:
        raise ManifestError(f"{field}: expected a repository-relative path without traversal")
    try:
        resolved = (root / relative).resolve()
        resolved.relative_to(root)
    except (ValueError, OSError, RuntimeError) as error:
        raise ManifestError(f"{field}: path escapes repository or contains a symlink loop") from error
    return resolved


class Registry:
    def __init__(self, root):
        self.root = Path(root).resolve()
        resources = self.root / "cli/resources"
        self.validator = SchemaValidator(read_json(resources / "commands.schema.json"))
        self.data = read_json(resources / "commands.json")
        self.validate(self.data)
        brand_dir = self.root / "Sources/GeordiManifestKit/Resources"
        self.brand = read_json(brand_dir / "product-brand.json")
        SchemaValidator(read_json(brand_dir / "product-brand.schema.json")).validate(self.brand)
        # Installation names must be safe even if the brand schema is relaxed later.
        import re
        if not re.fullmatch(r"[a-z][a-z0-9-]*", self.brand.get("cliCommand", "")):
            raise ManifestError("$.cliCommand: expected a safe command name")
        names = [self.link_name(link) for link in self.data["links"]]
        if len(set(names)) != len(names):
            raise ManifestError("$.links: duplicate resolved installation name")

    def validate(self, data):
        self.validator.validate(data)
        seen = []
        for index, command in enumerate(data["commands"]):
            tokens = command["command"]
            if tokens[0] in ("help", "list"):
                raise ManifestError(f"$.commands[{index}].command: reserved control command")
            for previous in seen:
                size = min(len(previous), len(tokens))
                if previous[:size] == tokens[:size]:
                    raise ManifestError(f"$.commands[{index}].command: duplicate or ambiguous prefix")
            seen.append(tokens)
            self.resource(command["path"], f"$.commands[{index}].path")
            if any("\0" in arg for arg in command["args"]):
                raise ManifestError(f"$.commands[{index}].args: NUL is not allowed")
        names = set()
        for index, link in enumerate(data["links"]):
            if link["name"] in names:
                raise ManifestError(f"$.links[{index}].name: duplicate name")
            names.add(link["name"])
            self.resource(link["path"], f"$.links[{index}].path")
            for path in link["legacySources"]:
                self.resource(path, f"$.links[{index}].legacySources")

    def resource(self, relative, field="path"):
        return safe_resource(self.root, relative, field)

    def link_name(self, link):
        return self.brand["cliCommand"] if link["name"] == "@cliCommand" else link["name"]
