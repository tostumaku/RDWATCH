<?php
/**
 * ╔═══════════════════════════════════════════════════════════════╗
 * ║  RD-WATCH: INSTALADOR DE BASE DE DATOS                        ║
 * ║  Script automatizado para crear y poblar la base de datos     ║
 * ╚═══════════════════════════════════════════════════════════════╝
 * 
 * USO: Ejecutar desde terminal: php install_db.php
 * o abrir directamente desde el navegador.
 */

$host = '127.0.0.1';
$port = '5432';
$adminUser = 'postgres';
$adminPass = ''; // Cambiar si PostgreSQL tiene contraseña
$dbName = 'rdwatch_db';

echo "\n";
echo "╔═══════════════════════════════════════════════════════════════╗\n";
echo "║          RD-WATCH :: INSTALADOR DE BASE DE DATOS             ║\n";
echo "╚═══════════════════════════════════════════════════════════════╝\n";
echo "\n";

// Detectar contraseña del .env si existe
$envPath = __DIR__ . '/.env';
if (file_exists($envPath)) {
    $env = parse_ini_file($envPath);
    $adminUser = $env['DB_USER'] ?? $adminUser;
    $adminPass = $env['DB_PASS'] ?? $adminPass;
    $host = $env['DB_HOST'] ?? $host;
    $port = $env['DB_PORT'] ?? $port;
    $dbName = $env['DB_NAME'] ?? $dbName;
    echo "✓ Configuración cargada desde .env\n\n";
}

