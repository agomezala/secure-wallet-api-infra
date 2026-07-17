# Secure Wallet API -- Infraestructura AWS

Infraestructura como codigo (IaC) con Terraform para una API serverless sobre AWS ECS Fargate, disenada para empresas que necesita un entorno productivo seguro, escalable y mantenible sin dedicar un equipo de DevOps a tiempo completo.

---

## Arquitectura

```
                          INTERNET
                             |
                     +-------v--------+
                     |   ALB (Capa 7)  |  Multi-AZ, puertos 80/443
                     +-------+--------+
                             |
              +--------------+--------------+
              |                             |
    eu-west-1a (AZ 1)              eu-west-1b (AZ 2)
    +---------------------+        +---------------------+
    | Subnet publica      |        | Subnet publica      |
    |  - NAT Gateway      |        |  - NAT Gateway      |
    |  - ALB nodes        |        |  - ALB nodes        |
    +---------------------+        +---------------------+
    | Subnet privada      |        | Subnet privada      |
    |  - ECS Fargate      |        |  - ECS Fargate      |
    +---------------------+        +---------------------+
    | Subnet de datos     |        | Subnet de datos     |
     |  - RDS PostgreSQL   |        |                     |
    +---------------------+        +---------------------+
```

---

## Decisiones de arquitectura

### Cada decision responde a una pregunta de negocio concreta.

---

### 1. Por que Fargate en lugar de EC2?

**Que elegimos:** AWS ECS Fargate como plataforma de computo.

**Por que:** Fargate elimina la gestion de servidores virtuales (EC2). No hay que parchear SO, dimensionar capacidad, ni mantener AMIs. En su lugar, se define la CPU y memoria que cada contenedor necesita y AWS se encarga de todo lo demas.

**Que gana la empresa:**

| Sin Fargate (EC2)                 | Con Fargate                        |
|-----------------------------------|------------------------------------|
| Parchear SO manualmente           | AWS gestiona el SO automaticamente |
| Dimensionar y escalar instancias  | Escalado al contenedor, no a la maquina |
| Pagar por servidores ociosos      | Pagar solo por lo que se ejecuta   |
| Un DevOps dedicado a mantener EC2 | 0 mantenimiento de infraestructura |
| Tareas de operacion constantes    | El equipo se centra en el producto |

**Impacto:** Un equipo pequeno no puede permitirse dedicar una persona al mantenimiento de servidores. Fargate absorbe ese coste operativo en el precio del servicio, liberando al equipo para desarrollar funcionalidad de negocio.

---

### 2. Por que Multi-AZ con NAT Gateway por zona?

**Que elegimos:** 2 zonas de disponibilidad con NAT Gateway independiente en cada una.

**Por que:** La alternativa tipica (1 solo NAT Gateway compartido entre zonas) ahorra ~32$/mes pero crea un punto unico de fallo: si la zona que aloja el NAT cae, toda la capa privada pierde conectividad a internet, aunque las tareas en la otra zona sigan funcionando (no podran, por ejemplo, llamar a APIs externas ni descargar imagenes de ECR).

**Que gana la empresa:**

- **Tolerancia a fallo real.** Si un centro de datos de AWS queda indisponible (ha pasado), la aplicacion sigue funcionando en la otra zona sin intervencion manual.
- **Alta disponibilidad parcial.** La capa de red y aplicacion son multi-AZ. RDS se mantiene como Single-AZ en esta demostracion para minimizar costes, pero es configurable a Multi-AZ con un cambio de variable.
- **Coste adicional controlado:** ~32$/mes por el segundo NAT Gateway. En terminos de negocio, es el coste de <1 hora de downtime evitado.

**Decision consciente:** Si el presupuesto lo exige, se puede reducir a 1 NAT Gateway compartido cambiando una variable. La arquitectura actual prioriza la disponibilidad sobre el ahorro marginal.

---

### 3. Por que segregar la red en 3 capas (publica / privada / datos)?

**Que elegimos:** 3 tipos de subred por zona de disponibilidad, con firewalls (Security Groups) en cadena.

**Por que:** El modelo de defensa en profundidad parte de un principio sencillo: si un atacante compromete una capa, no debe poder acceder a la siguiente.

