# GUÍA TÉCNICA: DESPLIEGE DE CISCO PACKET TRACER 9.0.0 EN OPENSUSE LEAP CON DISTROBOX
---
 ![](1*Ko3IZZ8TN6OfP3YFBOzJ7Q.png)
 
 Ejecutar entornos de simulación propietarios empaquetados exclusivamente para ecosistemas Debian/Ubuntu (como el `.deb` oficial de Cisco Packet Tracer) sobre sistemas operativos orientados a la estabilidad corporativa como **openSUSE Leap** suele generar conflictos severos de dependencias dinámicas (`.so`).
 
Para mantener el sistema base intacto y evitar la contaminación de librerías, la solución óptima es aislar el software en un contenedor nativo mediante **Distrobox y Podman**. A continuación, se documenta el despliegue estructurado, la resolución de errores en tiempo de ejecución (runtime) y las optimizaciones de interfaz para la versión 9.0.0.

## 1. Preparación del Entorno Anfitrión (Host)

Como administradores, priorizamos la seguridad. Utilizaremos Podman para gestionar el contenedor en el espacio de usuario (rootless, sin privilegios de root). Instale las herramientas necesarias en su terminal de openSUSE Leap:

```
sudo zypper in podman distrobox
```

Proceda a descargar el instalador oficial de Packet Tracer para Ubuntu (ej. `CiscoPacketTracer_900_Ubuntu_64bit.deb`) desde el portal de Cisco Networking Academy o Skills for All, y colóquelo en su directorio local `~/Descargas`.

## 2. Creación e Inicialización del Contenedor

Cree un contenedor basado en una imagen de Ubuntu LTS (en este caso, Ubuntu 24.04), el cual servirá como el entorno de ejecución aislado:

```
distrobox create --image ubuntu:24.04 --name packet-tracer-env
```


Una vez finalizada la descarga de la imagen, acceda al entorno interactivo del contenedor:

```
distrobox enter packet-tracer-env
```

## 3. Depuración e Inyección de Dependencias (Runtime)

Al ejecutar Packet Tracer en imágenes limpias de Ubuntu actualizadas, el binario fallará de forma secuencial. El análisis de los logs de la terminal nos indica exactamente qué librerías del sistema faltan y cómo resolverlas:

### Error de Instalación: Paquete obsoleto de infraestructura gráfica

```
Package 'libgl1-mesa-glx' has no installation candidate
```

- **Diagnóstico**: El instalador de Cisco busca libgl1-mesa-glx, un paquete de transición deprecado y eliminado en los repositorios modernos de Ubuntu.
- **Solución**: Reemplazarlo manualmente por las librerías actuales de la arquitectura OpenGL que proveen aceleración de hardware, e instalar `gdebi` para la gestión del paquete:

```
sudo apt update && sudo apt install -y gdebi-core libgl1 libglx-mesa0 libgl1-mesa-dri
```

### Errores en Ejecución: Ausencia de la API OpenGL y subsistema GSettings

```
./PacketTracer: error while loading shared libraries: libOpenGL.so.0: cannot open shared object file: No such file or directory
/tmp/.../pt-manage.sh: line 25: gsettings: command not found
```

- **Diagnóstico**: Falta el enlace dinámico a la abstracción de OpenGL independiente del proveedor y las herramientas de configuración de GNOME que invoca el script de inicio.
- **Solución**: Inyectar los paquetes exactos que contienen dichos recursos binarios:

```
sudo apt install -y libopengl0 libglib2.0-bin
```

### Error de Audio: Dependencia de PulseAudio

```
./PacketTracer: error while loading shared libraries: libpulse.so.0: cannot open shared object file: No such file or directory
```


- **Diagnóstico**: El binario requiere el enlace dinámico del servidor de sonido para reproducir las alertas de la simulación.
- **Solución**: Instalar la biblioteca compartida correspondiente:

```
sudo apt install -y libpulse0
```

### Error de Interfaz: Fallo del Plugin de Plataforma Qt (XCB)

```
Available platform plugins are: linuxfb, xcb.
```