try {
    // 1. CONECTAR A POSTGRESQL (base de datos del sistema)
    echo "[1/5] Conectando a PostgreSQL...\n";
    $dsnAdmin = "pgsql:host=$host;port=$port;dbname=postgres";
    $pdoAdmin = new PDO($dsnAdmin, $adminUser, $adminPass);
    $pdoAdmin->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "✓ Conexión exitosa a PostgreSQL\n\n";

    // 2. VERIFICAR SI LA BASE DE DATOS EXISTE
    echo "[2/5] Verificando base de datos '$dbName'...\n";
    $stmt = $pdoAdmin->query("SELECT 1 FROM pg_database WHERE datname = '$dbName'");
    
    if ($stmt->fetch()) {
        echo "⚠ La base de datos '$dbName' ya existe.\n";
        echo "  ¿Deseas eliminar y recrear? (s/n): ";
        
        // En CLI, esperar respuesta
        if (php_sapi_name() === 'cli') {
            $handle = fopen("php://stdin", "r");
            $line = trim(fgets($handle));
            fclose($handle);
        } else {
            $line = 'n'; // En navegador, no eliminar por defecto
        }
        
        if (strtolower($line) === 's') {
            echo "  Eliminando base de datos existente...\n";
            $pdoAdmin->exec("DROP DATABASE IF EXISTS $dbName");
            echo "  ✓ Base de datos eliminada\n";
        } else {
            echo "  Continuando con la base de datos existente...\n";
        }
    }

    // 3. CREAR BASE DE DATOS
    echo "[3/5] Creando base de datos '$dbName'...\n";
    $pdoAdmin->exec("CREATE DATABASE $dbName");
    echo "✓ Base de datos creada exitosamente\n\n";
    
    // Cerrar conexión admin
    $pdoAdmin = null;

    // 4. CONECTAR A LA NUEVA BASE DE DATOS
    echo "[4/5] Conectando a la nueva base de datos...\n";
    $dsn = "pgsql:host=$host;port=$port;dbname=$dbName";
    $pdo = new PDO($dsn, $adminUser, $adminPass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "✓ Conexión exitosa a '$dbName'\n\n";

    // 5. EJECUTAR SCRIPTS SQL
    echo "[5/5] Ejecutando scripts SQL...\n";
    echo str_repeat("-", 60) . "\n";

    // Forzar encoding UTF-8 en la conexión
    $pdo->exec("SET client_encoding TO 'UTF8'");

    $scripts = [
        // 1. Schema
        'sql/schema/database_rdwatch_3_0.sql' => 'Schema principal (tablas)',
        // 2. Migraciones
        'sql/oauth_migration.sql' => 'Migración OAuth',
        // 3. Triggers
        'sql/triggers/audit_trail.sql' => 'Triggers de auditoría',
        // 4. Seeds
        'sql/scripts/00_geodata.sql' => 'Departamentos y ciudades',
        'sql/scripts/01_users_base.sql' => 'Usuarios base',
        'sql/scripts/02_users_extended.sql' => 'Usuarios extendidos',
        'sql/scripts/03_catalog.sql' => 'Catálogo (marcas, productos, servicios)',
        'sql/scripts/04_activity.sql' => 'Actividad (órdenes, pagos)',
        'sql/scripts/05_reviews.sql' => 'Reseñas',
        'sql/scripts/06_configuracion_admin_pending.sql' => 'Configuración admin',
        // 5. Funciones backend
        'sql/logica_backend/auth_security.sql' => 'Funciones: Auth y Seguridad',
        'sql/logica_backend/catalog_master.sql' => 'Funciones: Catálogo',
        'sql/logica_backend/client_panel.sql' => 'Funciones: Panel Cliente',
        'sql/logica_backend/ecommerce_core.sql' => 'Funciones: E-commerce Core',
        'sql/logica_backend/admin_reports.sql' => 'Funciones: Reportes Admin',
    ];

    foreach ($scripts as $scriptPath => $description) {
        $fullPath = __DIR__ . '/' . $scriptPath;
        
        if (!file_exists($fullPath)) {
            echo "  ⚠ SKIP: $scriptPath no encontrado\n";
            continue;
        }

        echo "  ↳ Ejecutando: $description...\n";
        
        $sql = file_get_contents($fullPath);
        
        // Dividir por punto y coma y ejecutar cada statement
        $statements = array_filter(array_map('trim', explode(';', $sql)), fn($s) => !empty($s) && substr($s, 0, 2) !== '--');
        
        $count = 0;
        $errors = [];
        
        foreach ($statements as $statement) {
            // Saltar comentarios y líneas vacías
            if (empty(trim($statement)) || preg_match('/^--/', trim($statement))) {
                continue;
            }
            
            try {
                $pdo->exec($statement);
                $count++;
            } catch (PDOException $e) {
                // Ignorar errores de ON CONFLICT (son esperados para datos duplicados)
                if (strpos($e->getMessage(), 'ON CONFLICT') === false) {
                    $errors[] = "  ⚠ Error: " . substr($e->getMessage(), 0, 100);
                }
            }
        }
        
        echo "    ✓ $count comandos ejecutados";
        if (count($errors) > 0) {
            echo " (" . count($errors) . " advertencias)";
        }
        echo "\n";
    }

    echo str_repeat("-", 60) . "\n";
    echo "\n";

    // RESUMEN
    echo "╔═══════════════════════════════════════════════════════════════╗\n";
    echo "║                    ¡INSTALACIÓN COMPLETA!                     ║\n";
    echo "╚═══════════════════════════════════════════════════════════════╝\n";
    echo "\n";
    echo "  Base de datos: $dbName\n";
    echo "  Host: $host:$port\n";
    echo "\n";
    echo "  CREDENCIALES DE ACCESO:\n";
    echo "  ─────────────────────────────────────────\n";
    echo "  Admin:\n";
    echo "    Correo: admin@rdwatch.com\n";
    echo "    Contraseña: Admin123!\n";
    echo "\n";
    echo "  Cliente de prueba:\n";
    echo "    Correo: cliente@rdwatch.com\n";
    echo "    Contraseña: Cliente123!\n";
    echo "\n";
    echo "  📝 IMPORTANTE: Asegúrate de que el archivo .env tenga las credenciales correctas:\n";
    echo "     DB_HOST=$host\n";
    echo "     DB_PORT=$port\n";
    echo "     DB_NAME=$dbName\n";
    echo "     DB_USER=$adminUser\n";
    echo "     DB_PASS=****\n";
    echo "\n";

} catch (PDOException $e) {
    echo "\n";
    echo "╔═══════════════════════════════════════════════════════════════╗\n";
    echo "║                       ¡ERROR!                                 ║\n";
    echo "╚═══════════════════════════════════════════════════════════════╝\n";
    echo "\n";
    echo "  Mensaje: " . $e->getMessage() . "\n\n";
    
    echo "  POSIBLES SOLUCIONES:\n";
    echo "  ─────────────────────────────────────────\n";
    echo "  1. ¿PostgreSQL está instalado?\n";
    echo "     Descárgalo de: https://www.postgresql.org/download/\n\n";
    echo "  2. ¿El servicio de PostgreSQL está corriendo?\n";
    echo "     Windows: Buscar 'Services' > 'postgresql-x64-*' > Iniciar\n\n";
    echo "  3. ¿Las credenciales son correctas?\n";
    echo "     Por defecto PostgreSQL usa:\n";
    echo "       Usuario: postgres\n";
    echo "       Contraseña: (vacía en instalación local)\n\n";
    echo "  4. ¿Quieres usar XAMPP MySQL en su lugar?\n";
    echo "     En ese caso, necesitas migrar el proyecto a MySQL.\n";
    echo "     Puedo ayudarte con eso si lo necesitas.\n";
    echo "\n";
    exit(1);
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>RD-Watch | Instalador de Base de Datos</title>
    <style>
        :root {
            --success: #10b981;
            --bg: #0f172a;
            --card: #1e293b;
            --text: #f1f5f9;
            --muted: #94a3b8;
        }
        body {
            font-family: 'Fira Code', monospace;
            background: var(--bg);
            color: var(--text);
            min-height: 100vh;
            margin: 0;
            padding: 2rem;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
        }
        h1 {
            color: var(--success);
            text-align: center;
        }
        .info {
            background: var(--card);
            padding: 1.5rem;
            border-radius: 12px;
            margin-top: 2rem;
        }
        .info h3 {
            margin-top: 0;
            color: var(--success);
        }
        code {
            background: #334155;
            padding: 0.2rem 0.5rem;
            border-radius: 4px;
        }
        pre {
            background: #334155;
            padding: 1rem;
            border-radius: 8px;
            overflow-x: auto;
        }
        .btn {
            display: inline-block;
            background: var(--success);
            color: white;
            padding: 0.75rem 1.5rem;
            text-decoration: none;
            border-radius: 8px;
            margin-top: 1rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>RD-Watch :: Instalador</h1>
        <div class="info">
            <h3>📋 Instrucciones de uso</h3>
            <p>Este script se ejecuta mejor desde la terminal:</p>
            <pre>cd C:\xampp\htdocs\RD_WATCH\src\backend
php install_db.php</pre>
            <p>También puedes abrirlo directamente en el navegador, pero la terminal es mejor.</p>
            <a href="test_connection.php" class="btn">Verificar conexión después</a>
        </div>
    </div>
</body>
</html>
