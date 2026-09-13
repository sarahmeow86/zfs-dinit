# artix-zfs

Bozza di servizi dinit per ZFS su Artix Linux, derivati da
[dinit-chimera](https://github.com/chimera-linux/dinit-chimera)
(`services/early-fs-zfs`, `early/scripts/fs-zfs.sh`).

Si appoggiano ai target di `dinit-rc` di Artix (`early-fs-pre.target`,
`early-fs-fstab.target`, `early-fs-local.target`, `pre-local.target`,
`local.target`), che hanno gli stessi nomi di quelli di dinit-chimera.

## Servizi

| Servizio    | Tipo      | Cosa fa                                                         |
|-------------|-----------|-----------------------------------------------------------------|
| `zfs-mount` | scripted  | `zpool import -N -a` + `zfs mount -a -l`, prima di fstab        |
| `zfs-zvol`  | scripted  | `zvol_wait`, se fstab/swap usano zvol (opzionale)               |
| `zfs-share` | scripted  | `zfs share -a`, dopo `local.target` (opzionale)                 |
| `zed`       | process   | ZFS Event Daemon (opzionale)                                    |

## Differenze rispetto a dinit-chimera

- `@SCRIPT_PATH@` (sostituito da meson) diventa `@LIBDIR@/dinit`, sostituito
  dal Makefile come fa `dinit-rc` di Artix.
- `common.sh` non esiste su Artix: dello script resta solo l'`export PATH`;
  il controllo `DINIT_CONTAINER` e `log_debug` sono stati tolti.
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
  pool (utile per le live).

## Installazione

Come pacchetto `zfs-dinit` (percorsi di Artix, `/usr/lib/dinit` e
`/usr/lib/dinit.d`), da questa cartella:

```sh
makepkg -si
```

Il `PKGBUILD` usa direttamente i file della cartella (`$startdir`), quindi non
serve nessun tarball. Dipende da `dinit`, `zfs-dkms-git` e `zfs-utils-git`:
vanno installati prima, da [Chaotic-AUR](https://aur.chaotic.cx) o compilati
dall'AUR, perché `makepkg -s` non installa pacchetti dall'AUR.

A mano, senza toccare `/usr/lib`:

```sh
sudo make install PREFIX=/usr/local DINITSRVDIR=/etc/dinit.d
```

Poi abilita i servizi (crea i link in `/etc/dinit.d/boot.d`):

```sh
sudo dinitctl enable zfs-mount
sudo dinitctl enable zfs-zvol    # solo se usi zvol in fstab o come swap
sudo dinitctl enable zfs-share   # solo se usi sharenfs/sharesmb
sudo dinitctl enable zed         # opzionale
```

`boot` avvia tutta la catena insieme, quindi i vincoli `before`/`after` sono
rispettati dal boot successivo.

## Note

- **Root su ZFS:** il pool di root lo importa l'initramfs (il modulo `90zfs`
  di dracut, che `zfs-utils-git` installa, o l'hook `zfs` di mkinitcpio).
  `zfs-mount` importa gli altri pool e salta quelli già importati.
- **Modulo:** `zpool` carica `zfs` da solo se manca `/dev/zfs`; in alternativa
  aggiungilo a `/etc/modules-load.d/`.
- **Spegnimento:** lo `shutdown-hook` di Artix smonta tutto e rimonta `/` in
  sola lettura; `zpool export` non è necessario.
- **Percorsi:** `zfs-utils-git` compila con `--sbindir=/usr/bin`, quindi `zed`
  e `zvol_wait` sono in `/usr/bin`. Non ancora testato su un sistema Artix reale.

## Licenza

BSD-2-Clause, vedi `COPYING`.
