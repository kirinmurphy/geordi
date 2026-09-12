"""Strict stdlib validator for the JSON Schema subset used by CLI resources."""

import json
import re
from pathlib import Path


class ManifestError(ValueError):
    """A resource violates its structural contract or a security invariant."""


class SchemaValidator:
    """Keep field lists and enums in the declarative schema, not Python models."""

    def __init__(self, schema):
        self.schema = schema

    def validate(self, value, rule=None, path="$"):
        rule = self.schema if rule is None else rule
        supported = {"$schema", "$id", "$defs", "$ref", "title", "description",
                     "type", "const", "enum", "properties", "required",
                     "additionalProperties", "items", "minItems", "maxItems",
                     "uniqueItems", "minLength", "maxLength", "pattern"}
        unknown = set(rule) - supported
        if unknown:
            raise ManifestError(f"{path}: unsupported schema keywords: {sorted(unknown)}")
        if "$ref" in rule:
            ref = rule["$ref"]
            if not ref.startswith("#/"):
                raise ManifestError(f"{path}: only local schema references are supported")
            target = self.schema
            for part in ref[2:].split("/"):
                target = target[part.replace("~1", "/").replace("~0", "~")]
            self.validate(value, target, path)
        types = {"object": dict, "array": list, "string": str, "integer": int,
                 "boolean": bool, "null": type(None)}
        kind = rule.get("type")
        if kind and (kind not in types or type(value) is not types[kind]):
            raise ManifestError(f"{path}: expected {kind}")
        if "const" in rule and (type(value) is not type(rule["const"]) or value != rule["const"]):
            raise ManifestError(f"{path}: expected constant {rule['const']!r}")
        if "enum" in rule and value not in rule["enum"]:
            raise ManifestError(f"{path}: expected one of {rule['enum']!r}")
        if isinstance(value, dict):
            self._object(value, rule, path)
        elif isinstance(value, list):
            self._array(value, rule, path)
        elif isinstance(value, str):
            if len(value) < rule.get("minLength", 0) or len(value) > rule.get("maxLength", float("inf")):
                raise ManifestError(f"{path}: invalid string length")
            if "pattern" in rule and re.search(rule["pattern"], value) is None:
                raise ManifestError(f"{path}: does not match {rule['pattern']!r}")

    def _object(self, value, rule, path):
        properties = rule.get("properties", {})
        for key in rule.get("required", []):
            if key not in value:
                raise ManifestError(f"{path}.{key}: required field missing")
        for key, child in value.items():
            if key in properties:
                self.validate(child, properties[key], f"{path}.{key}")
            elif rule.get("additionalProperties") is False:
                raise ManifestError(f"{path}.{key}: unknown field")

    def _array(self, value, rule, path):
        if len(value) < rule.get("minItems", 0) or len(value) > rule.get("maxItems", float("inf")):
            raise ManifestError(f"{path}: invalid array length")
        if rule.get("uniqueItems") and len({json.dumps(item, sort_keys=True) for item in value}) != len(value):
            raise ManifestError(f"{path}: duplicate array items")
        for index, child in enumerate(value):
            self.validate(child, rule.get("items", {}), f"{path}[{index}]")


def read_json(path):
    def unique_pairs(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ManifestError(f"{path}: duplicate field {key!r}")
            result[key] = value
        return result

    try:
        return json.loads(Path(path).read_text(encoding="utf-8"), object_pairs_hook=unique_pairs)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ManifestError(f"{path}: {error}") from error