- **Diagnóstico**: El framework gráfico Qt embebido en Packet Tracer no puede renderizar la ventana ni comunicarse con el servidor de pantalla del host (X11/XWayland) por falta de componentes XCB.
- **Solución**: Instalar el backend gráfico de desarrollo requerido:

```
sudo apt install -y libxcb-xinerama0 libxkbcommon-x11-0 libxcb-cursor0
```

## 4. Despliegue del Software

Una vez que la validación de dependencias arroje un estado limpio, proceda con la instalación del paquete `.deb` ejecutando:

```
cd ~/Descargas
sudo gdebi CiscoPacketTracer_*_Ubuntu_64bit.deb
```

*(Utilice las teclas de navegación en la terminal para aceptar los términos de la licencia EULA de Cisco cuando el instalador lo solicite).*

## 5. Mitigación de Fricciones en el Login (Navegador Indexado)

Para evitar fallos de redirección de red o bloqueos de comunicación entre el contenedor aislado y los navegadores instalados en el sistema anfitrión (host), lo más eficiente es delegar la autenticación al motor web interno del programa.

- Inicie Packet Tracer por primera vez desde la terminal del contenedor escribiendo `packettracer`.
- Vaya a **Preferences** (Preferencias) / pestaña **Miscellaneous** (Miscelánea).
- Busque la sección Login Settings y marque la opción: `[X] Use internal web browser for Cisco Networking Academy login`
- Aplique los cambios. Esto forzará a la aplicación a desplegar la ventana de inicio de sesión de forma interna, garantizando la persistencia del token de sesión sin interactuar con el exterior.

## 6. Integración Nativa con el Escritorio (GNOME)

Para no depender de la terminal cada vez que requiera iniciar el simulador, exporte la aplicación hacia el menú del entorno gráfico de openSUSE Leap. Ejecute **dentro del contenedor**:

```
distrobox-export --app packettracer
```

Esto generará automáticamente el archivo de configuración del lanzador en la ruta local del host: `~/.local/share/applications/packet-tracer-env-CiscoPacketTracer-9.0.0.desktop`.

>⚠️ ADVERTENCIA CRÍTICA DE ADMINISTRACIÓN (PERMISOS)
>
>NUNCA ejecute el comando: `sudo chown -R $USER:$USER /home/TU_USUARIO/.local/.packettracer/`
>
>Razón técnica: Distrobox comparte de forma nativa el directorio `$HOME` del sistema anfitrión y mapea tu UID de usuario. Si ejecutas `sudo chown` de forma recursiva dentro del contenedor, la variable `$USER` se evalúa como `root` debido al uso de `sudo`. Al hacer esto, le quitarás los permisos de lectura y escritura a tu propio usuario real de openSUSE sobre sus propios archivos de configuración locales, rompiendo instantáneamente el contenedor y el acceso a la aplicación. Los logs demuestran que, si las dependencias del paso 3 están cubiertas, la aplicación gestiona sus directorios sin necesidad de alterar permisos manuales.

### Parche Manual para el Icono en la Versión 9.0.0

Existe un error de declaración en el instalador de la versión 9.0.0 que deja el campo `Icon=` vacío dentro del archivo `.desktop`, provocando que el lanzador se muestre genérico o roto en el tablero de GNOME. Para solucionarlo:

- Abra el archivo de configuración del acceso directo desde la terminal de openSUSE Leap:

```
nano ~/.local/share/applications/packet-tracer-env-CiscoPacketTracer-9.0.0.desktop
```

- Busque la línea `Icon=` y defina la ruta absoluta hacia el recurso gráfico oficial de Packet Tracer (por defecto el instalador lo aloja en la raíz del software bajo el nombre de `app.png`):

```
Icon=/opt/pt/app.png
```

- Guarde y cierre el editor (Ctrl + O, Enter, Ctrl + X).

### Aplicación de Cambios

Para que el entorno gráfico indexe el nuevo lanzador de escritorio y aplique la ruta corregida del icono de manera definitiva, la vía más limpia y rápida es cerrar la sesión actual de su usuario en GNOME y volver a iniciar sesión.

Una vez que el entorno de escritorio vuelva a cargar, el icono oficial de Cisco Packet Tracer estará completamente visible y listo para operar desde su menú de aplicaciones de forma integrada.