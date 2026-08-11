#!/usr/bin/env sh

### /// alpine-chroot.sh // ConzZah // 2026-07-24 18:30 ///

## exit if we're running on termux
[ -n "$TERMUX__PREFIX" ] && printf '%s\n' "--> SORRY, THIS CAN'T RUN ON TERMUX." && exit 1

## find out if we're a 0 or 1000 (root or normal user)
[ "$(id -u)" = "1000" ] && {
## next, check if sudo is present,
## else use doas, if we're on alpine
command -v sudo >/dev/null && doso="sudo"
[ -f "/etc/alpine-release" ] && doso="doas"
}

## check the current $arch, and exit if it doesn't match.
arch="$(uname -m)"
case "$arch" in
x86_64) : ;;
aarch64) : ;;
armhf) : ;;
armv7*) arch="armv7" ;;
loongarch64) : ;;
ppc64le) : ;;
riscv64) : ;;
s390x) : ;;
i686|i586|i486) arch="x86" ;;
*) printf '\n%s\n' "--> SORRY, ARCHITECTURE: ${arch} IS NOT SUPPORTED." && exit 1
esac

## edit $PATH, so chroot can be found
PATH="${PATH}:/sbin:/usr/sbin"

## check for missing deps
deps="mountpoint mount chroot curl grep uniq tar sed cut rev 7z"
missing_deps=""
## if any $dep is missing, write it to $missing deps
for dep in $deps; do
! command -v "$dep" >/dev/null && missing_deps="$missing_deps $dep"
done

## if $missing deps is nonzero, tell the user which are missing & exit 1
[ -n "$missing_deps" ] && printf '\n%s\n%s\n' "--> ERROR: THE FOLLOWING DEPS ARE MISSING:" "$missing_deps" && exit 1

## make sure $cr exists
cr="$HOME/.alpine-chroot"
mkdir -p "${cr}"; cd "${cr}" || exit 1


dl_minirootfs () {
## if no root dir is found in $cr,
## download the most recent minirootfs for $arch
[ ! -d "${cr}/root" ] && printf '\n%s\n\n' "--> DOWNLOADING MINIROOTFS.." && {
minirootfs="$(
curl -s 'https://alpinelinux.org/downloads/'| \
grep -o 'href.*alpine-minirootfs-.*.tar.gz'| \
cut -d '"' -f 2-| \
sed 's~&#x2F;~/~g'| \
uniq| grep "${arch}"
)"

## download & extract
curl -#LO "$minirootfs" || exit 1
alp="$(printf '%s\n' "$minirootfs"| rev| cut -d '/' -f 1| rev)"
printf '\n%s\n' "--> EXTRACTING: $alp"
tar -xf "$alp" || exit 1
rm "$alp"

copy_resolv_conf

## install the basics
## (NOTE: if /bin/sh is used as login shell, stuff won't be sourced correctly)
printf '\n%s\n\n' "--> INSTALLING PACKAGES.."
$doso chroot "${cr}" '/bin/sh' -c 'apk add nano bash'

## write .bashrc so we end up in /root instead of in / when chrooting
printf '%s\n' "cd /root" > "${cr}/root/.bashrc"
}
}


copy_resolv_conf () { cp -f "/etc/resolv.conf" "${cr}/etc/" ;}


mount_stuff () {
printf '\n%s\n' "--> ENTERING CHROOT.."
$doso mount -o bind "/proc" "${cr}/proc" && printf '%s\n' "--> MOUNTED: ${cr}/proc" && \
$doso mount -o bind "/dev" "${cr}/dev" && printf '%s\n' "--> MOUNTED: ${cr}/dev" && \
$doso mount -o bind "/sys" "${cr}/sys" && printf '%s\n\n' "--> MOUNTED: ${cr}/sys" || exit 1
}


enter_chroot () { $doso chroot "${cr}" '/bin/bash' -i || exit 1 ;}


unmount_stuff () {
mountpoint -q "${cr}/proc" && $doso umount "${cr}/proc" && printf '%s\n' "--> UNMOUNTED: ${cr}/proc"
mountpoint -q "${cr}/dev" && $doso umount "${cr}/dev" && printf '%s\n' "--> UNMOUNTED: ${cr}/dev"
mountpoint -q "${cr}/sys" && $doso umount "${cr}/sys" && printf '%s\n' "--> UNMOUNTED: ${cr}/sys"
}


reset_minirootfs () {
unmount_stuff
[ ! -d "${cr}/root" ] && printf '\n%s\n\n' "--> MINIROOTFS NOT FOUND, NOTHING TO PURGE." && exit 1
[ -d "${cr}/root" ] && printf '\n%s\n\n' "--> PURGING MINIROOTFS.." && $doso rm -rf "${cr}" && exit 0 || exit 1

}


backup_minirootfs () {
[ -d "${cr}/root" ] && \
printf '\n%s\n' "--> BACKING UP MINIROOTFS.."
mkdir -p "$HOME/alpine-chroot-backups" || exit 1
$doso 7z a -y "$HOME/alpine-chroot-backups/alpine-chroot-$(date +"%Y-%m-%d-%H%M").7z" "${cr}" -mx=9
}

case $1 in
*'reset') reset_minirootfs; exit ;;
*'backup') backup_minirootfs; exit ;;
esac

trap unmount_stuff INT EXIT

### LAUNCH ###
dl_minirootfs
copy_resolv_conf
unmount_stuff
mount_stuff
enter_chroot
printf '\n%s\n' "--> EXITING CHROOT.."
unmount_stuff
exit
