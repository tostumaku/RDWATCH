#!/bin/bash
# ==============================================================================
# Script de Instalación y Reseteo de Base de Datos RD-Watch
# ==============================================================================

set -e

# Obtener el directorio raíz (un nivel arriba de donde está este script)
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

ENV_FILE="src/backend/.env"
if [ -f "$ENV_FILE" ]; then
    echo "[*] Cargando variables de entorno desde $ENV_FILE..."
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    echo "[ERROR] El archivo .env no fue encontrado en $ENV_FILE"
    exit 1
fi

DB_HOST=${DB_HOST:-192.168.1.52}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-db_rdwatch}
DB_USER=${DB_USER:-postgres}
export PGPASSWORD=${DB_PASS}
export PGCLIENTENCODING=UTF8

echo "[*] Cerrando conexiones activas y recreando la base de datos '$DB_NAME'..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "
DO \$\$ 
BEGIN 
    PERFORM pg_terminate_backend(pid) 
    FROM pg_stat_activity 
    WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid(); 
END \$\$;" > /dev/null 2>&1

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS \"$DB_NAME\";"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "CREATE DATABASE \"$DB_NAME\";"

echo "[*] Base de datos lista. Empezando ejecución de scripts SQL..."

run_sql() {
    local file=$1
    if [ -f "$file" ]; then
        echo -n "   -> Ejecutando: $(basename $file) ... "
        # Ejecutamos ocultando la salida estándar y filtrando los NOTICE del error estándar
        if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 --set=client_min_messages=warning -f "$file" > /dev/null 2> error.log; then
            echo -e "\e[32m[OK]\e[0m"
        else
            echo -e "\e[31m[ERROR]\e[0m"
            echo -e "\e[31m      Detalle:\e[0m"
            cat error.log | sed 's/^/      /'
            exit 1
        fi
        rm -f error.log
    else
        echo -e "   [!] Advertencia: Archivo no encontrado \e[33m$file\e[0m"
    fi
}

echo ""
echo "[1/5] Estructura y Esquema (Tablas)"
run_sql "sql/schema/database_rdwatch_3_0.sql"

echo ""
echo "[2/5] Migraciones (OAuth, etc.)"
run_sql "sql/oauth_migration.sql"

echo ""
echo "[3/5] Triggers y Auditoría"
run_sql "sql/triggers/audit_trail.sql"

echo ""
echo "[4/5] Poblando Datos (Datos Semilla)"
run_sql "sql/scripts/00_geodata.sql"
run_sql "sql/scripts/01_users_base.sql"
run_sql "sql/scripts/02_users_extended.sql"
run_sql "sql/scripts/03_catalog.sql"
run_sql "sql/scripts/04_activity.sql"
run_sql "sql/scripts/05_reviews.sql"
run_sql "sql/scripts/06_configuracion_admin_pending.sql"

echo ""
echo "[5/5] Lógica Backend Refactorizada (Funciones PostgreSQL)"
run_sql "sql/logica_backend/auth_security.sql"
run_sql "sql/logica_backend/catalog_master.sql"
run_sql "sql/logica_backend/ecommerce_core.sql"
run_sql "sql/logica_backend/client_panel.sql"
run_sql "sql/logica_backend/admin_reports.sql"

echo ""
echo "✅ Instalación completada exitosamente. El proyecto ahora mantiene el hilo conductor y la nueva estructura global."
