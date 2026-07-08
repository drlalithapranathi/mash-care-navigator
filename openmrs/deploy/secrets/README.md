# Deploy secrets

Docker reads the database passwords from files here instead of container
environment variables, so they never appear in `docker inspect`, the process
list, or `/proc/<pid>/environ` (issue #33).

Before the first `docker compose up`, create the two secret files from the
templates and lock them down:

```sh
cd openmrs/deploy
cp secrets/mysql_root_password.example secrets/mysql_root_password
cp secrets/mysql_password.example     secrets/mysql_password
# replace the placeholder contents with real, distinct strong passwords, then:
chmod 600 secrets/mysql_root_password secrets/mysql_password
```

- `mysql_password` must match the OpenMRS DB user's password — the app reads the
  same file (`DB_PASSWORD` is injected from it by the openmrs entrypoint).
- The real `mysql_root_password` / `mysql_password` files are gitignored; only the
  `*.example` templates are committed.
- A trailing newline is fine — the MySQL image strips it.
