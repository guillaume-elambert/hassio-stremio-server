## Configuring the default WEB UI settings

<!-- Your webui should be a link to webui, defined at the bottom of the README -->
Go to [your webui][webui]

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
copy(res)
```

[webui]: https://homeassistant.local:8080/