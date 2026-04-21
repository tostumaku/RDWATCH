#!/bin/bash
# ============================================================
# SCRIPT MAESTRO DE DESPLIEGUE SQL — RD-Watch E-commerce
# ============================================================
# Autor       : Sistema de Migración PostgreSQL
# Última Mod. : 2026-02-20
# ============================================================
#
# ORDEN LÓGICO DE EJECUCIÓN:
# ──────────────────────────
# 1. Schema (tablas base)        ← Primero: crea todas las tablas
# 2. Migraciones                 ← Segundo: altera tablas existentes
# 3. Triggers                    ← Tercero: auditoría (depende de tablas)
# 4. Funciones CRUD legacy       ← Cuarto: funciones que usan tablas
# 5. Datos semilla (scripts)     ← Quinto: inserts iniciales
# 6. Lógica Backend (blindaje)   ← Sexto: funciones de la migración PHP
#
# REGLA: Cada módulo de blindaje usa CREATE OR REPLACE FUNCTION,
# por lo que re-ejecutar NUNCA borra funciones de otros módulos.
# Tampoco hay conflictos entre módulos porque cada función tiene
# un nombre único con prefijo por dominio (fn_auth_, fn_cat_, etc.)
#
# USO:
#   chmod +x deploy_all.sh
#   ./deploy_all.sh
#
# VARIABLES DE ENTORNO (opcionales):
#   DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASS
# ============================================================

set -euo pipefail

# ─── CONFIGURACIÓN ───────────────────────────────────────────
DB_HOST="${DB_HOST:-192.168.1.52}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-db_rdwatch}"
DB_USER="${DB_USER:-postgres}"
DB_PASS="${DB_PASS:-ander123}"

# Directorio base (donde está este script) + subdirectorio SQL
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_DIR="$SCRIPT_DIR/sql"

# Colores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Contadores
TOTAL=0
OK=0
FAIL=0

