import 'package:flutter/foundation.dart';

/// Notificador global para comunicar cambios en los contadores del perfil
/// Permite que cualquier pantalla notifique que se han eliminado registros o bitácoras
/// 
/// CASOS DE USO:
/// 1. Creación de nuevos registros desde RegDatos
/// 2. Creación de nuevas bitácoras desde CrearEditarBitacoraScreen
/// 3. Actualización de registros existentes desde RegDatos
/// 4. Actualización de bitácoras desde CrearEditarBitacoraScreen
/// 5. Eliminación de registros individuales desde DetalleRegistro
/// 6. Eliminación de bitácoras desde MisBitacorasScreen
/// 7. Eliminación masiva desde herramientas de administración
/// 8. Sincronización de datos que afecte los contadores
/// 
/// EJEMPLO DE USO:
/// ```dart
/// // Después de crear un nuevo registro exitosamente:
/// ProfileNotifier().notifyRegistroCreado();
/// 
/// // Después de crear una nueva bitácora exitosamente:
/// ProfileNotifier().notifyBitacoraCreada();
/// 
/// // Después de eliminar un registro exitosamente:
/// ProfileNotifier().notifyRegistroEliminado();
/// 
/// // Después de eliminar bitácoras:
/// ProfileNotifier().notifyBitacorasEliminadas();
/// 
/// // Para cambios generales en el perfil:
/// ProfileNotifier().notifyProfileChanged();
/// ```
/// 
/// El ProfileScreen automáticamente escucha estos cambios y recarga los datos.
class ProfileNotifier {
  static final ProfileNotifier _instance = ProfileNotifier._internal();
  factory ProfileNotifier() => _instance;
  ProfileNotifier._internal();

  /// ValueNotifier que se activa cuando se necesita recargar el perfil
  /// El valor booleano indica si hubo cambios que requieren recarga
  final ValueNotifier<bool> shouldRefreshProfile = ValueNotifier<bool>(false);

  /// Notificar que se eliminó un registro y posiblemente bitácoras
  /// Esto forzará la recarga del ProfileScreen
  void notifyRegistroEliminado() {
    print('🔔 ProfileNotifier: Notificando eliminación de registro');
    shouldRefreshProfile.value = !shouldRefreshProfile.value; // Toggle para activar listeners
  }

  /// Notificar que se creó un nuevo registro
  /// Esto forzará la recarga del ProfileScreen para actualizar contador de identificaciones
  void notifyRegistroCreado() {
    print('🔔 ProfileNotifier: Notificando creación de nuevo registro');
    shouldRefreshProfile.value = !shouldRefreshProfile.value; // Toggle para activar listeners
  }

  /// Notificar que se creó una nueva bitácora
  /// Esto forzará la recarga del ProfileScreen para actualizar contador de bitácoras
  void notifyBitacoraCreada() {
    print('🔔 ProfileNotifier: Notificando creación de nueva bitácora');
    shouldRefreshProfile.value = !shouldRefreshProfile.value; // Toggle para activar listeners
  }

  /// Notificar que se eliminaron bitácoras
  void notifyBitacorasEliminadas() {
    print('🔔 ProfileNotifier: Notificando eliminación de bitácoras');
    shouldRefreshProfile.value = !shouldRefreshProfile.value; // Toggle para activar listeners
  }

  /// Notificar cambios generales en el perfil
  void notifyProfileChanged() {
    print('🔔 ProfileNotifier: Notificando cambio en perfil');
    shouldRefreshProfile.value = !shouldRefreshProfile.value; // Toggle para activar listeners
  }

  /// Limpiar recursos si es necesario
  void dispose() {
    shouldRefreshProfile.dispose();
  }
}