# Estrategia de Observabilidad Centralizada con Zabbix

## 1. Justificación Arquitectónica (RFC-2026-018)
Para unificar la supervisión de la infraestructura híbrida en una sola interfaz gráfica y evitar la fragmentación entre consolas de AWS y servidores *on-premises*, se incorpora **Zabbix** como plataforma centralizada de monitoreo y observabilidad, manteniendo intacta la gobernanza de cambios mediante **Git, Pull Requests, Terraform e ITIL 4**.

* **Cobertura Híbrida Unificada:** Supervisa tanto los recursos en AWS (EC2/ASG, RDS PostgreSQL, ElastiCache Redis y estado de túneles Site-to-Site VPN) mediante *Zabbix Agent 2* y métricas CloudWatch integradas, como el **ERP legacy on-premises** a través del túnel VPN IPsec.
* **Prevención del Efecto Sandía (SLA vs. XLA):** Mediante *Zabbix Web Scenarios* (monitoreo sintético *end-to-end*), se ejecutan transacciones simuladas de navegación, carrito y *checkout* cada 60 segundos para detectar degradaciones reales de experiencia aunque el *uptime* de los servidores marque 100 % en verde.

## 2. Mapeo de Métricas por Señales Doradas de SRE

| Señal Dorada | Métricas en Zabbix (AWS + On-Premises) | Umbral de Alerta (Trigger) | Prevención de Efecto Sandía |
| :--- | :--- | :--- | :--- |
| **Latencia** | Tiempo de respuesta HTTP en *Web Scenarios* (`web.test.time`), latencia RTT del túnel VPN hacia el ERP y consultas lentas en RDS. | `p95 > 1.5 s` (Checkout XLA-01) o `> 3 s` (ERP XLA-02). | Detecta lentitud en el pago antes de que el usuario abandone el carrito. |
| **Tráfico** | Peticiones HTTP/s en ALB, sesiones activas en Redis y tasa de pedidos sincronizados hacia el ERP. | Variación anómala `> 70 %` (dispara evaluación de escalado ASG). | Correlaciona picos comerciales con capacidad real del clúster. |
| **Errores** | Códigos HTTP `5xx` en escenarios sintéticos, fallos de sincronización ERP y estado de agentes (`ZBX`). | Tasa de error transaccional `> 1 %` (XLA-03) durante 3 min. | Evita el falso positivo de servidores encendidos con fallos de negocio. |
| **Saturación** | Uso de CPU, memoria RAM (`Memory utilization`), cola de disco (`avgqu-sz`) y conexiones activas en PostgreSQL. | `CPU > 85 %` o `RAM > 90 %` sostenido por 5 min. | Diferencia carga normal controlada de cuellos de botella reales. |