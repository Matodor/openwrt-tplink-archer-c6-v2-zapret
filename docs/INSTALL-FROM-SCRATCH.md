# Установка с нуля на TP-Link Archer C6 v2

Инструкция для TP-Link Archer C6 RU v2.0 / Archer C6 v2 (EU/RU/JP).

Цель: получить OpenWrt 24.10.4 с LuCI, zapret, DoH через RAM, Flowseal lists и рабочей стратегией `fs-fake-tls-auto-alt03`.

## 1. Что понадобится

```text
Роутер TP-Link Archer C6 v2
Ноутбук/ПК с Linux
Ethernet-адаптер
Кабель Ethernet
Права sudo на ПК
```

Рекомендуемый firmware:

```text
artifacts/24.10.4-zapret-luci/openwrt-24.10.4-ath79-generic-tplink_archer-c6-v2-squashfs-factory.bin
```

Для уже установленного OpenWrt использовать:

```text
artifacts/24.10.4-zapret-luci/openwrt-24.10.4-ath79-generic-tplink_archer-c6-v2-squashfs-sysupgrade.bin
```

## 2. Проверить firmware

Из корня репозитория:

```sh
cd /home/matodor/openwrt-builds/2026-06-24-openwrt-c6-v2-zapret
(cd artifacts/24.10.4-zapret-luci && sha256sum -c sha256sums)
```

Если проверяется только нужный файл:

```sh
sha256sum artifacts/24.10.4-zapret-luci/openwrt-24.10.4-ath79-generic-tplink_archer-c6-v2-squashfs-factory.bin
```

## 3. Найти Ethernet interface

Подключить кабель к Ethernet-адаптеру и посмотреть имя интерфейса:

```sh
ip link
```

Примеры имен:

```text
enp5s0f3u1u1
enx...
eth0
```

Wi-Fi на ПК может оставаться включенным для интернета. Для recovery важен именно Ethernet interface, к которому подключен роутер.

## 4. Подключить кабель

Для Archer C6 v2 в этой настройке recovery работал через WAN порт.

```text
ПК Ethernet -> WAN порт Archer C6 v2
```

Если bootloader виден, но TFTP request не идет, можно попробовать LAN1. В рабочем случае bootloader запрашивал файл:

```text
ArcherC6v2_tp_recovery.bin
```

и использовал адреса:

```text
router: 192.168.0.86
server: 192.168.0.66
```

## 5. Запустить TFTP recovery helper

Команда:

```sh
sudo ./recover-archer-c6-v2.sh --iface <ethernet-iface> --server-ip 192.168.0.66/24 --timeout 300
```

Пример:

```sh
sudo ./recover-archer-c6-v2.sh --iface enp5s0f3u1u1 --server-ip 192.168.0.66/24 --timeout 300
```

Скрипт:

```text
временно настраивает IP на Ethernet interface
поднимает dnsmasq TFTP
готовит recovery filename aliases
показывает только важные recovery events
```

Recovery filenames:

```text
ArcherC6v2_tp_recovery.bin
ArcherC6V2_tp_recovery.bin
tp_recovery.bin
```

## 6. Ввести роутер в recovery mode

Порядок:

1. Отключить питание роутера.
2. Зажать RESET.
3. Подать питание, не отпуская RESET.
4. Держать RESET примерно 10-15 секунд.
5. Отпустить RESET.
6. Смотреть вывод `recover-archer-c6-v2.sh`.

Успешный признак:

```text
RRQ "ArcherC6v2_tp_recovery.bin"
dnsmasq-tftp: sent ... ArcherC6v2_tp_recovery.bin to 192.168.0.86
STATUS: transfer_completed_or_in_progress
```

После transfer не выключать питание несколько минут. Роутер может мигать всеми индикаторами и перезагружаться.

## 7. Первый вход в OpenWrt

После прошивки подключиться к LAN порту роутера или к его Wi-Fi, если Wi-Fi уже включен в образе.

Открыть:

```text
http://192.168.1.1
```

или SSH:

```sh
ssh root@192.168.1.1
```

