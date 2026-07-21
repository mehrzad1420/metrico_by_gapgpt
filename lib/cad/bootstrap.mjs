import { LibreDwg, Dwg_File_Type } from "./libredwg-web.js";

const wasmBase = new URL("../wasm/", import.meta.url).href;

try {
  const libredwg = await LibreDwg.create(wasmBase);
  window.__metricoLibreDwg = { libredwg, Dwg_File_Type, ready: true, error: null };
} catch (err) {
  window.__metricoLibreDwg = {
    ready: false,
    error: err?.message || String(err),
  };
}

window.dispatchEvent(new Event("metrico-libredwg-ready"));
