<?php
require_once 'src/backend/config.php';
header('Content-Type: text/plain');

try {
    $stmt = $pdo->prepare("SELECT fn_cat_update_subcategoria(?::INTEGER, ?::INTEGER, ?::TEXT, ?::BOOLEAN)");
    $stmt->execute([1, 4, 'Test Subcat', 'true']);
    print_r($stmt->fetchColumn());
} catch (PDOException $e) {
    echo "Error PDO: " . $e->getMessage() . "\n";
} catch (Throwable $e) {
    echo "Error General: " . $e->getMessage() . "\n";
}
