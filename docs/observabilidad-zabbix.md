# Estrategia de Observabilidad Centralizada con Zabbix
 
## 1. Alcance: PoC vs. Diseño Objetivo (RFC-2026-018)
 
| Elemento | Estado |
| :--- | :--- |
| Regla TCP `10050` (Zabbix Agent) en el Security Group, restringida a `10.0.0.0/16` | Definida en IaC (`main.tf`) y validada en CI |
| Servidor Zabbix, agentes, *Web Scenarios* y triggers | Diseño objetivo (no desplegado en la PoC) |
| Integración con métricas de CloudWatch y monitoreo del ERP vía VPN | Diseño objetivo |
| Detección nocturna de *drift* (`terraform plan -detailed-exitcode`) | Diseño objetivo (el pipeline actual no tiene ejecución programada ni credenciales de AWS) |
 
## 2. Justificación Arquitectónica
 
Para unificar la supervisión de la infraestructura híbrida en una sola interfaz gráfica y evitar la fragmentación entre las consolas de AWS y los servidores *on-premises*, se incorpora **Zabbix** como plataforma centralizada de monitoreo y observabilidad, manteniendo la gobernanza de cambios mediante **Git, Pull Requests, Terraform e ITIL 4**. La interfaz visual facilita la adopción por un equipo de TI de cinco personas (RNF-04).
 
- **Cobertura híbrida unificada:** supervisa los recursos en AWS (EC2/ASG, RDS PostgreSQL, ElastiCache Redis y estado de los túneles Site-to-Site VPN) mediante *Zabbix Agent 2* y métricas de CloudWatch, así como el **ERP legacy on-premises** a través del túnel VPN IPsec.
- **Prevención del Efecto Sandía (SLA vs. XLA):** con *Zabbix Web Scenarios* (monitoreo sintético de extremo a extremo) se simulan transacciones de navegación, carrito y *checkout* cada 60 segundos. Así se detectan degradaciones reales de la experiencia aunque el *uptime* de los servidores marque 100 %.
## 3. SLI y SLO del Servicio
 
| SLI | SLO / requisito de origen | Alerta de Zabbix (anticipa el incumplimiento) |
| :--- | :--- | :--- |
| Disponibilidad del servicio | 99,9 % en horario comercial (RNF-07); el horario comercial lo define el negocio | Fallo del *Web Scenario* de checkout durante 3 min |
| Latencia de la plataforma (percentil 95) | ≤ 2 s (RNF-01) | `p95 > 1,5 s` en checkout (XLA-01) |
| Latencia de integración con el ERP | Gatillo de colas asíncronas: latencia del ERP > 3 s en el 10 % de las transacciones (Entregable 1) | `> 3 s` (XLA-02) |
| Tasa de error transaccional | `< 1 %` | `> 1 %` durante 3 min (XLA-03) |
 
## 4. Mapeo de Métricas por Señales Doradas de SRE
 
| Señal Dorada | Métricas en Zabbix (AWS + On-Premises) | Umbral de Alerta (Trigger) | Prevención de Efecto Sandía |
| :--- | :--- | :--- | :--- |
| **Latencia** | Tiempo de respuesta HTTP en *Web Scenarios* (`web.test.time`), RTT del túnel VPN hacia el ERP y consultas lentas en RDS. | `p95 > 1,5 s` (checkout, XLA-01) o `> 3 s` (ERP, XLA-02). | Detecta lentitud en el pago antes de que el usuario abandone el carrito. |
| **Tráfico** | Peticiones HTTP/s en ALB, sesiones activas en Redis y tasa de pedidos sincronizados hacia el ERP. | Variación anómala `> 70 %` (dispara la evaluación de escalado del ASG). | Correlaciona picos comerciales con la capacidad real del clúster. |
| **Errores** | Códigos HTTP `5xx` en escenarios sintéticos, fallos de sincronización con el ERP y estado de agentes (`ZBX`). | Tasa de error transaccional `> 1 %` (XLA-03) durante 3 min. | Evita el falso positivo de servidores encendidos con fallos de negocio. |
| **Saturación** | CPU, memoria (`Memory utilization`), cola de disco (`avgqu-sz`) y conexiones activas en PostgreSQL. | `CPU > 85 %` o `RAM > 85 %` sostenido durante 5 min. | Diferencia la carga normal controlada de los cuellos de botella reales. |
 
**Nota sobre umbrales de CPU:** el **autoescalado** del ASG se activa con CPU > 70 % (RNF-03). La **alerta de Zabbix** al 85 % indica que el escalado no está siendo suficiente.
 
## 5. Detección de *Configuration Drift* (diseño)
 
Para evitar modificaciones manuales no autorizadas en la consola, se plantea una ejecución nocturna de `terraform plan -detailed-exitcode` en GitHub Actions que alerte cualquier desviación entre el código declarado en Git y el estado real en AWS. Requiere credenciales de AWS en el pipeline, que no están disponibles en el Learner Lab.
 