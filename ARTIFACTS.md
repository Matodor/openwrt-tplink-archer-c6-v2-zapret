# Artifacts

Прошивки и source packages сохранены вместе со скриптами, чтобы установку можно было повторить без поиска внешних файлов.

## Рекомендуемые

### `artifacts/24.10.4-zapret-luci/`

OpenWrt 24.10.4 для Archer C6 v2 с LuCI и zapret-пакетами.

```text
openwrt-24.10.4-ath79-generic-tplink_archer-c6-v2-squashfs-factory.bin     7,542,090 bytes
openwrt-24.10.4-ath79-generic-tplink_archer-c6-v2-squashfs-sysupgrade.bin  7,537,451 bytes
openwrt-24.10.4-ath79-generic-tplink_archer-c6-v2.manifest                 4,563 bytes
openwrt-24.10.4-ath79-generic-tplink_archer-c6-v2.bom.cdx.json             18,656 bytes
profiles.json
sha256sums
```

Использовать `factory.bin` для TFTP recovery/stock path, `sysupgrade.bin` для OpenWrt sysupgrade.

### `artifacts/official-24.10.4/`

Официальный OpenWrt 24.10.4 factory image:

```text
openwrt-24.10.4-ath79-generic-tplink_archer-c6-v2-squashfs-factory.bin  7,148,874 bytes
```

## Рабочие и промежуточные

### `artifacts/build-1/`

Ранняя 25.12.4 сборка. На практике привела к `apk`/overlay проблемам на этом устройстве, но сохранена для истории и сравнения.

```text
openwrt-25.12.4-ath79-generic-tplink_archer-c6-v2-squashfs-factory.bin     7,728,306 bytes
openwrt-25.12.4-ath79-generic-tplink_archer-c6-v2-squashfs-sysupgrade.bin  7,733,527 bytes
manifest / bom / profiles / sha256sums
```

### `artifacts/openwrt-25.12.4-ath79-generic-tplink_archer-c6-v2-squashfs-sysupgrade.bin`

Копия 25.12.4 sysupgrade image:

```text
sha256: 59b9ff9e7c72ae9e0485cfc8ccfef5823adec71a8722f3e6e919e764ef71ac75
size:   7,733,527 bytes
```

### `artifacts/24.10.4-zapret/`

Сборка 24.10.4 без полного LuCI набора. Сохранена для истории и сравнения с основной `24.10.4-zapret-luci`.

```text
openwrt-24.10.4-ath79-generic-tplink_archer-c6-v2-squashfs-factory.bin  7,148,874 bytes
manifest / bom / profiles / sha256sums
```

## Source packages

```text
source-apks/zapret-72.20260307-r1.apk
source-apks/luci-app-zapret-72.20260307-r1.apk
source-apks/zapret_v72.20260307_mips_24kc.zip
```

Эти файлы использовались для установки zapret/luci-app-zapret на OpenWrt 24.10.4.
