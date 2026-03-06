# 🛡️ Normas de Contribución: Arquitectura Aegis OS (Zero-Panic Policy)

¡Bienvenido al Ecosistema Aegis! Si deseas contribuir al Kernel (Rust), al Interceptor (Python) o al Shell (React/TS), este documento dicta **LA LEY**. Aegis no acepta código "que funcione por casualidad", exigimos software mantenible, inescrutable y resiliente a nivel de Producción SRE (*Site Reliability Engineering*).

---

## 🛑 Regla 1: Protocolo Zero-Panic (Rust Core)

Todo tu código en el Ecosistema `Aegis-ANK` será abortado instantáneamente si incluye:

- **`.unwrap()` o `.expect()`:** Están estrictamente **PROHIBIDOS** en variables no testeadas en tiempo productivo. Debes usar propagación `Result` con la librería `anyhow` o `thiserror`. Mapea cada error explícitamente y transpórtalo hacia arriba a través del Call Stack. El Aegis Neural Kernel nunca debe crashear por culpa de un fallo lógico imprevisto.
- **Race Conditions Indocumentadas:** Si usas `Arc`, `RwLock`, `Mutex` o canales de Tokio, DEBES dejar un comentario (`/// Docs`) explicando por qué tu arquitectura evita un *Deadlock* y describiendo en qué orden de precedencias obtienen tú código los bloques mutex de las variables atómicas compartidas.
- **No In-Place Mockups (`// TODO` eternos):** Si dejas lógica inconclusa, abre tu PR (Pull Request) como **Draft**. Tus Pull Requests definitivos deben estar pulidos y acompañados por Test Suites completos bajo `#[cfg(test)]`. Si la función requiere más tiempo, repártela en tickets más granulares y propónelos como issues.

---

## 🏛️ Regla 2: Arquitectura por RFC (Request For Comments)

El Diseño de Patrones y el control del *Cognitive Scheduler* de Ring 0 pesan muchísimo más que unas docenas de líneas de código bien escritas.

- Nadie crea un Pull Request (PR) incursionando sobre dependencias pesadas, inyectando bibliotecas enteras en `Cargo.toml`, ni rehaciendo `structs` fundamentales de Memoria sin haber creado previamente un **Issue (RFC)** en nuestro repositorio.
- Dentro del *Issue*, debes fundamentar el costo del cómputo que requieres agregar o mapear, cómo impacta los contrapesos de VRAM frente a las bibliotecas de LLM, y recibir el *LGTM* de un mantenedor del proyecto para comenzar a programar sobre ello.
- Todo hilo conversacional de PR debe limitarse a la implementación del RFC y debatir el cumplimiento SRE, la legibilidad del código, y la limpieza de imports. No rediseñamos proyectos enteros directamente sobre los PRs. No perdamos nuestro tiempo.

---

## 📝 Regla 3: Trazabilidad Militar (Conventional Commits)

El Registro Temporal sirve a la integridad del Changelog y a herramientas automáticas del DevEx de Aegis. Todo commit individual y cada título del Pull Request final integrando el código en Main debe usar `Conventional Commits`.

- En lugar de: `update the proxy network and bugs on startup` ❌
- Usa: `feat(proxy): intercept html directly parsing payload from stdin` ✅
- Usa: `fix(scheduler): prevent race condition between tokio and wasmtime locks` ✅
- Usa: `docs(readmes): improve Docker isolation guidelines and volume docs` ✅

Todos los scopes atañen un `epic` o módulo dentro de las áreas de la estructura: `(kernel)`, `(shell)`, `(bff)`, `(wasm-sdk)`, `(siren)`, etc.

*Gracias por acatar esta filosofía. Si respetas el ecosistema Aegis, la IA respetará tu RAM.*
