# Security

## Sensitive files (do not commit)

The following are ignored via `.gitignore` and must never be committed:

- `config.json` – Dirigera Hub IP and token
- `cert.pem`, `key.pem` – TLS certificate and private key for the bridge
- `SmartLightApp/developer_key.pem`, `SmartLightApp/developer_key.der` – Garmin Connect IQ developer keys

Use `config.example.json` as a template for local configuration.

## If a key or token was exposed

If any of the above (or similar secrets) were ever pushed to a remote repository:

1. **Treat them as compromised.** Assume they have been seen or copied.
2. **Rotate everything that was exposed:**
   - **Dirigera:** Run `python bridge.py setup` again to obtain a new token (you may need to remove the app/hub pairing in the IKEA app first).
   - **TLS:** Generate new `cert.pem` and `key.pem` (e.g. with `openssl`) and replace the old ones.
   - **Garmin:** Generate new developer keys in the Garmin Connect IQ Developer Program and replace the old keys in `SmartLightApp/`.
3. **Stop tracking secrets in git:** Ensure `.gitignore` is in place and that sensitive files are removed from the index (as in the “Fix secret leak” commit). Future pushes will no longer include those files; old history may still contain them, so rotation is essential.
