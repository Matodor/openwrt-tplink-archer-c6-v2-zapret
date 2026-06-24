# OpenWrt + zapret для TP-Link Archer C6 v2

Рабочая папка с прошивками, recovery-скриптом и настройкой zapret для TP-Link Archer C6 RU v2.0 / Archer C6 v2 (EU/RU/JP), target `ath79/generic`, arch `mips_24kc`.

Текущий роутер проверен как:

```text
OpenWrt 24.10.4 r28959-29397011cc
TP-Link Archer C6 v2 (EU/RU/JP)
192.168.1.1
```

## Что внутри

```text
artifacts/              Собранные и скачанные прошивки, manifests, sha256
files/                  Overlay-файлы для установки на роутер
files/usr/bin/          zapret-tool и doh-ram
files/etc/init.d/       init-скрипты автозапуска
notes/                  Логи сборок и рабочие заметки
source-apks/            Исходные zapret APK/ZIP
tests/                  Локальные shell-тесты zapret-tool
build-image.sh          Сборка OpenWrt image через ImageBuilder
recover-archer-c6-v2.sh TFTP recovery helper для Archer C6 v2
```

Подробно по прошивкам: [ARTIFACTS.md](ARTIFACTS.md).
Установка с нуля: [docs/INSTALL-FROM-SCRATCH.md](docs/INSTALL-FROM-SCRATCH.md).
Текущее состояние роутера: [docs/ROUTER-STATE.md](docs/ROUTER-STATE.md).
Upstream-источники и будущий workflow обновления: [docs/UPSTREAMS.md](docs/UPSTREAMS.md).

## Рекомендуемая прошивка

Для текущего opkg-based состояния использовать ветку `24.10.4`, а не раннюю `25.12.4` сборку с `apk`: на Archer C6 v2 слишком маленький overlay, persistent package install быстро упирается в `No space left on device`.

Основной готовый artifact:

```text
artifacts/24.10.4-zapret-luci/
```

В этой папке есть `factory.bin`, `sysupgrade.bin`, manifest и sha256. `factory.bin` нужен для TFTP recovery или перехода со стоковой прошивки; `sysupgrade.bin` нужен для обновления уже установленного OpenWrt.

## Установка с нуля

Основной способ для Archer C6 v2 - TFTP recovery через `recover-archer-c6-v2.sh`.

Кратко:

```sh
ip link
sudo ./recover-archer-c6-v2.sh --iface <ethernet-iface> --server-ip 192.168.0.66/24 --timeout 300
```

Порядок:

1. Подключить компьютер кабелем к WAN порту роутера.
2. Запустить recovery helper.
3. Отключить питание роутера.
4. Зажать RESET.
5. Подать питание, удерживая RESET 10-15 секунд.
6. Дождаться TFTP transfer и не трогать питание несколько минут.
7. После перезагрузки зайти на `192.168.1.1`.
8. Задать пароль root и применить zapret setup из раздела ниже.

Подробная инструкция: [docs/INSTALL-FROM-SCRATCH.md](docs/INSTALL-FROM-SCRATCH.md).

## Быстрый запуск на уже установленном OpenWrt

Скопировать актуальные скрипты:

```sh
scp -O files/usr/bin/zapret-tool root@192.168.1.1:/usr/bin/zapret-tool
scp -O files/usr/bin/doh-ram root@192.168.1.1:/usr/bin/doh-ram
scp -O files/etc/init.d/doh-ram root@192.168.1.1:/etc/init.d/doh-ram
scp -O files/etc/init.d/zapret-tool root@192.168.1.1:/etc/init.d/zapret-tool
```

Включить и применить текущую рабочую конфигурацию:

```sh
ssh root@192.168.1.1 '
chmod 755 /usr/bin/zapret-tool /usr/bin/doh-ram /etc/init.d/doh-ram /etc/init.d/zapret-tool
/etc/init.d/doh-ram enable
/etc/init.d/doh-ram start
/etc/init.d/zapret-tool enable
zapret-tool flowseal update
zapret-tool flowseal ipset update
zapret-tool flowseal telegram-reset
zapret-tool flowseal hosts install
zapret-tool flowseal apply fs-fake-tls-auto-alt03
'
```

Текущая рабочая стратегия:

```text
fs-fake-tls-auto-alt03
```

## Проверка

Локальные тесты:

```sh
sh tests/test-zapret-tool.sh
```

Проверка на роутере:

```sh
ssh root@192.168.1.1 'zapret-tool status'
ssh root@192.168.1.1 'zapret-tool flowseal test'
ssh root@192.168.1.1 'zapret-tool test domain www.youtube.com'
ssh root@192.168.1.1 'zapret-tool test domain web.telegram.org'
```

## Обновление списков и стратегий

Обновить текущие Flowseal lists, tmp ipset, Telegram hosts и пере-применить рабочую стратегию:

```sh
ssh root@192.168.1.1 '
zapret-tool flowseal update
zapret-tool flowseal ipset update
zapret-tool flowseal telegram-reset
zapret-tool flowseal hosts install
zapret-tool flowseal apply fs-fake-tls-auto-alt03
'
```

Если надо обновить сам `zapret-tool`:

```sh
sh -n files/usr/bin/zapret-tool
sh tests/test-zapret-tool.sh
scp -O files/usr/bin/zapret-tool root@192.168.1.1:/usr/bin/zapret-tool
ssh root@192.168.1.1 'chmod 755 /usr/bin/zapret-tool && ash -n /usr/bin/zapret-tool'
```

Где брать upstream-стратегии и списки: [docs/UPSTREAMS.md](docs/UPSTREAMS.md).

## Recovery

TFTP helper:

```sh
sudo ./recover-archer-c6-v2.sh --iface <ethernet-iface> --server-ip 192.168.0.66/24 --timeout 300
```

Кабель подключать к WAN порту роутера, если bootloader запрашивает `ArcherC6v2_tp_recovery.bin` с IP `192.168.0.86 -> 192.168.0.66`.

Скрипт готовит TFTP root, создает имена:

```text
ArcherC6v2_tp_recovery.bin
ArcherC6V2_tp_recovery.bin
tp_recovery.bin
```
