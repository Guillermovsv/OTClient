# Delyriumz Tibia 15.25 server instructions (Linux)

## Required native-client spell compatibility update

The compiled native Tibia 15.25 client requires the Monk-safe Canary patch in:

```text
client-updates/tibia-15.25-monk-safe/canary-tibia-15.25-monk-safe.patch
```

This patch does not change spell effects or canonical server IDs. It keeps all
Monk/Exalted Monk spell records intact, omits custom stance IDs `299` through
`304` only from the native 15.25 spell-list packet, and presents Forked Glacier
server ID `305` through its native record at ID `299`. OTClient and OTCv8
continue receiving canonical IDs `299` through `305`.

Apply and rebuild Canary using the dedicated instructions in:

```text
client-updates/tibia-15.25-monk-safe/README-SERVER.md
```

Do not deploy the superseded approach that mapped custom stances onto IDs
`274`-`281`; those are real Monk spells.

These instructions are for the official Tibia 15.25 client patched for
Delyriumz. The client already reaches the character list. The remaining path
is the raw game connection from the selected character to Canary.

## Required endpoints

```text
HTTP login: http://185.164.110.4:8088/login
Game host:  185.164.110.4
Game TCP:   7172
Protocol:   1525
```

The HTTP login response must advertise `185.164.110.4` (or
`game.delyriumzot.com`) and port `7172` for every world. It must not advertise
`127.0.0.1`, `localhost`, a container name, a private Docker address, `7171`,
`8088`, or `9090` as the game endpoint.

## Public and private RSA keys

The public modulus embedded in the client is committed as:

```text
client-updates/tibia-15.25-client-rsa-public.txt
```

The matching private key is intentionally not stored in this client
repository. On the trusted workstation it is located at:

```text
C:\Users\guill\Documents\OT Client\tibia-15.25-server-rsa-private.xml
```

Convert it to `key.pem` before transferring it to Linux. Never upload the XML
or PEM key to GitHub, MyAAC, the client ZIP, or a public object store.

## Convert XML RSA to key.pem on Windows

Run this locally in PowerShell:

```powershell
$source = "C:\Users\guill\Documents\OT Client\tibia-15.25-server-rsa-private.xml"
$xml = [xml](Get-Content -LiteralPath $source -Raw)
$rsa = [System.Security.Cryptography.RSA]::Create()
$p = [System.Security.Cryptography.RSAParameters]::new()
$p.Modulus = [Convert]::FromBase64String($xml.RSAKeyValue.Modulus)
$p.Exponent = [Convert]::FromBase64String($xml.RSAKeyValue.Exponent)
$p.P = [Convert]::FromBase64String($xml.RSAKeyValue.P)
$p.Q = [Convert]::FromBase64String($xml.RSAKeyValue.Q)
$p.DP = [Convert]::FromBase64String($xml.RSAKeyValue.DP)
$p.DQ = [Convert]::FromBase64String($xml.RSAKeyValue.DQ)
$p.InverseQ = [Convert]::FromBase64String($xml.RSAKeyValue.InverseQ)
$p.D = [Convert]::FromBase64String($xml.RSAKeyValue.D)
$rsa.ImportParameters($p)
[IO.File]::WriteAllText("$PWD\key.pem", $rsa.ExportRSAPrivateKeyPem(), [Text.UTF8Encoding]::new($false))
```

## Transfer the private key securely

Replace the SSH host/user and server path with the real values:

```powershell
scp .\key.pem root@185.164.110.4:/opt/delyriumz/secrets/key.pem
```

On Linux:

```bash
sudo chown root:root /opt/delyriumz/secrets/key.pem
sudo chmod 600 /opt/delyriumz/secrets/key.pem
```

Mount or copy this file to the path from which Canary loads `key.pem`. If
Canary expects it in its working directory, it must be beside `config.lua` and
the Canary executable inside the container.

Example Docker Compose secret mount:

```yaml
services:
  canary:
    ports:
      - "7172:7172/tcp"
    volumes:
      - /opt/delyriumz/secrets/key.pem:/app/key.pem:ro
```

Adjust `/app` to Canary's real working directory.

## Publish the game port

Port `7172` is raw Tibia TCP. Publish it directly; do not send it through an
HTTP-only Traefik router.

For UFW:

```bash
sudo ufw allow 7172/tcp
sudo ufw reload
```

Confirm Linux is listening:

```bash
sudo ss -lntp | grep ':7172'
```

Confirm Docker publishes it:

```bash
docker ps --format 'table {{.Names}}\t{{.Ports}}'
```

Expected publication:

```text
0.0.0.0:7172->7172/tcp
```

## Verify the login response

The selected world returned by the HTTP login service must contain the public
game address and port:

```text
address = 185.164.110.4
port    = 7172
```

The login service may communicate with Canary over gRPC `9090` internally,
but `9090` must never be returned to the client as its game port.

## Restart and inspect logs

```bash
docker compose restart canary login-server
docker compose logs --tail=200 canary
docker compose logs --tail=200 login-server
```

After selecting a character, confirm that Canary logs the incoming TCP
connection. If TCP connects but RSA/session validation fails, verify that the
running container loaded the newly deployed `key.pem` and that both services
agree on protocol `1525`.

## External checks

From another machine:

```bash
nc -vz 185.164.110.4 8088
nc -vz 185.164.110.4 7172
```

Both ports must be reachable. Reaching the character list proves only the
HTTP login step; successful character entry additionally requires the world
address, raw TCP publication, matching RSA private key, session validation,
and protocol 1525.
