#!/opt/homebrew/bin/bash
set -euo pipefail
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build-channel.sh" final
