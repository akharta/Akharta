# Regenera la carpeta pwa/ (lista para subir a un hosting https) a partir de akharta.html.
# Uso: clic derecho > Ejecutar con PowerShell, o: powershell -ExecutionPolicy Bypass -File build-pwa.ps1
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$pwa = Join-Path $root 'pwa'
New-Item -ItemType Directory -Force $pwa | Out-Null

# 1. La app: copia exacta del archivo único
Copy-Item (Join-Path $root 'akharta.html') (Join-Path $pwa 'index.html') -Force

# 2. Service worker con versión de caché ligada al contenido:
#    al subir una versión nueva de la app, la caché vieja se invalida sola.
$hash = (Get-FileHash (Join-Path $pwa 'index.html') -Algorithm SHA256).Hash.Substring(0, 12).ToLower()
$sw = @"
const C='akharta-$hash';
const ASSETS=['./','./index.html','./manifest.webmanifest','./icon-192.png','./icon-512.png'];
self.addEventListener('install',e=>{
  e.waitUntil(caches.open(C).then(c=>c.addAll(ASSETS)).then(()=>self.skipWaiting()));
});
self.addEventListener('activate',e=>{
  e.waitUntil(caches.keys()
    .then(ks=>Promise.all(ks.filter(k=>k!==C).map(k=>caches.delete(k))))
    .then(()=>self.clients.claim()));
});
// Red primero para el documento y el sw: si hay conexion la app siempre esta al dia;
// sin conexion, se sirve la copia en cache. Los iconos van cache primero.
self.addEventListener('fetch',e=>{
  if(e.request.method!=='GET')return;
  const isDoc=e.request.mode==='navigate'||e.request.destination==='document'||e.request.destination==='';
  if(isDoc){
    e.respondWith(
      fetch(e.request)
        .then(r=>{const cp=r.clone();caches.open(C).then(c=>c.put('./index.html',cp));return r})
        .catch(()=>caches.match(e.request,{ignoreSearch:true}).then(r=>r||caches.match('./index.html')))
    );
    return;
  }
  e.respondWith(caches.match(e.request,{ignoreSearch:true}).then(r=>r||fetch(e.request)));
});
"@
[IO.File]::WriteAllText((Join-Path $pwa 'sw.js'), $sw, (New-Object Text.UTF8Encoding($false)))

# 3. Manifest
$manifest = @"
{
  "name": "Akharta — Taller de novela",
  "short_name": "Akharta",
  "description": "Taller personal para escribir la saga Akharta. Offline y sin cuentas.",
  "lang": "es",
  "start_url": "./",
  "scope": "./",
  "display": "standalone",
  "background_color": "#0C0A09",
  "theme_color": "#0C0A09",
  "icons": [
    { "src": "icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any" },
    { "src": "icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
  ]
}
"@
[IO.File]::WriteAllText((Join-Path $pwa 'manifest.webmanifest'), $manifest, (New-Object Text.UTF8Encoding($false)))

# 4. Iconos: solo se generan si no existen (desde el PNG original del logo)
$srcPng = Get-ChildItem $root -Filter 'braisveredas_A_logo*.png' | Select-Object -First 1
if ($srcPng -and -not (Test-Path (Join-Path $pwa 'icon-512.png'))) {
  Add-Type -AssemblyName System.Drawing
  $img = [System.Drawing.Image]::FromFile($srcPng.FullName)
  foreach ($s in 512, 192) {
    $bmp = New-Object System.Drawing.Bitmap $s, $s
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($img, 0, 0, $s, $s)
    $g.Dispose()
    $bmp.Save((Join-Path $pwa "icon-$s.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
  }
  $img.Dispose()
}
Write-Output "pwa/ regenerada (cache akharta-$hash)"
