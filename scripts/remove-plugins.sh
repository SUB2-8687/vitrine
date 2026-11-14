#!/usr/bin/env bash
# Takes every app extension out of a built IPA, in place.
#
#   bash scripts/remove-plugins.sh <app.ipa>
#
# Removes the whole Payload/*.app/PlugIns/ folder (widget, Siri intents, notification service, Vitrine's
# own Live Activity ...) and any other .appex bundle left anywhere inside the app, then checks that
# nothing is left. Exits non-zero if an extension is still in the IPA.
set -euo pipefail

IPA="${1:-}"
[ -n "$IPA" ] && [ -f "$IPA" ] || { echo "usage: $0 <app.ipa>" >&2; exit 1; }
IPA="$(cd "$(dirname "$IPA")" && pwd)/$(basename "$IPA")"

APP_DIR="$(unzip -Z1 "$IPA" | grep -oE '^Payload/[^/]+\.app/' | sort -u | head -1)"
[ -n "$APP_DIR" ] || { echo "no Payload/*.app in $IPA" >&2; exit 1; }

left() { unzip -Z1 "$IPA" | grep -E "^${APP_DIR}PlugIns/|\.appex(/|$)" || true; }

if [ -z "$(left)" ]; then
  echo "    no app extensions in this IPA"
  exit 0
fi

echo "==> removing every app extension from $(basename "$IPA")"
unzip -Z1 "$IPA" | grep -oE "^${APP_DIR}.*\.appex/" | sort -u | sed 's/^/    removed: /'

# zip -d patterns: the folder, plus any other .appex bundle inside the app.
zip -q -d "$IPA" "${APP_DIR}PlugIns/*" "${APP_DIR}PlugIns" >/dev/null 2>&1 || true
while IFS= read -r appex; do
  [ -n "$appex" ] && zip -q -d "$IPA" "${appex}*" >/dev/null 2>&1 || true
done < <(unzip -Z1 "$IPA" | grep -oE "^${APP_DIR}.*\.appex/" | sort -u)

if [ -n "$(left)" ]; then
  echo "app extensions are still in $IPA after removal:" >&2
  left | head -20 >&2
  exit 1
fi
echo "    done: no PlugIns/ and no .appex left"
