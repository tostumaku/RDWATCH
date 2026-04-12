@echo off
title RDWATCH - Instalador Maestro v3.2
color 0B
setlocal enabledelayedexpansion

echo =====================================================
echo    RDWATCH - INSTALADOR DE BASE DE DATOS v3.2
echo    Cambios v3.2: Fix encoding UTF-8, subcategorias
echo    soft-delete, limpieza de overloads
echo =====================================================

:: --- CONFIGURACIÓN ---
set PG_PSQL="C:\Program Files\PostgreSQL\17\bin\psql.exe"
set DB_HOST=localhost
set DB_NAME=db_rdwatch
set DB_USER=postgres
set PGPASSWORD=toby,2003
set PGCLIENTENCODING=UTF8

:: Comando base para psql ejecutando sobre la BD del proyecto
set PSQL_CMD=%PG_PSQL% -h %DB_HOST% -U %DB_USER% -d %DB_NAME% -q --pset=pager=off
:: Comando sobre base 'postgres' (para operaciones de nivel BD)
set PSQL_ADMIN=%PG_PSQL% -h %DB_HOST% -U %DB_USER% -d postgres -q --pset=pager=off

echo.
echo [0/5] Recreando base de datos limpia...
%PSQL_ADMIN% -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '%DB_NAME%' AND pid <> pg_backend_pid();" 2>nul
%PSQL_ADMIN% -c "DROP DATABASE IF EXISTS \"%DB_NAME%\";" || goto :error
%PSQL_ADMIN% -c "CREATE DATABASE \"%DB_NAME%\";" || goto :error
echo    Base de datos '%DB_NAME%' creada desde cero.

echo.
echo [1/5] Cargando Esquema Base...
%PSQL_CMD% -f "..\sql\schema\database_rdwatch_3_0.sql" || goto :error

echo [2/5] Aplicando Migraciones (OAuth, etc.)...
%PSQL_CMD% -f "..\sql\oauth_migration.sql" || goto :error

echo [3/5] Instalando Triggers y Auditoria...
%PSQL_CMD% -f "..\sql\triggers\audit_trail.sql" || goto :error

echo [4/5] Desplegando Logica de Backend (Funciones)...
echo    - cargando: auth_security.sql
%PSQL_CMD% -f "..\sql\logica_backend\auth_security.sql" || goto :error
echo    - cargando: catalog_master.sql
%PSQL_CMD% -f "..\sql\logica_backend\catalog_master.sql" || goto :error
echo    - cargando: client_panel.sql
%PSQL_CMD% -f "..\sql\logica_backend\client_panel.sql" || goto :error
echo    - cargando: ecommerce_core.sql
%PSQL_CMD% -f "..\sql\logica_backend\ecommerce_core.sql" || goto :error
echo    - cargando: admin_reports.sql
%PSQL_CMD% -f "..\sql\logica_backend\admin_reports.sql" || goto :error

echo [5/5] Poblando Semillas y Datos Maestros...
echo    - insertando: 00_geodata.sql
%PSQL_CMD% -f "..\sql\scripts\00_geodata.sql" || goto :error
echo    - insertando: 01_users_base.sql
%PSQL_CMD% -f "..\sql\scripts\01_users_base.sql" || goto :error
echo    - insertando: 02_users_extended.sql
%PSQL_CMD% -f "..\sql\scripts\02_users_extended.sql" || goto :error
echo    - insertando: 03_catalog.sql
%PSQL_CMD% -f "..\sql\scripts\03_catalog.sql" || goto :error
echo    - insertando: 04_activity.sql
%PSQL_CMD% -f "..\sql\scripts\04_activity.sql" || goto :error
echo    - insertando: 05_reviews.sql
%PSQL_CMD% -f "..\sql\scripts\05_reviews.sql" || goto :error
echo    - insertando: 06_configuracion_admin_pending.sql
%PSQL_CMD% -f "..\sql\scripts\06_configuracion_admin_pending.sql" || goto :error

echo.
echo =====================================================
echo    INSTALACION COMPLETADA EXITOSAMENTE (V3.2)
echo    - Base de datos limpia (sin overloads)
echo    - Encoding UTF-8 correcto (tildes ok)
echo    - Soft-delete en subcategorias funcional
echo =====================================================
pause
exit /b 0

:error
echo.
echo [ERROR] La instalacion fallo en el ultimo paso.
pause
exit /b 1
