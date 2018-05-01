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

CURL_INSTALLED=false
command -v curl >/dev/null 2>&1 && CURL_INSTALLED=true

# no curl, install it
if [ ${CURL_INSTALLED} = false ]; then
  PACKAGES=${PACKAGES}" curl";
  CURL_INSTALLED=true
else
  echo "Curl is already installed"
  exit 0
fi

command -v yum >/dev/null 2>&1 && YUM_INSTALLED=true
command -v apt-get >/dev/null 2>&1 && APT_GET_INSTALLED=true
command -v dnf >/dev/null 2>&1 && DNF_INSTALLED=true
command -v zypper >/dev/null 2>&1 && ZYPPER_INSTALLED=true


if [ ${YUM_INSTALLED} = false ]; then
  ${SUDO} yum install ${PACKAGES};

elif [ ${APT_GET_INSTALLED} = false ]; then
  ${SUDO} apt-get update;
  ${SUDO} apt-get -y install ${PACKAGES};

elif [ ${DNF_INSTALLED} = false ]; then
  ${SUDO} dnf -y install ${PACKAGES};

elif [ ${ZYPPER_INSTALLED} = false ]; then
  ${SUDO} zypper install -y ${PACKAGES};

else
    >&2 echo "Any of Yum, Apt-get, Dnf, Zypper package manager is not available"
    exit 1
fi

echo "Curl is installed successfully"