```
Internet --> [SG ALB:80/443] --> ALB --> [SG ECS:8080] --> Fargate --> [SG RDS:5432] --> PostgreSQL
```

- **El ALB** solo acepta trafico HTTP/HTTPS del mundo exterior.
- **La capa de aplicacion (ECS)** solo acepta trafico que proviene del ALB. Ningun otro origen.
- **La base de datos (RDS)** solo acepta conexiones desde la capa de aplicacion. No tiene IP publica. No es accesible desde internet.

**Que gana la empresa:**

- **Defensa en profundidad comprobable.** Los Security Groups son auditables: un auditor puede verificar en segundos que la base de datos no tiene exposicion publica.
- **Cumplimiento regulatorio.** Esta segmentacion es requisito en normativas como PCI-DSS, SOC2 e ISO 27001. Si la empresa necesita certificarse en el futuro, la base ya esta puesta.
- **Reduce la superficie de ataque.** Incluso si una vulnerabilidad en la aplicacion expone un endpoint, el atacante no puede llegar a la base de datos directamente.

---

### 4. Por que GitHub Actions con OIDC y no claves estaticas?

**Que elegimos:** Autenticacion via OpenID Connect (OIDC) entre GitHub Actions y AWS.

**Por que:** El metodo tradicional (crear un usuario IAM con claves de acceso, guardarlas en GitHub Secrets) tiene problemas graves:

| Claves estaticas (Access Key)        | OIDC                                    |
|--------------------------------------|-----------------------------------------|
| Hay que rotarlas manualmente         | Sin claves que rotar                    |
| Si se filtran, acceso permanente     | Token de corta duracion (~1h)           |
| Quien tiene la clave, tiene acceso   | Solo GitHub Actions desde tu repo puede asumir el rol |
| Visibles en Secrets de GitHub        | Nada que filtrar                        |

**Que gana la empresa:**

- **Elimina el riesgo de credenciales filtradas.** Es uno de los vectores de ataque mas comunes en empresas de este tamano. Con OIDC, no hay claves estaticas que un empleado pueda exponer accidentalmente en un commit, un log, o una captura de pantalla.
- **Vinculado al repositorio.** Solo `agomezala/secure-wallet-api` puede desplegar en esta cuenta de AWS. No se puede reutilizar la credencial en otro contexto.
- **Cumplimiento de seguridad.** Cualquier auditoria de seguridad valora positivamente la ausencia de secretos de larga duracion.

---

### 5. Por que RDS PostgreSQL con almacenamiento cifrado?

**Que elegimos:** Amazon RDS PostgreSQL 16, almacenamiento cifrado gp3, backups diarios con 1 dia de retencion.

**Por que:**

- **Cifrado en reposo:** AES-256 gestionado por AWS KMS. Sin coste adicional para gp3.
- **gp3 (SSD):** Mejor relacion precio/rendimiento que gp2. Permite ajustar IOPS y throughput independientemente del almacenamiento.
- **Backups automatizados:** Retencion de 1 dia. Restauracion a cualquier punto en el tiempo (PITR) dentro de esa ventana.
- **Multi-AZ disponible:** La configuracion actual es Single-AZ para minimizar costes en entornos de demostracion. Para produccion, activar `multi_az = true` proporciona failover automatico en ~60-120 segundos con una replica sincrona en otra zona de disponibilidad.

**Que gana la empresa:**

- **RPO ~5 minutos, RTO ~2 minutos.** Si la base de datos falla, se pierden como maximo 5 minutos de transacciones y la recuperacion toma ~2 minutos. Sin Multi-AZ, la misma recuperacion podria tomar horas y requeriria intervencion manual.
- **Sin DBA necesario.** RDS automatiza backups, parches de seguridad del motor, y failover. Una empresa de 12-50 personas tipicamente no tiene un DBA dedicado.
- **Cumplimiento GDPR.** El cifrado en reposo es requisito para el tratamiento de datos personales en la UE.

---

### 6. Por que Infraestructura como Codigo con Terraform y diseno modular?

**Que elegimos:** Terraform con modulos reutilizables. Cada zona de disponibilidad se despliega mediante un modulo `network-az` parametrizable.

