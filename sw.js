const C='akharta-bb5799db3f3c';
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