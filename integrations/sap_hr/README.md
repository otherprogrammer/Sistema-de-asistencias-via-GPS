# Módulo de Integración SAP Recursos Humanos (SAP HR / SuccessFactors Time Tracking)

Módulo empresarial para la extracción, sanitización, deduplicación y transferencia de registros históricos de asistencia desde **Firebase Firestore** hacia el sistema de gestión de personal **SAP Recursos Humanos** (específicamente la API OData v2 de **SAP SuccessFactors Employee Central Time Tracking** o SAP ERP HCM Infotipo 2011).

---

## 1. Arquitectura y Componentes

El módulo opera de manera 100% desacoplada del código de la aplicación móvil Flutter y del panel web React, garantizando que el sistema original permanezca intacto.

```
integrations/sap_hr/
├── __init__.py               # Metadatos del paquete
├── config.py                 # Carga de configuración tipada desde variables de entorno (.env)
├── models.py                 # Clases de dominio inmutables y mapeo OData SAP
├── extractor.py              # Extracción desde Firestore (SDK/REST) y sanitización de datos
├── validator.py              # Validación temporal, georreferencial y detección de duplicados
├── sync_service.py           # Orquestador del flujo E2E
├── cli.py                    # Interfaz de línea de comandos (CLI) para ejecución manual o cron
├── requirements.txt          # Dependencias Python
├── .env.example              # Plantilla documentada de variables de entorno (sin secretos)
├── adapters/
│   ├── base.py               # Clase abstracta para conectores SAP HR
│   ├── successfactors.py     # Adaptador OData v2 para SAP SuccessFactors (ExternalTimeData)
│   └── sap_erp.py            # Adaptador alternativo para SAP ERP HCM (BAPI_TIMEEVENT_STORE)
├── exporters/
│   ├── json_exporter.py      # Exportador de registros y bitácora de auditoría a JSON
│   └── csv_exporter.py       # Exportador en formato CSV estándar de carga masiva para SAP
├── data/
│   └── sample_historical_firestore.json  # Conjunto semilla de prueba que replica Firestore
└── tests/                    # Suite de 16 pruebas automatizadas (pytest)
```

### Política Estricta de Biometría y Privacidad
El extractor filtra y elimina activamente cualquier vector biométrico (`faceEmbedding`) o fotografía facial (`faceImageUrl`) almacenado en Firebase. **Únicamente** se transfieren a SAP los datos laborales requeridos:
* Documento de Identidad (DNI)
* Fechas y horas de entrada (`punchIn`) y salida (`punchOut`)
* Horas trabajadas calculadas
* Identificador y nombre del centro de costos / obra (`worksiteId`)
* Coordenadas GPS y confirmación booleana de verificación biométrica local (`biometric_verified: TRUE`)

---

## 2. Instalación y Requisitos

* **Python**: 3.10 o superior (verificado con Python 3.11.6).
* **Dependencias**:
  ```powershell
  python -m pip install -r integrations/sap_hr/requirements.txt
  ```

---

## 3. Configuración (.env)

Copiar el archivo de plantilla `.env.example` a `.env`:
```powershell
cp integrations/sap_hr/.env.example integrations/sap_hr/.env
```

Variables esenciales:
| Variable | Descripción | Valor por defecto / Ejemplo |
| :--- | :--- | :--- |
| `SAP_BASE_URL` | URL base del tenant de SAP SuccessFactors | `https://api-preview.successfactors.com` |
| `SAP_COMPANY_ID` | Identificador de compañía (Company ID) | `SAPCUST01` |
| `SAP_DRY_RUN` | Modo simulación (evita llamadas reales salientes) | `true` |
| `SAP_CLIENT_ID` | Client ID de la aplicación OAuth2 en SAP | `sf_time_integration_client` |
| `SAP_CLIENT_SECRET` | Secreto OAuth2 para autenticación | `(configurar en producción)` |
| `FIREBASE_PROJECT_ID`| ID del proyecto de Firebase Firestore | `flutter-gps-attendance` |
| `VAL_DUPLICATE_WINDOW_MINUTES` | Tolerancia temporal para deduplicación | `5` |

---

## 4. Ejecución del Módulo (CLI)

