# Delyriumz 15.25 — diagnóstico de conectividad

## Estado observado

El cliente oficial 15.25 está configurado para usar:

```text
Login URL:  http://game.delyriumzot.com:8088/login
Game port: 7172/TCP
Protocol:  1525
```

La prueba externa mostró:

```text
game.delyriumzot.com:8088 — accesible
game.delyriumzot.com:7172 — connection refused
```

Esto indica que el login HTTP es alcanzable, pero el game server no está
escuchando públicamente en TCP 7172, está limitado a localhost, o el firewall
del servidor/VPS está bloqueando el puerto. No es un error de RSA todavía: la
conexión TCP falla antes de la negociación RSA.

## Comprobación en Windows Server

Verifica que el proceso esté escuchando:

```powershell
Get-NetTCPConnection -LocalPort 7172 -State Listen
```

Si no aparece ninguna línea, inicia el game server o cambia su configuración
para escuchar en `0.0.0.0:7172` en lugar de `127.0.0.1:7172`.

Permite el puerto en Windows Firewall:

```powershell
New-NetFirewallRule -DisplayName "Delyriumz Game 7172" `
  -Direction Inbound -Protocol TCP -LocalPort 7172 -Action Allow
```

## Comprobación en Linux

```bash
sudo ss -lntp | grep 7172
sudo ufw allow 7172/tcp
sudo ufw reload
```

El proceso debe mostrar `0.0.0.0:7172` o la IP pública/privada correcta, no
solamente `127.0.0.1:7172`.

## NAT, VPS y proveedor

Si el servidor está detrás de un router, crea una redirección TCP:

```text
Puerto externo 7172 -> IP interna del servidor:7172
```

Si es un VPS, abre TCP 7172 también en el firewall del proveedor/cloud panel.

## Prueba desde el PC del jugador

```powershell
Test-NetConnection game.delyriumzot.com -Port 7172
```

El resultado correcto es:

```text
TcpTestSucceeded : True
```

Después de abrir el puerto, reinicia el login/game server y prueba de nuevo
con `client-delyriumz-15.25.exe`.
