# Qué va y qué no va en el archivo de contexto

## Los seis tipos que van

### 1. La dirección

El código muestra el estado. No muestra hacia dónde va.

> `src/` es legacy con cambios restringidos. Cada ruta, comando o caso de uso nuevo empieza
> en `internal/features/<área>/<operación>/`.

Un agente ve las dos carpetas con un `ls`. Lo que no ve es cuál crece.

### 2. Lo que impone algo de afuera

Un servidor, una red, una herramienta externa.

> El servidor solo acepta ramas `master`, `develop`, o con prefijo `feature/`, `release/`,
> `hotfix/` o `bugfix/`. Rechaza las demás al pushear.

No está en ningún archivo del repositorio. Se descubre cuando el push falla.

### 3. Prohibiciones contra el default

Lo que el agente hace mal si nadie se lo dice, justamente porque hace lo normal.

> Los mocks son a mano. No los generes.

### 4. Las trampas

Lo que parece que funciona y no funciona. Es el tipo de mayor valor: es lo que hace perder
una tarde.

> Los tests de integración se saltean sin Docker. Un salteo no valida una migración.

### 5. Convenciones con un criterio comprobable

Con el ejemplo adentro. Un ejemplo vale más que el párrafo que lo describe.

> Los nombres de test describen conducta:
> `TestThe_migration_creates_the_schema_in_a_real_database`.

### 6. Comandos que no se adivinan

> Los módulos privados necesitan `GOPRIVATE="…"` y credenciales en `~/.netrc`.

## Lo que no va

| No va | Por qué |
|---|---|
| La estructura de carpetas | Se ve con `ls` |
| La lista de dependencias | Está en el archivo de dependencias |
| Un resumen de la arquitectura, si se deduce leyendo unos pocos archivos | En un repositorio grande puede no deducirse: ahí sí vale |
| "Verificá tu trabajo antes de responder" | En los modelos frontera actuales produce verificación de más. Con un modelo menor puede hacer falta |
| "Mantené el código limpio" | No se puede comprobar |
| Una referencia a otro repositorio o a un plan | El lector no lo tiene. Salvo que sea un requisito real del trabajo, y entonces se explica |
| El nombre de una herramienta local | Quien clona el repositorio quizá no la tenga. Si es obligatoria, decilo con cómo instalarla |

## La excepción que importa

**Que algo sea deducible no alcanza para sacarlo.** La pregunta es cuánto cuesta omitirlo.

| Regla | ¿Deducible? | ¿Cuesta omitirla? | Va |
|---|---|---|---|
| "No edites una migración publicada" | Sí, del comentario del paquete | Daño irreversible en la base | **Sí** |
| "No edites los archivos generados" | Sí, del encabezado del archivo | Se pierde el trabajo | **Sí** |
| "El proyecto usa Go y Postgres" | Sí, del archivo de dependencias | Nada | No |

## La forma de cada línea

Una regla y su razón, en una o dos líneas.

```
Cada ruta, comando o caso de uso nuevo empieza en `internal/`. `src/` acepta
cambios adentro de lo que ya expone; se migra de a una operación por MR.
```

Ojo con las reglas absolutas. Una primera versión de este mismo ejemplo decía
"ningún archivo nuevo bajo `src/`", y era falsa: el equipo ya estaba agregando
archivos ahí. Una regla que el equipo viola el día que se escribe no se cumple
nunca.

La razón importa: una regla sin razón se desobedece el día que molesta.

## Un caso que vale conocer

En una prueba real, un generador describió una frontera entre dos arquitecturas así:

> "El código HTTP y de negocio vive en `src/api/`; el código de plataforma vive en
> `internal/`."

Es lo que se ve. Pero la división real era por edad, no por tipo. Un agente que lea esa
frase pone una función de negocio nueva en la carpeta congelada.

**Una descripción de arquitectura sin su regla de decisión puede ser peor que
ninguna descripción**: suena segura y puede llevar al error. Pasó una vez, en
una corrida. No está medido cuán seguido pasa.