**Por que:**

| ClickOps (consola AWS)              | Infraestructura como Codigo           |
|--------------------------------------|---------------------------------------|
| No hay trazabilidad de cambios       | Git guarda el historial completo      |
| Riesgo de deriva entre entornos      | Mismo codigo, mismos recursos         |
| Imposible replicar un entorno        | `terraform apply` y esta listo        |
| Depende de quien pulsa botones       | Pull request, revision, merge, apply  |
| Recuperacion ante desastre manual    | Reconstruccion automatizada           |

**El modulo `network-az` permite:**

1. **Anadir una tercera AZ en el futuro** anadiendo 4 lineas de configuracion sin duplicar 60 lineas de codigo.
2. **Replicar el entorno** (staging, produccion) con un cambio de variables, no de codigo.
3. **Onboarding rapido.** Un desarrollador nuevo entiende la infraestructura leyendo 7 archivos, no navegando la consola de AWS.

**Que gana la empresa:**

- **Velocidad de recuperacion.** Si hay que reconstruir todo desde cero (desastre, migracion de cuenta), se hace con un `terraform apply`. Minutos, no dias.
- **Revision entre pares.** Los cambios de infraestructura pasan por PR como el codigo de aplicacion. Esto elimina el riesgo de "alguien toco algo en AWS y ahora no funciona".
- **Evita vendor lock-in con Terraform.** Si en el futuro se necesita soporte multi-cloud, Terraform soporta cientos de providers. El conocimiento y los patrones se transfieren.

---

### 7. Por que un Application Load Balancer (ALB) y no un NLB o API Gateway?

**Que elegimos:** ALB (capa 7 - HTTP/HTTPS).

**Por que:** Para una API HTTP tradicional, el ALB es la opcion que mejor equilibra funcionalidad, coste y simplicidad:

| Criterio                  | ALB          | API Gateway       | NLB             |
|--------------------------|--------------|-------------------|-----------------|
| Enrutamiento por path    | Si           | Si                | No              |
| Integracion ECS nativa   | Si           | Requiere VPC Link | Si (TCP)        |
| Health checks            | Si           | No aplica         | Si (TCP)        |
| Coste                    | ~$20/mes fijo + trafico | ~$3.5/millon reqs | ~$20/mes |
| Certificados SSL/TLS     | ACM nativo   | ACM nativo        | ACM nativo      |

La eleccion: ALB porque integra con ECS de forma nativa, soporta health checks a nivel HTTP (el endpoint `/health` de la aplicacion), y tiene un coste predecible (tarifa plana + trafico) para una aplicacion de uso interno o B2B. API Gateway seria necesario si la API tuviera decenas de endpoints con enrutamiento complejo o se necesitara throttling por cliente.

---

## Costes estimados mensuales

| Recurso                     | Cantidad | Coste/mes (eu-west-1) | Notas                              |
|-----------------------------|----------|-----------------------|------------------------------------|
| ALB                         | 1        | ~$22                  | Tarifa fija + LCU minimas          |
| ECS Fargate (0.25 vCPU/0.5GB) | 1 task   | ~$15                  | 1 tarea para demostracion, escalable |
| ECR                         | 1 repo   | ~$1                   | Almacenamiento de imagenes Docker  |
| RDS PostgreSQL db.t3.micro  | 1        | ~$15                  | Single-AZ para minimizar costes    |
| NAT Gateways                | 2        | ~$72                  | $0.045/hora x 2 x 730h             |
| Elastic IPs                 | 2        | ~$7                   | Solo si no estan asociadas a un NAT|
| **Total estimado**          |          | **~$132/mes**         |                                    |

> **Nota:** El coste real depende del trafico y uso. Con auto-scaling, Fargate escala a 0 tareas fuera de horario laboral si se configura `aws_appautoscaling_target` con schedule, reduciendo costes significativamente.

---

## Modelo de seguridad resumido

