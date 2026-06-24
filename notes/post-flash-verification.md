# Post-Flash Verification

1. SSH into the router:

```sh
ssh root@192.168.1.1
```

2. Confirm curl is still built in:

```sh
curl --version
```

3. Confirm zapret packages are present:

```sh
apk info | grep -E '^(zapret|luci-app-zapret)$'
```

4. Confirm the web-management stack is still present:

```sh
apk info | grep -E '^(luci|luci-ssl|rpcd|rpcd-mod-rrdns|uhttpd|uhttpd-mod-ubus)$'
```

5. Confirm the zapret init script exists:

```sh
/etc/init.d/zapret enabled || /etc/init.d/zapret status
```
