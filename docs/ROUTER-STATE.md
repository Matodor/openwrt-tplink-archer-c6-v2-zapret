# Router State

Снимок состояния после настройки.

## System

```text
DISTRIB_ID='OpenWrt'
DISTRIB_RELEASE='24.10.4'
DISTRIB_REVISION='r28959-29397011cc'
DISTRIB_TARGET='ath79/generic'
DISTRIB_ARCH='mips_24kc'
DISTRIB_DESCRIPTION='OpenWrt 24.10.4 r28959-29397011cc'
Kernel: 6.6.110
Model: TP-Link Archer C6 v2 (EU/RU/JP)
Board: tplink,archer-c6-v2
Rootfs: squashfs
```

## Storage

```text
/overlay: 448.0K total, 280.0K used, 168.0K free
/tmp:      59.2M total, 3.0M used, 56.2M free
```

`/tmp` находится в RAM. Он подходит для временных списков, ipset и RAM install `https-dns-proxy`, но не решает нехватку persistent overlay.

## Network

```text
LAN IPv4: 192.168.1.1/24
DHCPv4: enabled
DHCPv6: disabled
RA: disabled
NDP: disabled
LAN delegate: 0
```

LAN IPv6 выключен намеренно: WAN IPv6 не был настроен, а клиенты могли получать ULA/AAAA и обходить IPv4 zapret.

## DNS over HTTPS

```text
doh-ram: running, enabled
dnsmasq noresolv=1
dnsmasq servers:
  127.0.0.1#5053
  127.0.0.1#5054
```

Проверка:

```sh
ssh root@192.168.1.1 '/usr/bin/doh-ram status'
ssh root@192.168.1.1 'nslookup www.youtube.com 127.0.0.1'
```

## zapret

```text
Service: enabled
Current strategy: ZTOOL_fs-fake-tls-auto-alt03
```

Первый UDP/443 block должен содержать Google hostlists:

```text
--filter-udp=443
--hostlist=/opt/zapret/ipset/flowseal-google.txt
--hostlist=/opt/zapret/ipset/zapret-hosts-google.txt
--hostlist=/opt/zapret/ipset/flowseal-general.txt
--hostlist=/opt/zapret/ipset/zapret-hosts-user.txt
--hostlist=/opt/zapret/ipset/zapret-hosts-telegram.txt
```

Проверка:

```sh
ssh root@192.168.1.1 'uci -q get zapret.config.NFQWS_OPT | sed -n "1,14p"'
ssh root@192.168.1.1 'ps w | grep "[n]fqws"'
```

## Flowseal hosts

Flowseal hosts block установлен в `/etc/hosts`:

```text
# ZTOOL-FLOWSEAL-BEGIN
# ZTOOL-FLOWSEAL-END
```

Он нужен для Telegram web/API pinning на `149.154.167.220`.

Проверка:

```sh
ssh root@192.168.1.1 'grep -n "ZTOOL-FLOWSEAL" /etc/hosts'
ssh root@192.168.1.1 'zapret-tool test domain web.telegram.org'
ssh root@192.168.1.1 'zapret-tool test domain api.telegram.org'
ssh root@192.168.1.1 'zapret-tool test domain t.me'
```

Удалить hosts block:

```sh
ssh root@192.168.1.1 'zapret-tool flowseal hosts remove'
```

## Backups on router

Перед отключением LAN IPv6 были созданы:

```text
/etc/config/network.ztool-ipv6.bak.20260624-133644
/etc/config/dhcp.ztool-ipv6.bak.20260624-133644
```

Также `zapret-tool` сохраняет backup zapret config:

```text
/etc/config/zapret.ztool.bak
```