# ─── FUNCIÓN HELPER ──────────────────────────────────────────
run_sql() {
    local file="$1"
    local label="$2"
    TOTAL=$((TOTAL + 1))

    if [ ! -f "$file" ]; then
        echo -e "  ${YELLOW}⚠ SKIP${NC} $label (archivo no encontrado: $file)"
        return 0
    fi

    echo -ne "  🔄 $label... "
    OUTPUT=$(PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$file" 2>&1)

    if [ $? -eq 0 ]; then
        # Contar funciones creadas
        FN_COUNT=$(echo "$OUTPUT" | grep -c "CREATE FUNCTION" || true)
        if [ "$FN_COUNT" -gt 0 ]; then
            echo -e "${GREEN}✅${NC} ($FN_COUNT funciones)"
        else
            echo -e "${GREEN}✅${NC}"
        fi
        OK=$((OK + 1))
    else
        echo -e "${RED}❌ ERROR${NC}"
        echo "$OUTPUT" | head -5
        FAIL=$((FAIL + 1))
    fi
}

# ─── INICIO ──────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  🐘 DESPLIEGUE SQL COMPLETO — RD-Watch E-commerce      ║${NC}"
echo -e "${BOLD}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}║  Servidor: ${CYAN}$DB_HOST:$DB_PORT${NC}${BOLD}                          ║${NC}"
echo -e "${BOLD}║  Base:     ${CYAN}$DB_NAME${NC}${BOLD}                                    ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ─── PASO 1: SCHEMA BASE ────────────────────────────────────
echo -e "${BOLD}📋 PASO 1/6: SCHEMA (Tablas base)${NC}"
run_sql "$SQL_DIR/schema/database_rdwatch_3_0.sql" "Schema principal (23 tablas)"
echo ""

# ─── PASO 2: MIGRACIONES ────────────────────────────────────
echo -e "${BOLD}🔧 PASO 2/6: MIGRACIONES (Alteraciones de tablas)${NC}"
run_sql "$SQL_DIR/migrations/add_foto_to_reservas.sql" "Migración: foto en reservas"
echo ""

# ─── PASO 3: TRIGGERS ───────────────────────────────────────
echo -e "${BOLD}⚡ PASO 3/6: TRIGGERS (Auditoría automática)${NC}"
run_sql "$SQL_DIR/triggers/audit_trail.sql" "Trigger: audit trail"
echo ""

# ─── PASO 4: FUNCIONES CRUD LEGACY ──────────────────────────
echo -e "${BOLD}🔩 PASO 4/6: FUNCIONES CRUD LEGACY${NC}"
for f in "$SQL_DIR"/functions/*.sql; do
    BASENAME=$(basename "$f" .sql)
    run_sql "$f" "CRUD: $BASENAME"
done
echo ""

# ─── PASO 5: DATOS SEMILLA ──────────────────────────────────
echo -e "${BOLD}🌱 PASO 5/6: DATOS SEMILLA (Scripts de inserción)${NC}"
# Orden específico: departamentos primero (FK de ciudades)
run_sql "$SQL_DIR/functions/inserts_departamentos_y_ciudades.sql" "Geodata: departamentos + ciudades"
for f in "$SQL_DIR"/scripts/*.sql; do
    BASENAME=$(basename "$f" .sql)
    run_sql "$f" "Seed: $BASENAME"
done
echo ""

# ─── PASO 6: LÓGICA BACKEND (BLINDAJE) ──────────────────────
# ORDEN CRÍTICO: Las dependencias van de menor a mayor complejidad
# Cada módulo usa CREATE OR REPLACE, así que:
# - NO borra funciones de otros módulos
# - Es 100% idempotente (se puede re-ejecutar sin riesgo)
#
# Orden lógico:
# 1. auth_security   → Base: usuarios, sesiones, rate limiting
# 2. catalog_master  → Usa: usuarios (quién crea productos)
# 3. ecommerce_core  → Usa: productos, usuarios (carrito, checkout)
# 4. client_panel    → Usa: usuarios, órdenes, opiniones (panel)
# 5. admin_reports   → Usa: TODO (reportes consolidados)

echo -e "${BOLD}🛡️  PASO 6/6: LÓGICA BACKEND — BLINDAJE POSTGRESQL${NC}"
echo -e "   ${CYAN}(Funciones CREATE OR REPLACE — idempotentes, sin conflictos)${NC}"
echo ""

run_sql "$SQL_DIR/logica_backend/auth_security.sql"   "Fase 1: Seguridad y Acceso"
run_sql "$SQL_DIR/logica_backend/catalog_master.sql"  "Fase 2: Catálogo e Inventario"
run_sql "$SQL_DIR/logica_backend/ecommerce_core.sql"  "Fase 3: Transacciones y Compras"
run_sql "$SQL_DIR/logica_backend/client_panel.sql"    "Fase 4: Panel de Cliente y Reseñas"
run_sql "$SQL_DIR/logica_backend/admin_reports.sql"   "Fase 5: Reportes y Facturación"
echo ""

# ─── RESUMEN FINAL ───────────────────────────────────────────
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}📊 RESUMEN DE DESPLIEGUE${NC}"
echo -e "   Total ejecutados: $TOTAL"
echo -e "   ${GREEN}Exitosos: $OK${NC}"

if [ $FAIL -gt 0 ]; then
    echo -e "   ${RED}Fallidos: $FAIL${NC}"
    echo ""
    echo -e "${RED}⚠️  Hay errores. Revise los mensajes anteriores.${NC}"
    exit 1
else
    echo -e "   ${RED}Fallidos: 0${NC}"
    echo ""

    # Contar funciones fn_ en la BD
    FN_TOTAL=$(PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
        "SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname LIKE 'fn_%';" 2>/dev/null || echo "?")

    echo -e "${GREEN}${BOLD}✅ DESPLIEGUE COMPLETADO SIN ERRORES${NC}"
    echo -e "${GREEN}   Funciones fn_* activas en la BD: $FN_TOTAL${NC}"
fi
echo ""
