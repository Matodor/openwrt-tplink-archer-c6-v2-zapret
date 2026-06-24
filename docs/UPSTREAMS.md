# Upstreams and update workflow

Этот проект не является самостоятельным форком zapret. Он собирает минимальный набор скриптов и настроек под TP-Link Archer C6 v2 с очень маленьким overlay.

## Source repositories

### zapret / OpenWrt packages

```text
https://github.com/bol-van/zapret
https://github.com/remittor/zapret-openwrt
https://github.com/remittor/zapret-openwrt/releases
https://github.com/remittor/zapret-openwrt/wiki
```

Назначение:

```text
bol-van/zapret              upstream zapret/nfqws
remittor/zapret-openwrt     OpenWrt packages, LuCI app, wiki, release APK/IPK assets
```

Текущие source packages сохранены в:

```text
source-apks/
```

При обновлении zapret сначала проверить свежий release в `remittor/zapret-openwrt`, скачать APK/IPK для `mips_24kc`, затем обновить `source-apks/` и пересобрать image.

### Flowseal strategies and lists

```text
https://github.com/Flowseal/zapret-discord-youtube
```

Используемые источники:

```text
https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/lists/list-general.txt
https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/lists/list-google.txt
https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/lists/list-exclude.txt
https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/.service/hosts
https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/.service/ipset-service.txt
https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/utils/targets.txt
https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/bin/quic_initial_dbankcloud_ru.bin
```

Где брать стратегии:

```text
general.bat
general (ALT).bat
general (ALT2).bat ... general (ALT12).bat
general (SIMPLE FAKE).bat
general (SIMPLE FAKE ALT).bat
general (SIMPLE FAKE ALT2).bat
general (FAKE TLS AUTO).bat
general (FAKE TLS AUTO ALT).bat
general (FAKE TLS AUTO ALT2).bat
general (FAKE TLS AUTO ALT3).bat
```

Важно: Flowseal стратегии написаны для Windows `winws.exe`; в `zapret-tool` они вручную адаптированы под OpenWrt `nfqws`. Нельзя просто скопировать `.bat` целиком на роутер.

Текущая лучшая стратегия на роутере:

```text
fs-fake-tls-auto-alt03
```

Соответствует Flowseal `general (FAKE TLS AUTO ALT3).bat`, но с OpenWrt-адаптациями:

```text
nfqws вместо winws.exe
OpenWrt hostlist paths
Google hostlists добавлены в UDP/443 block
часть ipset/game blocks урезана из-за RAM/flash limits
```

### Flowseal Telegram issue

```text
https://github.com/Flowseal/zapret-discord-youtube/issues/5820
```

Использовано для Telegram seed list и понимания ограничения: домены помогают web/API и hosts pinning, но сами по себе не гарантируют ускорение native Telegram media.

### Zapret-Manager

```text
https://github.com/StressOzz/Zapret-Manager
https://raw.githubusercontent.com/StressOzz/Zapret-Manager/refs/heads/main/zapret-hosts-user-exclude.txt
https://github.com/StressOzz/Zapret-Manager/blob/main/Strategies.md
https://github.com/StressOzz/Zapret-Manager/blob/main/Strategies_For_Youtube.md
```

Назначение:

```text
exclude list source
идеи меню/диагностики
справочные стратегии v1-v9 и YouTube strategies
DoH UX ideas
```

Zapret-Manager сам по себе тяжелее, чем нужно для Archer C6 v2. Для этого проекта берем идеи и отдельные списки, но не ставим менеджер целиком.

### zapret4rocket

```text
https://github.com/IndeecFOX/zapret4rocket
https://raw.githubusercontent.com/IndeecFOX/z4r/4/z4r
```

Назначение:

```text
идеи auto mode
идеи user test flow
reference для подбора стратегий
```

Не запускать напрямую на Archer C6 v2 без предварительной проверки: скрипт рассчитан на более широкий набор систем, может поставить лишние зависимости и занять overlay.

## Current local integration points

`zapret-tool` задает upstream defaults:

```text
FLOWSEAL_BASE=https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main
EXCLUDE_URL=https://raw.githubusercontent.com/StressOzz/Zapret-Manager/refs/heads/main/zapret-hosts-user-exclude.txt
```

Можно временно переопределить источники:

```sh
ZTOOL_FLOWSEAL_BASE=https://raw.githubusercontent.com/<owner>/<repo>/<branch> zapret-tool flowseal update
ZTOOL_EXCLUDE_URL=https://example.com/zapret-hosts-user-exclude.txt zapret-tool update-exclude
```

## Updating lists on the router

Обычное обновление списков без смены кода:

```sh
ssh root@192.168.1.1 '
zapret-tool flowseal update
zapret-tool flowseal ipset update
zapret-tool flowseal telegram-reset
zapret-tool flowseal hosts install
zapret-tool flowseal apply fs-fake-tls-auto-alt03
'
```

Проверка:

```sh
ssh root@192.168.1.1 'zapret-tool flowseal test'
ssh root@192.168.1.1 'zapret-tool test domain www.youtube.com'
ssh root@192.168.1.1 'zapret-tool test domain web.telegram.org'
```

## Updating `zapret-tool` code

Workflow:

1. Изучить upstream `.bat` или список.
2. Добавить/изменить тест в `tests/test-zapret-tool.sh`.
3. Запустить тест и убедиться, что он падает по ожидаемой причине.
4. Изменить `files/usr/bin/zapret-tool`.
5. Проверить локально:

```sh
sh -n files/usr/bin/zapret-tool
sh tests/test-zapret-tool.sh
```

6. Скопировать на роутер:

```sh
scp -O files/usr/bin/zapret-tool root@192.168.1.1:/usr/bin/zapret-tool
```

7. Проверить и применить на роутере:

```sh
ssh root@192.168.1.1 '
chmod 755 /usr/bin/zapret-tool
ash -n /usr/bin/zapret-tool
zapret-tool flowseal apply fs-fake-tls-auto-alt03
zapret-tool flowseal test
'
```

8. Если менялись init-скрипты, скопировать их отдельно и проверить `enable/status`.

## Adding a new Flowseal strategy

Rules:

```text
Do not paste .bat blindly.
Keep only blocks that make sense for OpenWrt nfqws.
Prefer hostlists over large ipsets unless ipset is required.
Remember Archer C6 v2 overlay is tiny.
Keep runtime ipset in /tmp, not in /overlay.
```

Implementation checklist:

1. Скачать или открыть upstream `.bat`.
2. Перенести `--filter-*`, `--dpi-desync-*`, `--hostlist*`, `--ipset*` blocks в генератор `zapret-tool`.
3. Добавить имя стратегии в `flowseal_strategy_names`.
4. Добавить case в `flowseal_upstream_strategy` или отдельную `strategy_*` функцию.
5. Добавить regression test на ожидаемые ключевые flags.
6. Проверить на роутере через `zapret-tool flowseal try` или `zapret-tool flowseal auto`.

## Rebuilding firmware

При обновлении packages или overlay:

```sh
./build-image.sh
```

Перед прошивкой проверить:

```sh
sha256sum artifacts/<build>/*.bin
du -h artifacts/<build>/*.bin
```

Для уже установленного OpenWrt использовать `sysupgrade.bin`. Для TFTP recovery/stock path использовать `factory.bin`.
