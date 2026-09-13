# Built from the files in this directory: run `makepkg -si` here.

pkgname=zfs-dinit
pkgver=0.1
pkgrel=1
pkgdesc="dinit service scripts for ZFS (derived from dinit-chimera)"
arch=('any')
url="https://github.com/chimera-linux/dinit-chimera"
license=('BSD-2-Clause')
depends=('dinit' 'zfs-utils')
install=zfs-dinit.install

package() {
    make -C "$startdir" DESTDIR="$pkgdir" install
    install -Dm644 "$startdir/COPYING" "$pkgdir/usr/share/licenses/$pkgname/COPYING"
}
