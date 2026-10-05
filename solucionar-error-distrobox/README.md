# DISTROBOX-EXPORT FALLBACK: CÓMO SOLUCIONAR EL ERROR DE PERMISOS (MKDIR: PERMISSION DENIED) AL EXPORTAR APPS

Si utilizas **Distrobox** para empaquetar aplicaciones aisladas dentro de contenedores (como Debian o Ubuntu) y correrlas de forma transparente en tu distribución Host (como openSUSE Tumbleweed, Fedora o Arch), tarde o temprano te vas a topar con este error al intentar integrar los accesos directos en tu entorno gráfico:

```
📦[user@container]$ distrobox-export --app zoho-mail-desktop
mkdir: cannot create directory ‘/run/host//home/usuario/.local/share/icons/hicolor/128x128’: Permiso denegado
```

Lo curioso de este fallo es que puede ocurrirte con una aplicación específica (como Zoho Mail) mientras que con otras (como Packet Tracer) la exportación nativa funciona a la primera.

En este artículo analizamos la causa raíz y cómo resolverlo de forma manual y quirúrgica sin romper los mapeos de IDs de tu contenedor.

## La Causa Raíz: El bug de la doble diagonal `//`

Cuando ejecutas `distrobox-export`, el script interno del contenedor intenta comunicarse con el sistema de archivos de tu máquina principal a través del punto de montaje `/run/host/`.

Para exportar los iconos de la aplicación, el script concatena esa ruta con tu variable `$HOME` (`/home/usuario`). Debido a una desincronización en la interpretación de variables de entorno entre ciertos sistemas Host y la capa de virtualización de Podman/Docker, la ruta se expande erróneamente con una doble diagonal:

Ruta erronea: `/run/host//home/usuario/…`

Para el kernel de Linux, esta inconsistencia rompe el contexto de seguridad del montaje rootless (sin raíz). El contenedor pierde el privilegio de llamada al sistema mkdir sobre esa ruta específica, lanzando el frustrante Permiso denegado.

Para el kernel de Linux, esta inconsistencia rompe el contexto de seguridad del montaje rootless (sin raíz). El contenedor pierde el privilegio de llamada al sistema `mkdi`r sobre esa ruta específica, lanzando el frustrante `Permiso denegado`.

## La Solución: Exportación Manual Quirúrgica

Si el automatismo de Distrobox falla, podemos replicar exactamente el mismo comportamiento de `distrobox-export` de manera manual usando el puente nativo `/tmp` (que no sufre de restricciones de `/run/host/`) y herramientas estándar de la terminal (`cp`, `mv` y `sed`).

### Paso 1: Extraer y mover el archivo .desktop

Los instaladores `.deb` o `.rpm` colocan el acceso directo dentro del contenedor. Vamos a sacarlo hacia el espacio de usuario del Host.

**Dentro del contenedor**:

```
cp /usr/share/applications/zoho-mail-desktop.desktop /tmp/
```

**En la terminal del Host**

```
mv /tmp/zoho-mail-desktop.desktop ~/.local/share/applications/
```

### Paso 2: Enlazar el ejecutable al motor de Distrobox

Actualmente, el archivo `.desktop` del Host intenta buscar el programa en una ruta local (ej. `/opt/...`), donde no existe. Debemos modificar la línea `Exec` para que llame a `distrobox-enter`.

Ejecuta este comando en el Host (reemplaza `ubuntu-env` por el nombre real de tu contenedor):

```
sed -i 's|^Exec=.*|Exec=distrobox-enter -n ubuntu-env -- "/opt/Zoho Mail - Desktop/zoho-mail-desktop" %U|' ~/.local/share/applications/zoho-mail-desktop.desktop
```

>**Nota técnica**: Al usar distrobox-enter -n <contenedor> --, el entorno gráfico del Host (como KDE Plasma o GNOME) sabrá que debe inicializar el contenedor para ejecutar el binario aislado de forma transparente.


**Desglose de sus partes:**

*   **`sed -i`**: Edita el archivo directamente en el disco (sin pedir confirmación ni crear copias).
*   **`s|...|...|`**: Es la orden de **buscar y reemplazar**. Usa el símbolo `|` como separador en lugar de `/` para que las barras de las rutas de archivos no causen errores.
*   **`^Exec=.*`**: Lo que **busca**. Selecciona la línea que empieza (`^`) con `Exec=` y cualquier cosa que le siga (`.*`). Es el comando original de ejecución.

### Paso 3: Extraer y mapear el Icono de la aplicación

Para evitar que la aplicación se muestre con un icono genérico o en blanco, extraemos la imagen en alta resolución desde el contenedor.

**Dentro del contenedor:**

```
cp /usr/share/icons/hicolor/512x512/apps/zoho-mail-desktop.png /tmp/
```

**En la terminal del Host**: Creamos el directorio de iconos local si no existe y movemos la imagen

```
mkdir -p ~/.local/share/icons
mv /tmp/zoho-mail-desktop.png ~/.local/share/icons/
```

Finalmente, actualizamos el archivo de escritorio en el Host para que apunte a la ruta absoluta de la imagen extraída:

```
sed -i "s|^Icon=.*|Icon=/home/$USER/.local/share/icons/zoho-mail-desktop.png|" ~/.local/share/applications/zoho-mail-desktop.desktop
```

>**Nota**: parece ser que en kde esto se hace automáticamente

## Conclusión

Forzar permisos masivos en el Host con comandos como `chown -R` o alterar las ACLs de tu carpeta `~/.local` suele ser una mala idea que termina rompiendo el mapeo de sub-IDs dinámicos de Podman.

Hacer la exportación manual te permite saltarte los bugs de concatenación de rutas de `distrobox-export`, manteniendo el aislamiento de tus contenedores intacto y logrando una integración al 100% en tu menú de aplicaciones.