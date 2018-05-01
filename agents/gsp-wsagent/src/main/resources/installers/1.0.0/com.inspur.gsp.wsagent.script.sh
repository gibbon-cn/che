is_current_user_root() {
    test "$(id -u)" = 0
}

is_current_user_sudoer() {
    sudo -n true > /dev/null 2>&1
}

set_sudo_command() {
    if is_current_user_sudoer && ! is_current_user_root; then SUDO="sudo -E"; else unset SUDO; fi
}

set_sudo_command
unset PACKAGES

command -v tar >/dev/null 2>&1 || { PACKAGES=${PACKAGES}" tar"; }
CURL_INSTALLED=false
WGET_INSTALLED=false
command -v curl >/dev/null 2>&1 && CURL_INSTALLED=true
command -v wget >/dev/null 2>&1 && WGET_INSTALLED=true

# no curl, no wget, install curl
if [ ${CURL_INSTALLED} = false ] && [ ${WGET_INSTALLED} = false ]; then
  PACKAGES=${PACKAGES}" curl";
  CURL_INSTALLED=true
fi

DOWNLOAD_AGENT_BINARIES_URI='http://10.24.19.123/che/gsp-wsgent/gsp-wsagent-1.0.0.tar.gz'

echo "GSP WS Agent binary is downloaded remotely"
GSP_WSAGENT_DIR=/home/user/che
mkdir -p ${GSP_WSAGENT_DIR}
curl -s ${DOWNLOAD_AGENT_BINARIES_URI} | tar xzf - -C ${GSP_WSAGENT_DIR}

cd ${GSP_WSAGENT_DIR}/gsp-wsagent
sh startup-linux.sh

echo "GSP WS Agent is installed successfully"

