# PERSISTENCIA Y ARQUITECTURA DE PERMISOS: CÓMO LOGRÉ COMUNICAR UN ESCANER USB DENTRO DE UN CONTENEDOR DE DISTROBOX CON PODMAN
---

En el ámbito de la administración de sistemas Linux, la adopción de herramientas de contenerización como Distrobox y Podman se ha convertido en una práctica estándar para mantener la integridad y limpieza del sistema anfitrión (host). Sin embargo, el aislamiento estricto que define a estas tecnologías suele presentar desafíos complejos cuando se introduce la necesidad de interactuar con hardware físico local.

Recientemente, me planteé un problema técnico que comenzó con una interrogante fundamental: **¿Es posible hacer funcionar un periférico de escaneo USB (específicamente una Brother DCP-T220) dentro de un contenedor de Debian gestionado por Podman sobre una distribución base como openSUSE?** A través de este artículo, comparto el análisis de las capas de abstracción involucradas, el obstáculo real de seguridad que enfrenté y la metodología exacta que utilicé para resolver la comunicación directa entre el contenedor y el hardware.

## El Diagnóstico del Problema: La Barrera del Aislamiento Rootless

El despliegue inicial parecía directo: acceder al contenedor e instalar los controladores propietarios provistos por el fabricante. No obstante, al ejecutar la herramienta de diagnóstico de SANE (sane-find-scanner), me encontré de forma sistemática con el siguiente bloqueo de seguridad:

```
could not open USB device 0x04f9/0x0474: Access denied (insufficient permissions)
```

El identificador de hardware `0x04f9/0x0474` confirmaba que el sistema reconocía la presencia física de mi Brother DCP-T220, pero la capa de abstracción de Podman impedía la comunicación. Incluso tras intentar forzar la detección con privilegios de administrador dentro del contenedor, el acceso seguía denegado.

Comprendí entonces un principio fundamental de la arquitectura de Linux: **todo es un archivo**. Si el sistema operativo anfitrión mantiene un bloqueo estricto sobre los nodos de los dispositivos en el directorio `/dev/`, el contenedor jamás podrá reclamar el control del puerto, independientemente de los privilegios o controladores que se configuren en su entorno aislado.


## La Solución: Modificación de Permisos en el Sistema Base (Host)

La clave para resolver este problema no se encontraba dentro del contenedor, sino fuera de él. El proceso requirió identificar la ubicación exacta del puerto físico en el host mediante el comando lsusb. Una vez determinado que el dispositivo se encontraba asignado al Bus 003, Dispositivo 002, procedí a alterar el modo del archivo de dispositivo directamente en mi sistema openSUSE:

```
sudo chmod 666 /dev/bus/usb/003/002
```

Este comando asignó permisos globales de lectura y escritura (666) sobre el nodo del USB. Al otorgar este acceso a nivel de sistema base, se eliminó de inmediato el bloqueo que originaba el error Access Denied, permitiendo que el contenedor finalmente pudiera comunicarse con el hardware.

> Nota de persistencia: Es crucial denotar que el directorio /dev/ se reconstruye dinámicamente en el espacio de memoria durante cada arranque del sistema, por lo que esta asignación de permisos es de carácter temporal y persistirá únicamente hasta el próximo reinicio de la máquina.
>
>> **NOTA DE SEGURIDAD**: investigando me di cuenta que usar el comando 666 es una muy mala practica y si esto se hace en una empresa es mejor usar las `udev rules`

## Automatización del Entorno Interno del Contenedor

Una vez abierto el canal de comunicación desde el host liberando la ruta física, el escáner fue reconocido de inmediato. Con la finalidad de estandarizar, replicar y automatizar este flujo en futuras implementaciones dentro de Debian, desarrollé el siguiente script en Bash que realiza la instalación limpia de las dependencias y el driver:

```
#!/bin/env bash
# Forzar la detención del script ante cualquier fallo
set -e

echo "[*] Instalación de dependencias..."
sudo apt update && sudo apt install -y wget

echo "[*] Descarga de los drivers oficiales de Brother..."
wget -O brscan5-1.7.0-0.amd64.deb "https://support.brother.com/g/b/downloadend.aspx?c=mx&lang=es&prod=dcpt220_all&os=128&dlid=dlf104033_000&flang=4&type3=566"

echo "[*] Instalación del paquete local con apt..."
sudo apt install -y ./brscan5-1.7.0-0.amd64.deb

echo "[*] Instalación de la interfaz gráfica de escaneo..."
sudo apt install -y simple-scan

echo "[*] Verificación del hardware con SANE..."
sudo sane-find-scanner
```

Al ejecutar este entorno automatizado con la ruta del USB previamente desbloqueada, la salida de SANE confirmó el éxito rotundo del experimento:

```
found possible USB scanner (vendor=0x04f9 [Brother], product=0x0474 [DCP-T220]) at libusb:003:002
```

## Integración con el Entorno de Escritorio Anfitrión

Para consolidar la usabilidad del sistema y evitar la dependencia de la terminal en tareas cotidianas, utilicé la capacidad de exportación nativa de Distrobox. Ejecutando el siguiente comando dentro de Debian, logré integrar la interfaz gráfica instalada en el contenedor directamente en el menú de mi sistema base:

```
distrobox-export --app simple-scan
```

Este proceso generó un lanzador `.desktop` en la ruta de mi usuario (`~/.local/share/applications/`), permitiéndome ejecutar Simple Scan con la misma fluidez que una aplicación nativa, manteniendo el host completamente libre de paquetería de terceros y delegando todo el trabajo pesado al contenedor.

## Conclusiones

Esta experiencia me aportó una valiosa lección de infraestructura y sistemas. Demostró que las limitaciones de compatibilidad de hardware en entornos virtuales o contenedorizados rara vez se deben a la ausencia de controladores compatibles, sino a la rigidez en las capas de aislamiento y la asignación de permisos sobre los buses de comunicación del sistema operativo. Comprender el flujo de los dispositivos dentro del directorio /dev/ abre un abanico de posibilidades para mantener un sistema anfitrión limpio, delegando la gestión de periféricos complejos a entornos controlados.

>Nota del autor: Esta documentación, junto con el script en Bash, está liberada bajo la licencia CC0 1.0; es decir, es de dominio público. Les sugiero que siempre auditen y lean cualquier script que vayan a ejecutar en su máquina para evitar cualquier inconveniente; después de todo, es bajo su propia responsabilidad.

 