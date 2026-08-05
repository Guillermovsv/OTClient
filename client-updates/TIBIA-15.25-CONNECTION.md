# Tibia 15.25 connection settings

The Delyriumz Tibia 15.25 client uses two separate connections:

```text
Login HTTP: http://game.delyriumzot.com:8088/login
Game TCP:   game.delyriumzot.com:7172
Protocol:   15.25
```

The client first sends the login request to port `8088`. The login response
must advertise `game.delyriumzot.com` and port `7172`; the client then opens a
direct TCP connection to Canary on that game port.

## Configuration used by our OTC build

The Delyriumz OTC build uses this exact `Servers_init` entry in `init.lua`:

```lua
["http://game.delyriumzot.com:8088/login"] = {
    port = 7172,
    protocol = 1525,
    httpLogin = true,
    useAuthenticator = false
}
```

The `port = 7172` value is the configured game-world port. Because the host is
an HTTP URL, `modules/client_entergame/entergame.lua` extracts `8088` from the
URL and uses it for the HTTP login request. After character selection, the
world entry returned by `login-server` directs the OTC to Canary on TCP port
`7172`.

Therefore, the required game forwarding rule is:

```text
public 7172/TCP -> Canary container 7172/TCP
```

Do not forward the OTC game connection to `7171`, `8088`, or `9090`.

## Proxy requirements

Dokploy/Traefik may proxy the HTTP login endpoint on port `8088`, but the
Tibia game protocol on port `7172` is raw TCP and must not be routed through a
normal HTTP proxy. Docker/Dokploy must publish TCP port `7172` directly to the
Canary container.

If Cloudflare manages the hostname, the DNS record used for the game
connection must be **DNS only** (grey cloud). Cloudflare's standard HTTP proxy
does not forward the Tibia TCP protocol on port `7172`.

Related server ports are:

- `7171`: Canary's legacy/native login TCP port; this patched client uses the
  HTTP login service instead.
- `7172`: game-world TCP connection used after character selection.
- `7173`: Canary status protocol.
- `9090`: login-server gRPC; it is not the client's game connection.

Private RSA key installation belongs exclusively in the private OTServer
repository and deployment secret store. Never add private key material to this
client repository.
