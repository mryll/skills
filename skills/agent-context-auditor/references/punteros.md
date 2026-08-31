# Qué archivo lee cada herramienta

**Fecha de este mapa: 2026-08-28.** Cambia seguido. Verificalo contra la documentación del
proveedor antes de escribir punteros: si pasaron unos meses, ya no es confiable.

## El estado al 2026-08-28

| Herramienta | Lee | Nota |
|---|---|---|
| Codex | `AGENTS.md` | Nativo |
| Claude Code | `CLAUDE.md` | No lee `AGENTS.md`. Necesita un `CLAUDE.md` con `@AGENTS.md`, o un enlace simbólico |
| Copilot CLI | `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` | También `.github/copilot-instructions.md` |
| Copilot en VS Code | `AGENTS.md` | En el chat. Hay un ajuste que lo habilita o deshabilita |
| Copilot Chat en github.com | `.github/copilot-instructions.md` | |
| Copilot agente de la nube | `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` | |
| Copilot revisión de código | `AGENTS.md` | No los otros dos |
| Copilot en JetBrains | `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` | El agente de la nube |
| Agentes personalizados de Copilot | `.github/agents/` | Otra cosa: define agentes, no instrucciones |

## Lo que se aprende de esa tabla

**"Copilot" no es una herramienta.** Son al menos cinco superficies, y no cargan lo mismo.
Preguntá cuál usa el equipo antes de escribir un puntero.

**Un archivo canónico y punteros de una línea.** Nunca copies el contenido: dos textos
divergen, y el que quedó viejo es el que alguien lee.

Forma de un puntero:

```markdown
Las instrucciones de este repositorio están en `AGENTS.md`, en la raíz. Leelo
antes de escribir código.

<!-- Este archivo existe porque <la superficie exacta> no lee AGENTS.md. No
copies acá el contenido: los dos textos divergen. -->
```

El comentario HTML explica por qué existe el archivo, y Claude Code lo descarta antes de
cargarlo, así que no gasta contexto.

## Cómo verificar que llegó

Cuando la herramienta ofrece un comando para listar lo que cargó, usalo. En Claude Code,
`/memory` lista los archivos de instrucciones y `/context` muestra las categorías; el hook
`InstructionsLoaded` da el registro exacto. Copilot CLI tiene `/instructions`.

Y un puntero en prosa no equivale a una importación: que un archivo diga "leé AGENTS.md" no
garantiza que el agente lo abra. Probalo en cada superficie. Un puntero que nadie lee es peor que ninguno:
da una falsa sensación de cobertura.

## Un error que cometimos

Escribimos un `.agent.md` en la raíz creyendo que Copilot CLI no leía `AGENTS.md`. La
documentación dice que sí lo lee, y `.agent.md` ni siquiera es una ubicación de
instrucciones.

La lección: **verificá contra la documentación del proveedor, no contra un artículo ni
contra la memoria.** Este mapa incluido.
