# Funcionalidad de Sincronización con Google Drive

## Descripción
La funcionalidad de sincronización permite subir automáticamente todas las fotos de artrópodos identificados junto con sus metadatos científicos a Google Drive, organizándolos en una estructura jerárquica por clase y orden taxonómico.

## Estructura de Carpetas Creada

```
📁 BioDetect/
├── 📁 Insecta/
│   ├── 📁 Lepidoptera/
│   │   ├── 🖼️ Insecta_Lepidoptera_[photoId].jpg
│   │   └── 📄 Insecta_Lepidoptera_[photoId]_metadata.txt
│   ├── 📁 Orthoptera/
│   │   ├── 🖼️ Insecta_Orthoptera_[photoId].jpg
│   │   └── 📄 Insecta_Orthoptera_[photoId]_metadata.txt
│   └── 📁 [Otros órdenes]/
└── 📁 Arachnida/
    ├── 📁 Araneae/
    │   ├── 🖼️ Arachnida_Araneae_[photoId].jpg
    │   └── 📄 Arachnida_Araneae_[photoId]_metadata.txt
    └── 📁 [Otros órdenes]/
```

## Contenido de los Metadatos

Cada archivo de metadatos contiene información científica estructurada:

- **Información Taxonómica**: Clase, Orden
- **Información del Hallazgo**: Hábitat, Detalles, Notas de campo
- **Información Geográfica**: Coordenadas GPS, Fecha de verificación
- **Información de Sincronización**: Fecha y estructura de carpetas

## Cómo Usar

1. **Desde el Álbum de Fotos**: Toca el ícono de sincronización (☁️🔄) en la parte superior
2. **Confirmar Sincronización**: Revisa el diálogo que muestra cuántas fotos se van a sincronizar
3. **Autenticación**: Si es la primera vez, se solicitará acceso a Google Drive
4. **Esperar**: El proceso puede tardar algunos minutos dependiendo de la cantidad de fotos
5. **Resultado**: Se mostrará un resumen de la sincronización completada

## Permisos Requeridos

- **Google Drive**: Acceso para crear carpetas y subir archivos
- **Internet**: Conexión activa para comunicarse con Google Drive API

## Consideraciones Técnicas

- Las fotos se suben en resolución completa
- Los metadatos se generan en tiempo real desde Firebase
- La estructura de carpetas se crea automáticamente
- No se suben duplicados (se verifica por ID de foto)
- El proceso es resiliente a errores de conexión

## Beneficios Científicos

1. **Organización Taxonómica**: Estructura clara por clasificación científica
2. **Respaldo en la Nube**: Protección contra pérdida de datos
3. **Acceso Universal**: Disponible desde cualquier dispositivo con Google Drive
4. **Metadatos Completos**: Información científica detallada para cada especimen
5. **Compartir Investigación**: Fácil colaboración con otros investigadores

## Limitaciones

- Requiere cuenta de Google Drive activa
- Consume espacio del almacenamiento de Google Drive del usuario
- Necesita conexión a internet estable para completar la sincronización
- El tiempo de sincronización depende de la velocidad de internet y cantidad de fotos

## Solución de Problemas

- **Error de autenticación**: Verificar que la cuenta de Google tenga acceso a Drive
- **Error de conexión**: Verificar la estabilidad de la conexión a internet
- **Espacio insuficiente**: Liberar espacio en Google Drive
- **Proceso interrumpido**: Reintentar la sincronización (solo subirá archivos faltantes)