Сразу задать пароль root:

```sh
passwd
```

## 8. Установить локальные helper scripts

Из корня репозитория на ПК:

```sh
scp -O files/usr/bin/zapret-tool root@192.168.1.1:/usr/bin/zapret-tool
scp -O files/usr/bin/doh-ram root@192.168.1.1:/usr/bin/doh-ram
scp -O files/etc/init.d/doh-ram root@192.168.1.1:/etc/init.d/doh-ram
scp -O files/etc/init.d/zapret-tool root@192.168.1.1:/etc/init.d/zapret-tool
```

На роутере:

```sh
ssh root@192.168.1.1 '
chmod 755 /usr/bin/zapret-tool /usr/bin/doh-ram /etc/init.d/doh-ram /etc/init.d/zapret-tool
ash -n /usr/bin/zapret-tool
ash -n /usr/bin/doh-ram
'
```

## 9. Включить DoH в RAM

На Archer C6 v2 persistent overlay очень маленький, поэтому `https-dns-proxy` ставится в RAM.

```sh
ssh root@192.168.1.1 '
/etc/init.d/doh-ram enable
/etc/init.d/doh-ram start
/usr/bin/doh-ram status
'
```

Ожидаемо:

```text
running
server=127.0.0.1#5053
server=127.0.0.1#5054
```

## 10. Обновить списки и применить zapret strategy

```sh
ssh root@192.168.1.1 '
/etc/init.d/zapret-tool enable
zapret-tool flowseal update
zapret-tool flowseal ipset update
zapret-tool flowseal telegram-reset
zapret-tool flowseal hosts install
zapret-tool flowseal apply fs-fake-tls-auto-alt03
'
```

## 11. Проверить работу

```sh
ssh root@192.168.1.1 'zapret-tool status'
ssh root@192.168.1.1 'zapret-tool flowseal test'
ssh root@192.168.1.1 'zapret-tool test domain www.youtube.com'
ssh root@192.168.1.1 'zapret-tool test domain redirector.googlevideo.com'
ssh root@192.168.1.1 'zapret-tool test domain web.telegram.org'
ssh root@192.168.1.1 'zapret-tool test domain api.telegram.org'
ssh root@192.168.1.1 'zapret-tool test domain t.me'
```

Проверить autostart:

```sh
ssh root@192.168.1.1 '
/etc/init.d/zapret enabled && echo zapret=yes
/etc/init.d/doh-ram enabled && echo doh-ram=yes
/etc/init.d/zapret-tool enabled && echo zapret-tool=yes
'
```

## 12. Клиентские устройства

После включения DoH/zapret:

```text
переподключить клиент к Wi-Fi/LAN
перезапустить браузер
отключить VPN на клиенте для проверки
выключить browser Secure DNS или поставить "current provider"
```

Если YouTube страница открывается, но видео не грузится, проверить QUIC:

```text
Chrome/Edge: chrome://flags/#enable-quic -> Disabled -> Relaunch
```

Если Telegram Desktop/media тормозит, домены могут не решить проблему полностью. Для native Telegram media часто нужен MTProto proxy, WARP или отдельный VPN.

## 13. Обновление уже установленного OpenWrt

Если OpenWrt уже установлен, использовать `sysupgrade.bin`:

```sh
scp -O artifacts/24.10.4-zapret-luci/openwrt-24.10.4-ath79-generic-tplink_archer-c6-v2-squashfs-sysupgrade.bin root@192.168.1.1:/tmp/
ssh root@192.168.1.1 'sysupgrade /tmp/openwrt-24.10.4-ath79-generic-tplink_archer-c6-v2-squashfs-sysupgrade.bin'
```

Для чистой переустановки без сохранения конфигов:

```sh
ssh root@192.168.1.1 'sysupgrade -n /tmp/openwrt-24.10.4-ath79-generic-tplink_archer-c6-v2-squashfs-sysupgrade.bin'
```

После `sysupgrade -n` повторить шаги с первого входа, установкой helper scripts и применением zapret strategy.
