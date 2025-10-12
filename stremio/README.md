# Stremio server

This module allow you to run a stremio service and stremio Web UI.
It is based on [stremio docker from tsaridas][stremio-docker].

## Importing/configuring the default Web UI settings

Stremio's web app stores settings in the browser's local storage. You can pre-configure these settings by editing the `local_storage` option.
To import your actual from [Stremio Web][stremio-web] or [your Web UI][webui], open the developper tools and type in the console the following code to copy your configuration in your clipboard.

```js
let res = {}
for (let i = 0; i < localStorage.length; i++) {
  const key = localStorage.key(i);
  const value = localStorage.getItem(key);
  try {
    const parsed = JSON.parse(value);
    // Overwrite with parsed version if valid JSON
    res[key] = parsed;
  } catch (e) {
    // Value is not JSON, keep as string
    res[key] = value;
  }
}
copy(JSON.stringify(res))
```
Then paste your clipboard content into the `localStorage` option.
Now, all the devices accessing [your Web UI][webui] for the first time should have all settings configured identically (account and Trakt included).


## VPN setup

This addon supports routing internet traffic through an OpenVPN connection while maintaining local network access. This is useful for privacy or accessing geo-restricted content.
You need an OpenVPN configuration file from your VPN provider. Most providers (NordVPN, ExpressVPN, ProtonVPN, etc.) provide .ovpn files.

```sh
# 1. Create VPN directory
mkdir -p /addon_configs/stremio_server/vpn

# 2. Copy VPN config
cp your-vpn.ovpn /addon_configs/stremio_server/vpn/vpn.ovpn

# 3. (Optional) Add credentials
echo "username" > /addon_configs/stremio_server/vpn/auth.txt
echo "password" >> /addon_configs/stremio_server/vpn/auth.txt

# 4. Restart addon
```

[stremio-docker]: https://github.com/tsaridas/stremio-docker/
[stremio-web]: https://web.stremio.com/
[webui]: https://homeassistant.local:8080/