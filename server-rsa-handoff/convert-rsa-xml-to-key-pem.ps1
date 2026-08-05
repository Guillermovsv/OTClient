param(
    [Parameter(Mandatory = $true)] [string] $PrivateXml,
    [Parameter(Mandatory = $true)] [string] $ServerRoot
)

$ErrorActionPreference = 'Stop'
$xml = [xml](Get-Content -LiteralPath $PrivateXml -Raw)
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

$target = Join-Path (Resolve-Path -LiteralPath $ServerRoot) 'key.pem'
[IO.File]::WriteAllText($target, $rsa.ExportRSAPrivateKeyPem(), [Text.UTF8Encoding]::new($false))
Write-Output "Created $target"
