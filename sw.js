const CACHE_NAME = "metrico-cache-v2.44.1";
const ASSETS = [
  "./", "./index.html", "./manifest.json", "./icons/icon-192.png", "./icons/icon-512.png",
  "./lib/react.production.min.js", "./lib/react-dom.production.min.js",
  "./lib/babel.min.js", "./lib/tailwind.js", "./lib/supabase.js",
  "./lib/leaflet.js", "./lib/leaflet.css", "./lib/apexcharts.min.js",
  "./fonts/Vazirmatn.woff2", "./logo.png"
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS)).catch(() => {})
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

// Network-first: always try to get the latest version when online.
// Falls back to cache only when there's no internet connection.
self.addEventListener("fetch", (event) => {
  event.respondWith(
    fetch(event.request)
      .then((response) => {
        if (response && response.status === 200) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
        }
        return response;
      })
      .catch(() => caches.match(event.request))
  );
});
