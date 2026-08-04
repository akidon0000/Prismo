#!/bin/bash

# SwiftPM の成果物から Prismo.app を組み立てる共通処理。
# 呼び出し元は set -euo pipefail を設定し、必要なら事前に出力先を削除する。
package_prismo_app() {
  local build_dir="$1"
  local app_dir="$2"
  local project_dir="$3"
  local app_name="Prismo"

  mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
  cp "$build_dir/$app_name" "$app_dir/Contents/MacOS/$app_name"
  cp "$project_dir/Info.plist" "$app_dir/Contents/Info.plist"

  local bundle="$build_dir/${app_name}_${app_name}.bundle"
  if [[ -d "$bundle" ]]; then
    cp -R "$bundle" "$app_dir/Contents/Resources/"
  fi

  if [[ -f "$project_dir/assets/AppIcon.icns" ]]; then
    cp "$project_dir/assets/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
  fi
}
