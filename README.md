# EduNova

Aplicación Flutter del sistema académico EduNova.

## Abrir el proyecto correctamente

Abre en VS Code **esta carpeta**, la que contiene directamente `pubspec.yaml`, `lib/` y `web/`. No abras una carpeta superior ni una carpeta `edunova` anidada.

Si recibiste una copia anterior que contiene otra carpeta `edunova` dentro, usa la carpeta raíz de este paquete y no mezcles archivos entre ambas.

## Ejecutar en Microsoft Edge

En una terminal ubicada en la raíz del proyecto ejecuta:

```bash
flutter config --enable-web
flutter clean
flutter pub get
flutter devices
flutter run -d edge
```

Para depurar con **F5** en VS Code:

1. Instala Flutter y la extensión **Dart-Code**.
2. Abre la carpeta raíz del proyecto, la que contiene `pubspec.yaml`.
3. Ejecuta una vez `flutter pub get`.
4. Selecciona **EduNova (Edge)** en el panel **Ejecutar y depurar**.
5. Presiona **F5**.

La configuración de `.vscode/launch.json` usa `${workspaceFolder}` y ya no depende de rutas absolutas ni de la ubicación donde se descomprimió el ZIP.

## Cuenta local y foto de perfil

La aplicación incluye registro e inicio de sesión local con correo y contraseña. La cuenta se guarda en el almacenamiento del navegador actual; no es una cuenta Google real ni sincroniza entre dispositivos. La foto de perfil también se guarda localmente y se recupera al volver a abrir la aplicación.

Para usar Google real se necesita conectar un proyecto Firebase y habilitar los proveedores Google y correo/contraseña.

### Si Edge no aparece en `flutter devices`

- Comprueba que Microsoft Edge esté instalado.
- Ejecuta `flutter config --enable-web`.
- Cierra y vuelve a abrir VS Code después de instalar Flutter o la extensión Dart-Code.
- No ejecutes el comando desde `android/`, `lib/` o desde la carpeta contenedora; ejecútalo desde la raíz que contiene `pubspec.yaml`.

### Si aparece un error de localhost

`flutter run -d edge` crea un servidor local temporal. No escribas una URL fija en el navegador: espera a que Flutter muestre la URL y abra Edge. Si quedó un proceso anterior bloqueando el puerto, detén la ejecución con `Ctrl+C`, cierra la pestaña de la aplicación y vuelve a ejecutar:

```bash
flutter clean
flutter pub get
flutter run -d edge
```

## Módulo de Proyectos

El módulo está integrado directamente en el menú principal. Incluye creación rápida con pasos sugeridos, tarjetas de progreso, fechas de entrega, brief del profesor, pasos interactivos, recursos con enlaces y archivos, Pomodoro de 25 minutos, mensajes motivadores y sección de proyectos entregados.

## Calificaciones y Eventos

Calificaciones permite editar las notas de P1, P2, P3 y P4 por materia, calcular el promedio de cada materia y mostrar el promedio general. Las notas se guardan localmente en el dispositivo.

Google Maps está integrado dentro de Eventos.

## Módulo de documentos

Desde **Documentos** puedes guardar archivos PDF o imágenes JPG/PNG. En Edge se guardan en el almacenamiento local del navegador y se abren en una pestaña nueva. En Android/iOS se copian a la carpeta privada de documentos de la aplicación y se conservan entre sesiones.

El perfil del estudiante se abre desde la burbuja ubicada en la esquina superior derecha del menú principal.
