# Built from the files in this directory: run `makepkg -si` here.
# One package per init; install only the one your system boots with,
# e.g. `makepkg -s && sudo pacman -U zfs-runit-*.pkg.tar.zst`.

pkgbase=zfs-dinit
pkgname=('zfs-dinit' 'zfs-runit' 'zfs-s6')
pkgver=0.2
pkgrel=1
arch=('any')
url="https://codeberg.org/sarahmeow86/zfs-dinit"
license=('BSD-2-Clause')

package_zfs-dinit() {
    pkgdesc="dinit service scripts for ZFS (derived from dinit-chimera)"
    depends=('dinit' 'zfs-dkms-git' 'zfs-utils-git')
    install=zfs-dinit.install
    make -C "$startdir" DESTDIR="$pkgdir" install-dinit
    install -Dm644 "$startdir/COPYING" "$pkgdir/usr/share/licenses/$pkgname/COPYING"
}

package_zfs-runit() {
    pkgdesc="runit-rc sysinit step and runit services for ZFS"
    depends=('runit-rc' 'zfs-dkms-git' 'zfs-utils-git')
    install=zfs-runit.install
    make -C "$startdir" DESTDIR="$pkgdir" install-runit
    install -Dm644 "$startdir/COPYING" "$pkgdir/usr/share/licenses/$pkgname/COPYING"
}

package_zfs-s6() {
    pkgdesc="s6-rc services for ZFS"
    depends=('s6-scripts' 'zfs-dkms-git' 'zfs-utils-git')
    install=zfs-s6.install
    make -C "$startdir" DESTDIR="$pkgdir" install-s6
    install -Dm644 "$startdir/COPYING" "$pkgdir/usr/share/licenses/$pkgname/COPYING"
}