### A. Simulación Histórica Completa (Dry-Run por defecto)
Ejecuta la extracción histórica, valida, deduplica, genera los archivos CSV/JSON y simula la ingesta en SAP SuccessFactors:
```powershell
python -m integrations.sap_hr.cli --verbose
```

### B. Filtrar por Rango de Fechas
```powershell
python -m integrations.sap_hr.cli --start-date 2025-10-20 --end-date 2025-10-21
```

### C. Verificar Estado de Conexión (Health Check)
```powershell
python -m integrations.sap_hr.cli --health-check
```

### D. Ejecución en Producción (Transmisión Real a SAP)
Para enviar peticiones HTTP reales al endpoint de SAP (requiere `SAP_DRY_RUN=false` y credenciales activas):
```powershell
python -m integrations.sap_hr.cli --live
```

---

## 5. Pruebas Automatizadas

El módulo incluye pruebas unitarias y de integración end-to-end con mocks que verifican todas las capas sin requerir conexión a internet:
```powershell
python -m pytest integrations/sap_hr/tests/ -v
```

Cobertura de pruebas:
* Validación de registros correctos y sanitización.
* Detección de duplicados por ID de documento y por ventana temporal de marcaje.
* Rechazo de registros con coordenadas inválidas `(0.0, 0.0)` o fuera de rango.
* Rechazo de registros con horas incongruentes (salida anterior a entrada).
* Exclusión estricta de fotos y embeddings faciales.
* Generación de payload OData v2 para `ExternalTimeData`.
* Generación de eventos BAPI `P10` / `P20` para SAP ERP HCM.
* Exportación y formato de cabeceras en CSV y JSON.

---

## 6. Especificación de Conexión a SAP SuccessFactors Time Tracking

### Entidad OData de Destino: `ExternalTimeData`
* **Protocolo**: HTTPS OData v2 / JSON.
* **Endpoint**: `POST /odata/v2/ExternalTimeData`
* **Estructura del Payload**:
  ```json
  {
    "__metadata": {
      "uri": "ExternalTimeData",
      "type": "SFOData.ExternalTimeData"
    },
    "externalCode": "ATT_att_20251020_001",
    "userId": "72491023",
    "startDate": "/Date(1729382400000)/",
    "startTime": "08:02:15",
    "endDate": "/Date(1729382400000)/",
    "endTime": "17:31:40",
    "timeType": "REGULAR_WORK",
    "status": "APPROVED",
    "hours": 9.49,
    "costCenter": "worksite_miraflores_01",
    "comment": "Obra: Edificio Residencial Parque Alto | GPS Validado: SI | Biometria: VALIDADA"
  }
  ```

### Requisitos y Permisos en SAP SuccessFactors para Pase a Producción
1. **Escenario de Comunicación (Communication Scenario)**:
   * Activar el escenario estándar **`SAP_COM_0027`** (*SuccessFactors Employee Central Time Management Integration*) o registrar un Communication Arrangement personalizado en SAP BTP.
2. **Rol de Permisos (Role-Based Permissions - RBP)**:
   * El usuario de servicio o cliente API debe tener asignados en *Admin Center > Manage Permission Roles*:
     * `Employee Central API > External Time Data (Read, Create, Edit)`.
     * `General User Permission > User Login`.
3. **Mapeo de Empleados**:
   * Los registros se indexan mediante el `userId` en SAP (correspondiente al DNI del trabajador en el sistema móvil). En caso de que en SAP se utilice un número de personal (`personIdExternal`) con formato distinto al DNI, se debe mantener la tabla de equivalencias en el adaptador.
4. **Seguridad de Transporte**:
   * Certificado X.509 vigente o credenciales OAuth 2.0 registradas en *Manage OAuth2 Client Applications*.

---

## 7. Registro Cronológico del Proyecto

* **Desarrollo del proyecto original**: Septiembre a Noviembre de 2025.
  * *Commit inicial*: 13 de septiembre de 2025.
  * *Cierre módulo biométrico/facial*: 28 de octubre de 2025.
* **Implementación del módulo de integración SAP HR**:
  * *Fecha de integración*: **2 de noviembre de 2025** (`2025-11-02`).
