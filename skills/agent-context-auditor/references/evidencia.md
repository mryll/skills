# La evidencia, y sus límites

Reunida el 2026-08-28. Cada afirmación con su fuente y su alcance. Varias de estas
conclusiones son más débiles de lo que suele repetirse.

## Lo que está medido

### Los archivos de contexto cuestan, y no está demostrado que ayuden

Gloaguen et al., "Evaluating AGENTS.md" (ETH Zurich, feb 2026):

- Archivos escritos por desarrolladores: **+2,4 puntos**, con **p = 21 %**. No significativo.
- Archivos generados sin curar: **−0,5 y −2 puntos**, con p = 87 % y 37 %. No significativo.
- Humano contra generado: **p = 3,8 %**. Eso sí es significativo.
- **Costo: +20 a 23 %.** Eso también.

La lectura correcta: no está demostrado que un archivo de contexto mejore el resultado
contra no tener ninguno. Sí está demostrado que aumenta el costo, y que un archivo aportado
por un desarrollador supera a uno generado sin revisar.

Ojo: el estudio comparó **origen**, no **poda**. Nadie midió el mismo archivo podado contra
sin podar. Decir "lo que importa es la poda" es una hipótesis razonable, no un resultado.

Cuidado con la versión que circula, que dice "los archivos humanos ayudan un 4 %". El
número es 2,4 y no es significativo.

### En un estudio grande, la estructura del archivo no movió la adherencia

McMillan, arXiv 2605.10039 (may 2026). Estudio factorial de cuatro variables: tamaño,
posición de la instrucción, arquitectura de archivos, contradicciones entre archivos
vecinos. 1650 sesiones, 16 050 observaciones, dos repositorios TypeScript, tres modelos.

- **Ninguna de las cuatro produce un efecto detectable.**
- Tamaño y conflicto tienen evidencia positiva de nulidad (factor de Bayes 0,05–0,10).
- El efecto más grande es **dentro de la sesión**: cada función adicional se asocia con un
  5,6 % menos de probabilidad de cumplimiento. Es una asociación, no una causa, la relación
  no es constante, y el hallazgo apareció durante el análisis, no estaba previsto.

Límites: mide adherencia a una anotación trivial, no tasa de éxito ni costo. Dos
repositorios, un lenguaje. No demuestra que el tamaño nunca importe.

**Lo accionable**: en las condiciones de ese estudio, el largo no movió la adherencia. No
demuestra que nunca importe. Y sobre la caída dentro de la sesión, el estudio no probó que
los controles automáticos la arreglen: es lo razonable, no lo medido.

### Un método iterativo de producción rindió más que uno estático

Shepard y Albrecht, arXiv 2606.20512 (jun 2026). SWE-bench Verified:

- Sin guía: 25,5 %. Base estática: 28,3 %. Con refinamiento iterativo: **33,0 %** (p < 0,001).
- La mejora es de **cobertura, no de precisión**: la guía lleva al agente al archivo
  correcto (+14,5 puntos de parches evaluables), pero la calidad del cambio queda igual
  (~59 %, p = 0,119).

Límites: un modelo principal. La guía refinada era 63 % más larga, y el estudio no aisló
ese factor. Con otro modelo, la guía perjudicó.

Y algo que hay que decir: ese método refina el archivo con sondas sintéticas de errores.
**Este skill no lo implementa.** El estudio aporta motivación, no respaldo directo.

### Con un modelo menor, el formato de la especificación pesa más

"Architecture as Capability Equalizer", arXiv 2608.21747 (ago 2026). Factorial 5×6, 90
corridas:

- En modelos frontera el formato casi no importa: dispersión de 0,17 a 0,92 puntos.
- En modelos menores llega a 2,42: hasta 14 veces más.
- Los contratos tipados triplicaron la cobertura del modelo más débil (33 % → 100 %).
- Sin guía de arquitectura, un modelo frontera cayó de 8,42 a 5,08.

Límites: **los autores lo declaran exploratorio**, con tres repeticiones por celda y un
solo sistema. No presentan significancia para las comparaciones principales. El evaluador
puntuaba arquitectura, y la condición sin guía no podía satisfacer esos criterios.

**Lo que sí sostiene**: en ese experimento exploratorio, un modelo débil reprodujo mejor
una arquitectura con contratos tipados que con prosa. No sostiene que los necesite siempre,
ni una mejora general de éxito funcional.

## Lo que dice el proveedor

Documentación de Claude Code, vigente:

- Menos de 200 líneas. Es una recomendación operativa, no un umbral medido.
- Específico y verificable: "usá dos espacios de sangría" rinde más que "formateá bien".
- El contenido llega como mensaje de usuario. **No es control.**
- Para algo que debe pasar siempre: un hook, no el archivo.
- Reglas por ruta, que cargan solo cuando el agente toca esos archivos.

Guía de Anthropic para Opus 5, vigente:

- Sacar las instrucciones de verificación y de re-chequeo: producen verificación de más.
- Esa recomendación es **para ese modelo**. No se extiende sola a los demás niveles ni a
  otros proveedores.

## Lo que no está demostrado

Decilo cuando aplique, en vez de presentarlo como hecho:

- No hay un largo óptimo demostrado.
- No está demostrado que podar mejore el resultado. La comparación humano-contra-generado
  no aísla la poda: nadie comparó el mismo archivo podado y sin podar.
- Que un generador mencione una regla demuestra que la encontró **una vez**. No que la
  encuentre siempre. Y que la omita no demuestra que no sea deducible.
- La regla de dónde poner cada cosa es una heurística de diseño razonable. No está validada
  experimentalmente.

## Cómo usar esto

Cuando el skill toma una decisión apoyada en algo de acá, decí en qué se apoya y cuánto
pesa. Un informe que presenta una heurística como un hecho medido es el mismo error que el
skill intenta evitar en los archivos que audita.
