#!/bin/bash
set -euo pipefail
source_dir="$(cd "$(dirname "$0")/../harmonyos" && pwd)"
deveco_dir="${RENTRECEIPT_DEVECO_DIR:-/Applications/DevEco-Studio.app/Contents}"
build_dir="$(mktemp -d /private/tmp/rentreceipt-harmonyos.XXXXXX)"
trap 'rm -rf "$build_dir"' EXIT
cp -R "$source_dir/AppScope" "$source_dir/entry" "$source_dir/hvigor" "$build_dir/"
cp "$source_dir/build-profile.json5" "$source_dir/oh-package.json5" "$source_dir/hvigorfile.ts" "$build_dir/"
if [[ "${RENTRECEIPT_SIGN:-0}" == "1" ]]; then
  "$deveco_dir/tools/node/bin/node" - "$source_dir/signing-config.local.json" "$build_dir/build-profile.json5" <<'NODE'
const fs = require('fs');
const [local, profile] = process.argv.slice(2);
if (!fs.existsSync(local)) throw new Error('Missing local debug signing configuration');
const config = JSON.parse(fs.readFileSync(profile, 'utf8'));
config.app.signingConfigs = JSON.parse(fs.readFileSync(local, 'utf8'));
config.app.products[0].signingConfig = config.app.signingConfigs[0].name;
fs.writeFileSync(profile, JSON.stringify(config));
NODE
fi
mkdir -p "$build_dir/node_modules/@ohos"
ln -s "$deveco_dir/tools/hvigor/hvigor" "$build_dir/node_modules/@ohos/hvigor"
ln -s "$deveco_dir/tools/hvigor/hvigor-ohos-plugin" "$build_dir/node_modules/@ohos/hvigor-ohos-plugin"
export JAVA_HOME="$deveco_dir/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$deveco_dir/tools/node/bin:$PATH"
export NODE_PATH="$build_dir/node_modules"
export DEVECO_SDK_HOME="$deveco_dir/sdk"
export HVIGOR_USER_HOME="$build_dir/hvigor-cache"
cd "$build_dir"
"$deveco_dir/tools/node/bin/node" "$deveco_dir/tools/hvigor/hvigor/bin/hvigor.js" \
  --mode module -p product=default -p module=entry@default assembleHap --no-daemon
mkdir -p "$source_dir/entry/build/outputs"
cp -R "$build_dir/entry/build/default/outputs/" "$source_dir/entry/build/outputs/"
