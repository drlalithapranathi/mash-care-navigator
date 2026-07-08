# Proxy basic-auth (#17)

The reference `nginx-proxy` applies HTTP basic auth to a vhost when a file named
**exactly** `$VIRTUAL_HOST` exists in this directory. With no such file, no auth
is applied (non-breaking default).

To gate the instance behind basic auth until a pilot has real access control
(VPN / IP allowlist):

```sh
cd openmrs/deploy
htpasswd -Bc htpasswd/$VIRTUAL_HOST pilotuser     # creates a bcrypt entry
# (omit -c to add more users)
docker compose up -d nginx-proxy                  # picks the file up
```

The credential files are gitignored — only this README is committed. Basic auth
is a stopgap; prefer a VPN or IP allowlist for anything holding real data, and
never rely on it in place of rotating the admin account (see
`openmrs/scripts/harden-instance.sh`).
