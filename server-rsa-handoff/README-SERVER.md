# Delyriumz Tibia 15.25 — configuración RSA del servidor

## Archivos del cliente

El cliente modificado usa:

```text
http://game.delyriumzot.com:8088/login
```

La RSA pública correspondiente está en `tibia-15.25-client-rsa-public.txt`.
El servidor debe usar la clave privada que corresponde a esa RSA pública.

## TFS / servidor OT

1. Convierte `tibia-15.25-server-rsa-private.xml` a `key.pem` con:

   ```powershell
   .\convert-rsa-xml-to-key-pem.ps1 `
     -PrivateXml "C:\ruta\tibia-15.25-server-rsa-private.xml" `
     -ServerRoot "C:\ruta\del\servidor"
   ```

2. Confirma que el resultado sea:

   ```text
   C:\ruta\del\servidor\key.pem
   ```

3. `key.pem` debe estar en la raíz del servidor, junto a `config.lua` y el
   ejecutable del servidor. No debe llamarse `key.pem.txt`.

4. Reinicia el login server y el game server.

5. Prueba con:

   ```text
   tibia-client-15.25.0a00a0 (1)\bin\client-delyriumz-15.25.exe
   ```

## Parámetros de red

```text
Login URL:  http://game.delyriumzot.com:8088/login
Game port: 7172
Protocol:  15.25
```

## Seguridad

Nunca subas `tibia-15.25-server-rsa-private.xml` ni `key.pem` a GitHub, al
cliente, a un ZIP público o a MyAAC. Guarda la clave privada solamente en el
servidor y en una copia segura.
