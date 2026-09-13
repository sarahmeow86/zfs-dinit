# artix-zfs

Servizi per ZFS su Artix Linux per dinit, runit e s6: tre pacchetti
(`zfs-dinit`, `zfs-runit`, `zfs-s6`) dallo stesso `PKGBUILD`, con lo stesso
script di import e mount (`scripts/zfs-mount`) e gli stessi nomi di servizio.
Per OpenRC c'è [zfs-openrc](https://codeberg.org/sarahmeow86/zfs-openrc).

I servizi dinit derivano da
[dinit-chimera](https://github.com/chimera-linux/dinit-chimera)
(`services/early-fs-zfs`, `early/scripts/fs-zfs.sh`) e si appoggiano ai target
di `dinit-rc` di Artix (`early-fs-pre.target`, `early-fs-fstab.target`,
`early-fs-local.target`, `pre-local.target`, `local.target`), che hanno gli
stessi nomi di quelli di dinit-chimera. Quelli runit e s6 seguono le
convenzioni di `runit-rc` e `s6-scripts`, sul modello di `lvm2-runit`,
`cryptsetup-s6` e `mdadm-s6`.

## Servizi

| Servizio    | dinit     | runit                              | s6                                  | Cosa fa |
|-------------|-----------|------------------------------------|-------------------------------------|---------|
| `zfs-mount` | scripted  | passo `/etc/rc/sysinit/57-zfs-mount` | oneshot essenziale nel bundle `mount` | import delle pool in `zpool.cache` + `zfs mount -a -l`, dopo `/` in lettura/scrittura |
| `zfs-zvol`  | scripted  | passo sysinit opzionale            | oneshot                             | `zvol_wait`, se fstab/swap usano zvol (opzionale) |
| `zfs-share` | scripted  | servizio (`run` + `finish`)        | oneshot (`up` + `down`)             | `zfs share -a` / `zfs unshare -a` (opzionale) |
| `zed`       | process   | servizio                           | pipeline `zed-srv` + `zed-log`      | ZFS Event Daemon (opzionale) |

### dinit

`zfs-mount` parte prima di fstab (`before = early-fs-fstab.target`),
`zfs-share` dopo `local.target`.

### runit

`runit-rc` esegue in ordine i link in `/etc/rc/sysinit`. `57-zfs-mount` sta
dopo `55-remount-root`, così i mountpoint si possono creare e `zpool.cache`
aggiornare, e prima di `60-mount-all`, così le voci di fstab su dataset ZFS li
trovano già montati: la stessa posizione che `lvm2-runit` e
`cryptsetup-runit` usano per i loro volumi. Essendo un link installato dal
pacchetto, è attivo appena `zfs-runit` è installato. `zfs-share` resta attivo
(`sleep infinity`) perché `sv down zfs-share` possa ritirare le condivisioni con
`finish`.

### s6

`zfs-mount` è un oneshot con `flag-essential`, nel bundle `mount` e dipendente
da `remount-root`, `udevadm` e `modules`, come `cryptsetup-s6`: il database di
`s6-rc` viene ricompilato dall'hook di `s6-base` all'installazione e il servizio
parte a ogni avvio. `zed` è una pipeline con log in `/var/log/zed` (o
`/run/log/zed` finché `/var/log` non è scrivibile), configurabile in
`/etc/s6/config/zed.conf`, come `mdadm-s6`.

## Differenze rispetto a dinit-chimera

- `@SCRIPT_PATH@` (sostituito da meson) diventa `@LIBDIR@/dinit`, sostituito
  dal Makefile come fa `dinit-rc` di Artix.
- `common.sh` non esiste su Artix: dello script resta solo l'`export PATH`;
  il controllo `DINIT_CONTAINER` e `log_debug` sono stati tolti.
- Si importano solo le pool elencate in `/etc/zfs/zpool.cache` (o nel file
  indicato da `ZPOOL_CACHE` in `/etc/default/zfs`; vuoto disattiva l'import).
  dinit-chimera, senza cache, esegue `zpool import -a` e importa ogni pool
  presente sui dischi: su una macchina con pool di altri sistemi, o pool
  esportate apposta, se ne impadronirebbe. Senza cache qui non si importa
  nulla e si montano solo i dataset delle pool già importate (quella di root,
  dall'initramfs).
- Gli errori non vengono più ignorati: dinit-chimera chiude ogni passo con
  `|| exit 0`, qui un pool che non si importa o un dataset che non si monta
  fanno fallire `zfs-mount` (visibile con `dinitctl status zfs-mount`), e
  `zed`, `zfs-share` e `zfs-zvol`, che ne dipendono, non partono. Non avere
  nulla da importare non è un errore: `zpool import -a` esce comunque con 0.
- Su Chimera sono `early-fs-fstab.target` ed `early-fs-local.target` ad avere
  `waits-for: early-fs-zfs`. Qui l'ordinamento è espresso con `before =` nel
  servizio ZFS, così non serve modificare i file di `dinit-rc`.
- `after = early-root-rw.target` su `zfs-mount`: su Chimera l'import può
  partire mentre `/` è ancora in sola lettura, e allora `zfs mount -a` non
  riesce a creare i mountpoint mancanti né `zpool import` ad aggiornare
  `zpool.cache`.
- `start-timeout = 0` su `zfs-mount`: `zfs mount -l` può chiedere la passphrase
  dei dataset cifrati, e il timeout predefinito di dinit (60 s) la
  interromperebbe.
- `zfs share -a` è spostato in un servizio separato, perché all'avvio iniziale
  il server NFS/SMB non è ancora attivo.
- `zfs-zvol` e `zed` non esistono in dinit-chimera; sono aggiunte.
- Il parametro del kernel `dinit_skip_volumes` è mantenuto: salta l'import dei
  pool (utile per le live). Vale anche per runit e s6, che usano lo stesso
  script.

## Installazione

Il `PKGBUILD` crea i tre pacchetti usando direttamente i file della cartella
(`$startdir`), quindi non serve nessun tarball. Installa solo quello dell'init
con cui avvii il sistema:

```sh
makepkg -s
sudo pacman -U zfs-dinit-*.pkg.tar.zst   # oppure zfs-runit-* / zfs-s6-*
```

Dipendono da `dinit`, `runit-rc` o `s6-scripts` e da `zfs-dkms-git` e
`zfs-utils-git`: questi ultimi vanno installati prima, da
[Chaotic-AUR](https://aur.chaotic.cx) o compilati dall'AUR, perché
`makepkg -s` non installa pacchetti dall'AUR.

A mano, con `make install-dinit`, `make install-runit` o `make install-s6`
(`make install` equivale a `install-dinit`), per esempio senza toccare
`/usr/lib`:

```sh
sudo make install-dinit PREFIX=/usr/local DINITSRVDIR=/etc/dinit.d
```

### Abilitare i servizi

dinit (crea i link in `/etc/dinit.d/boot.d`):

```sh
sudo dinitctl enable zfs-mount
sudo dinitctl enable zfs-zvol    # solo se usi zvol in fstab o come swap
sudo dinitctl enable zfs-share   # solo se usi sharenfs/sharesmb
sudo dinitctl enable zed         # opzionale
```

`boot` avvia tutta la catena insieme, quindi i vincoli `before`/`after` sono
rispettati dal boot successivo.

runit (`zfs-mount` è già attivo come passo di sysinit):

```sh
sudo ln -s /etc/runit/sv/zed /etc/runit/runsvdir/default/         # opzionale
sudo ln -s /etc/runit/sv/zfs-share /etc/runit/runsvdir/default/   # solo con sharenfs/sharesmb
sudo ln -s /usr/lib/rc/sv.d/zfs-zvol /etc/rc/sysinit/58-zfs-zvol  # solo con zvol in fstab o swap
```

s6 (`zfs-mount` è già nel bundle `mount`):

```sh
sudo s6 set enable zed          # opzionale
sudo s6 set enable zfs-share    # solo con sharenfs/sharesmb
sudo s6 set enable zfs-zvol     # solo con zvol in fstab o swap
sudo s6 set commit && sudo s6 live install
```

## Note

- **Pool importate all'avvio:** solo quelle nella cache. Per aggiungerne una:
  `zpool set cachefile=/etc/zfs/zpool.cache <pool>`; per toglierla:
  `zpool set cachefile=none <pool>`. Una pool creata o importata a mano con
  le opzioni predefinite finisce già nella cache.
- **Root su ZFS:** il pool di root lo importa l'initramfs (il modulo `90zfs`
  di dracut, che `zfs-utils-git` installa, o l'hook `zfs` di mkinitcpio).
  `zfs-mount` importa gli altri pool e salta quelli già importati.
- **Modulo:** `zpool` carica `zfs` da solo se manca `/dev/zfs`; in alternativa
  aggiungilo a `/etc/modules-load.d/`.
- **Spegnimento:** in tutti e tre gli init lo spegnimento di Artix smonta tutto
  e rimonta `/` in sola lettura; `zpool export` non è necessario.
- **Percorsi:** `zfs-utils-git` compila con `--sbindir=/usr/bin`, quindi `zed`
  e `zvol_wait` sono in `/usr/bin`.
- **Verificato finora:** `zfs-dinit` compilato, installato e abilitato con
  `dinitctl --offline enable` in un Artix creato con pacstrap; le definizioni
  s6 compilate da `s6-rc-compile` insieme a `s6-scripts`; il passo sysinit
  runit eseguito con le funzioni di `runit-rc`. Nessuno dei tre è ancora stato
  avviato su un sistema reale.

## Licenza

BSD-2-Clause, vedi `COPYING`.
