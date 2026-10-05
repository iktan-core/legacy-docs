# OPENSUSE TUMBLEWEED: WIFI SOLICITA CONTRASEÑA EN CADA INICIO (RTL8821CE / NETWORKMANAGER)
---
## Contexto

En un equipo con openSUSE Tumbleweed, utilizando una tarjeta inalámbrica Realtek RTL8821CE (driver rtw88_8821ce), se presentó un comportamiento anómalo en la conexión WiFi.

La red estaba correctamente configurada (incluyendo uso de banda de 5 GHz y WPA3-SAE), pero el sistema solicitaba la contraseña de forma recurrente.


## problema

La conexión WiFi pedía la contraseña en los siguientes casos:

- Después de reiniciar el sistema
- Al desactivar y volver a activar el adaptador WiFi

Esto ocurría aun cuando:

- La red ya estaba guardada
- La contraseña era correcta
- No había cambios en la configuración del router

## Síntomas observados

- La red aparecía como conocida, pero no se conectaba automáticamente
- Se requería introducir la contraseña manualmente en cada reconexión
- No se observaban errores claros en la interfaz gráfica
- Inicialmente parecía un problema relacionado con WPA3 o con el driver Realtek

## Diagnóstico

Después de descartar problemas de compatibilidad con WPA3-SAE y posibles fallos del driver, se revisó la configuración del perfil de red gestionado por NetworkManager.

Se identificó que la conexión no tenía habilitada la opción de autoconexión (```connection.autoconnect```).

```bash
nmcli connection show "NOMBRE_DE_TU_WIFI"| grep autoconnect
```

Esto provocaba que NetworkManager tratara la conexión como no persistente, forzando un nuevo proceso de autenticación en cada intento de conexión.

## Causa raíz

El parámetro:

```
connection.autoconnect
```

estaba deshabilitado para el perfil de red.

En este estado, NetworkManager:

- No intenta reconectar automáticamente
- No prioriza la red al iniciar el sistema
- Puede no reutilizar correctamente las credenciales almacenadas

Esto deriva en la solicitud repetida de la contraseña, aunque esta ya exista en el sistema.

## Solución

Se habilitó la autoconexión para el perfil de red mediante ```nmcli```:

```bash
nmcli connection modify "NOMBRE_DE_TU_WIFI" connection.autoconnect yes
```

esultado

Después de aplicar el cambio:

- La red se conecta automáticamente al iniciar el sistema
- No vuelve a solicitar la contraseña
- La conexión se comporta como persistente

## Consideraciones adicionales

El chipset Realtek RTL8821CE es conocido por presentar ciertos problemas en Linux, especialmente en configuraciones con WPA3-SAE. Esto puede llevar a diagnósticos erróneos si no se revisan primero los parámetros básicos de NetworkManager.

En este caso, el problema no estaba relacionado con el driver ni con el tipo de seguridad, sino con la configuración del perfil de red.

## Conclusión

Antes de asumir problemas de compatibilidad (driver, chipset o WPA3), es recomendable verificar la configuración de autoconexión en NetworkManager.

Un ajuste simple en ```connection.autoconnect``` puede resolver completamente un problema que, a primera vista, parece mucho más complejo.
