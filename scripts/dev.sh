#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
runtime_dir=${GAMELAB_RUNTIME_DIR:-"$project_dir/.runtime"}
godot_bin=${GODOT_BIN:-godot}
export XDG_DATA_HOME=${XDG_DATA_HOME:-"$runtime_dir/data"}
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-"$runtime_dir/config"}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-"$runtime_dir/cache"}
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"

godot_version=$("$godot_bin" --version)
case "$godot_version" in
    4.6.3.*) ;;
    *) printf 'Godot 4.6.3 necessário; encontrado: %s\n' "$godot_version" >&2; exit 1 ;;
esac

command_name=${1:-run}
if [ "$#" -gt 0 ]; then shift; fi
case "$command_name" in
    import) exec "$godot_bin" --headless --path "$project_dir" --import "$@" ;;
    test) exec "$godot_bin" --headless --path "$project_dir" --script tests/run_tests.gd "$@" ;;
    run) exec "$godot_bin" --path "$project_dir" "$@" ;;
    editor) exec "$godot_bin" --path "$project_dir" --editor "$@" ;;
    capture)
        exec "$godot_bin" --path "$project_dir" --audio-driver Dummy --script tests/capture.gd -- --capture-dir="$runtime_dir/captures" "$@"
        ;;
    build)
        mkdir -p "$project_dir/builds"
        exec "$godot_bin" --headless --path "$project_dir" --export-pack "Linux" "$project_dir/builds/gamelab.pck" "$@"
        ;;
    *) printf 'Uso: sh scripts/dev.sh [import|test|run|editor|capture|build]\n' >&2; exit 2 ;;
esac
