#!/usr/bin/env bash
# Grava a versão nos presets Android e no projeto (usado pelo job de release no CI).
#   tools/set_version.sh <version_code> <version_name> [telemetry_url]
# Ex.: tools/set_version.sh 142 1.0.0 https://telemetria.exemplo.workers.dev
set -euo pipefail
code="$1"
name="$2"
url="${3:-}"
[[ "$code" =~ ^[0-9]+$ ]] || { echo "version_code inválido: $code" >&2; exit 1; }
[[ "$name" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.]+)?$ ]] || { echo "version_name inválido: $name" >&2; exit 1; }
cd "$(dirname "$0")/.."
sed -i -E "s/^version\/code=.*/version\/code=$code/; s/^version\/name=.*/version\/name=\"$name\"/" export_presets.cfg
sed -i -E "s/^config\/version=.*/config\/version=\"$name\"/" project.godot
if [[ -n "$url" ]]; then
	sed -i -E "s|^telemetry_url=.*|telemetry_url=\"$url\"|" project.godot
fi
grep -E "^version/(code|name)=" export_presets.cfg
grep -E "^config/version=|^telemetry_url=" project.godot
