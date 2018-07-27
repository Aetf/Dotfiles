#! /bin/sh

# Default values
REFIND_INSTALL_SCRIPT=/usr/bin/refind-install
MAX_RETRY=2
RETRY_WAIT=5s

# Global value
SOMETHING_WRONG=

#
# Purpose: Display message on stderr
#
info() {
    echo "==> $@" >&2
}
err() {
    echo "==> ERROR: $@" >&2
    SOMETHING_WRONG=1
}
warning() {
    echo "==> WARNING: $@" >&2
}

# Purpose: Display message and die with given exit code
# 
die(){
    local message="$1"
    local exitCode=$2
    err "$message"
    [ "$exitCode" == "" ] && exit 1 || exit $exitCode
}

#
# Purpose: Is script run by root? Else die..
# 
is_user_root(){
    [ "$(id -u)" != "0" ] && die "You must be root to run this script" 2
}

mountPathForBoot() {
    findmnt -n -o SOURCE -T /boot | sed -r 's/^.*\[(.*)\].*$/\1/'
}

clean() {
    info "Restoring /boot previous mount status"
    umount -v /boot

    info "Removing unneeded conf file"
    rm -fv /esp/*.conf
    # We are using /esp/EFI/refind/manual.conf to provide boot menus, no need for the auto generated one.
    rm -rfv /esp/EFI/archlinux/refind_linux.conf

    # Remove back icons if identical
    if [ -d /esp/EFI/refind/icons-backup ]; then
        if diff -q /esp/EFI/refind/icons /esp/EFI/refind/icons-backup > /dev/null; then
            info "Removing identical icons-backup"
            rm -rfv /esp/EFI/refind/icons-backup
        else
            warning "Detected updated icons, check and remove /esp/EFI/refind/icons-backup if needed"
        fi
    fi
}

setup() {
    #info "Umount anything on /boot"
    #while umount /boot; do continue; done

    info "Mounting ESP on /boot"
    mount -vo bind /esp /boot
}

ensureScript() {
    local count=0
    while [ ! -x "$REFIND_INSTALL_SCRIPT" ]; do
        count=$(($count+1))
        warning "Waiting for $REFIND_INSTALL_SCRIPT to be ready for 5 seconds"
        sleep 5s

        if [ $count -ge $MAX_RETRY ]; then
            err "Exceeded max retry times, abort"
            return 1
        fi
    done
    return 0
}

tryInstall() {
    if ensureScript; then
        info "Installing refind"
        "$REFIND_INSTALL_SCRIPT"
    fi
}

main() {
    setup
    tryInstall
    clean

    if ! [ "${SOMETHING_WRONG}x" = "x" ]; then
        return 1
    fi
}

main $@
