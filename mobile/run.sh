#!/usr/bin/env bash
# Launch the SmartBand companion on the Linux desktop.
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v flutter >/dev/null 2>&1; then
  if [[ -x "${HOME}/sdk/flutter/bin/flutter" ]]; then
    export PATH="${HOME}/sdk/flutter/bin:${PATH}"
  else
    echo "Flutter is not on PATH. Install it or add its bin directory to PATH." >&2
    exit 1
  fi
fi

exec flutter run -d linux "$@"
