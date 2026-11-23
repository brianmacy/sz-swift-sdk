#!/usr/bin/env bash
# Installs a released Senzing runtime from Senzing's production apt repository
# (Debian/Ubuntu), plus the tools the tests need. Used by CI; runs as root
# (for example in the Swift container) or through sudo.
#
#   senzingsdk-runtime  libSz, the C headers, szflags.json / szerrors.json,
#                       /etc/opt/senzing, /opt/senzing/data, the resources tree
#   senzingsdk-setup    the SQLite schema script the tests apply per repository
#   sqlite3             applies that schema
#
# Installing Senzing requires accepting the Senzing EULA
# (https://senzing.com/end-user-license-agreement); SENZING_ACCEPT_EULA below
# records that acceptance for CI.
set -euo pipefail

SENZING_VERSION="${SENZING_VERSION:-4.5.0}"
SENZING_REPO_DEB="${SENZING_REPO_DEB:-senzingrepo_2.0.2-1_all.deb}"
SENZING_REPO_URL="${SENZING_REPO_URL:-https://senzing-production-apt.s3.amazonaws.com}"

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
fi
export DEBIAN_FRONTEND=noninteractive

$SUDO apt-get update
$SUDO apt-get install -y --no-install-recommends \
    apt-transport-https ca-certificates git gnupg lsb-release sqlite3 wget

deb="$(mktemp -d)/${SENZING_REPO_DEB}"
wget -q "${SENZING_REPO_URL}/${SENZING_REPO_DEB}" -O "$deb"
$SUDO apt-get install -y "$deb"
$SUDO apt-get update

# sudo resets the environment, so the EULA acceptance is passed explicitly.
$SUDO env SENZING_ACCEPT_EULA=I_ACCEPT_THE_SENZING_EULA DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
    "senzingsdk-runtime=${SENZING_VERSION}-*" \
    "senzingsdk-setup=${SENZING_VERSION}-*"

# Fail now if anything the build or tests use is missing.
for path in \
    /opt/senzing/er/lib/libSz.so \
    /opt/senzing/er/sdk/c/libSz.h \
    /opt/senzing/er/sdk/c/szhelpers/SzLang_helpers.h \
    /opt/senzing/er/sdk/szflags.json \
    /opt/senzing/er/sdk/szerrors.json \
    /opt/senzing/er/resources/schema/szcore-schema-sqlite-create.sql; do
    test -e "$path" || { echo "missing: $path" >&2; exit 1; }
done
test -d /etc/opt/senzing
test -d /opt/senzing/data
cat /opt/senzing/er/szBuildVersion.json