1. **Sin claves estaticas.** OIDC para CI/CD.
2. **Red segmentada en 3 capas.** ALB publico, ECS privado, RDS aislado.
3. **Trafico inter-capa controlado.** Solo ALB -> ECS -> RDS en la direccion correcta.
4. **Base de datos sin IP publica.** Solo accesible via Security Group desde ECS.
5. **Cifrado en reposo.** RDS con AES-256. ECR compatible por defecto.
6. **Imagenes Docker inmutables.** `image_tag_mutability = "IMMUTABLE"` en ECR evita sobrescritura accidental de tags.
7. **Escaneo de vulnerabilidades automatico.** `scan_on_push = true` en ECR analiza cada imagen en busca de CVEs conocidos.
8. **Container Insights activado.** Metricas, logs y trazabilidad de cada contenedor.

---

## Proximos pasos recomendados

1. **Anadir HTTPS.** Generar un certificado via AWS Certificate Manager y anadir un listener en el puerto 443 que redirija o termine SSL. El ALB lo soporta de forma nativa sin coste extra por certificado.
2. **Configurar auto-scaling para ECS.** Definir `aws_appautoscaling_target` y politicas de escalado basadas en CPU/memoria. Permite que Fargate escale a 0 fuera de horario laboral.
3. **Anadir WAF.** AWS WAF en el ALB protege contra OWASP Top 10 (SQL injection, XSS, etc.) con reglas gestionadas por AWS.
4. **Parametrizar secretos.** Extraer la contrasena de RDS a AWS Secrets Manager (`aws_secretsmanager_secret`) y referenciarla dinamicamente en lugar de hardcodearla.
5. **Crear entorno de staging.** Replicar la misma configuracion con `environment = "staging"` y un RDS mas pequeno (db.t3.micro, sin Multi-AZ) para ahorrar costes.
6. **Anadir VPC Endpoints.** Para ECR y CloudWatch, evitar que el trafico salga a internet via NAT Gateway, reduciendo costes y mejorando seguridad.

---

## Estructura del proyecto y documentacion por archivo

### Directorio raiz

| Archivo              | Responsabilidad                                              |
|----------------------|--------------------------------------------------------------|
| `provider.tf`        | Region AWS. Aislado para facilitar multi-region futuro.      |
| `variables.tf`       | Variables de entrada: AZs, CIDRs, entorno.                   |
| `main.tf`            | VPC, IGW, OIDC GitHub, y llamada al modulo network-az.       |
| `security_groups.tf` | Firewall en 3 capas: ALB -> ECS -> RDS.                      |
| `load_balancer.tf`   | ALB, Target Group con health check en `/health`, Listener.   |
| `ecs.tf`             | Cluster Fargate, repositorio ECR, roles IAM.                 |
| `rds.tf`             | Subnet group y base de datos PostgreSQL Multi-AZ.            |
| `outputs.tf`         | Valores que se exportan tras `terraform apply`.              |

### Modulo `modules/network-az/`

| Archivo       | Responsabilidad                                      |
|---------------|------------------------------------------------------|
| `main.tf`     | 3 subnets (publica/privada/datos), NAT, route tables |
| `variables.tf`| Parametros de entrada: AZ, CIDRs, VPC, IGW          |
| `outputs.tf`  | IDs de subnets, NAT, route tables                    |

---

## Requisitos para desplegar

1. **AWS CLI** configurado con credenciales (`aws configure`).
2. **Terraform >= 1.0** instalado.
3. Permisos IAM suficientes en la cuenta AWS (AdministratorAccess recomendado para el primer despliegue).

```bash
terraform init
terraform plan  -out=tfplan
terraform apply "tfplan"
```

---

## Principios que guiaron las decisiones

1. **El coste del downtime supera el coste de la alta disponibilidad.** Una hora de caida para una PYME facturando puede costar mas que un ano de NAT Gateway extra.
2. **La seguridad se diseña, no se anade despues.** Las 3 capas de red, el OIDC y el cifrado estan integrados desde el dia 1.
3. **El equipo es pequeno; la infraestructura no debe consumir su tiempo.** Fargate, RDS gestionado e IaC eliminan tareas operativas repetitivas.
4. **Todo cambio debe ser trazable y reversible.** Terraform + Git garantiza auditoria completa y capacidad de rollback.
5. **Elegir tecnologia estandar, no exotica.** ECS, ALB, RDS PostgreSQL y Terraform son servicios maduros con documentacion abundante y amplia comunidad de soporte.
