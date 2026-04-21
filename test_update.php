<?php
require_once 'src/backend/config.php';

try {
    $stmt = $pdo->query("SELECT routine_name, data_type, routine_schema FROM information_schema.routines WHERE routine_name = 'fn_cat_update_subcategoria'");
    $funcs = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "Functions:\n";
    print_r($funcs);

    $stmt2 = $pdo->query("SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'fn_cat_update_subcategoria'");
    $defs = $stmt2->fetchAll(PDO::FETCH_ASSOC);
    echo "\nDefinitions:\n";
    print_r($defs);
    
} catch (PDOException $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
