# respaldo-gitlab

Copia automática, cada hora, de **todos** los repos de GrupoPDC460 hacia GitLab
(ramas y tags, historial completo). Los repos nuevos se incluyen solos.

## Configuración (una sola vez)
En este repo → Settings → Secrets and variables → Actions:
- **Secret** `GITLAB_TOKEN`: token personal de GitLab con permisos `api` y `write_repository`.
- **Variable** `GITLAB_GROUP`: ruta del grupo o usuario de GitLab (ej. `grupopdc`).
- (Opcional) Variable `GITLAB_HOST` si no usan gitlab.com.

## Reglas
- GitLab es **solo espejo**: no hagas commits directo allá, o la copia fallará.
- Si un repo falla, la corrida queda en rojo y GitHub te avisa por correo.
- GitHub pausa los workflows programados tras 60 días sin actividad en este repo;
  si ves un aviso, entra a Actions y vuelve a activarlo.
