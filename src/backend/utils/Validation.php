<?php
/**
 * Clase Validation
 * Utilidad para centralizar la validación y sanitización de datos de entrada
 * alineado con el estándar ISO IEEE 830 para RD Watch.
 */

class Validation
{

    /**
     * Valida nombres y textos simples sin caracteres especiales
     */
    public static function validateName($name)
    {
        // Permitir casi cualquier carácter imprimible, longitud 1-100 (límite de BD)
        return strlen(trim($name)) >= 1 && strlen($name) <= 100;
    }

    /**
     * Valida números de teléfono (exactamente 10 dígitos)
     */
    public static function validatePhone($phone)
    {
        return preg_match("/^[0-9]{10}$/", $phone);
    }

    /**
     * Valida correos electrónicos
     */
    public static function validateEmail($email)
    {
        return filter_var($email, FILTER_VALIDATE_EMAIL);
    }

    /**
     * Valida direcciones (permite letras, números, #, - and .)
     */
    public static function validateAddress($address)
    {
        return preg_match("/^[a-zA-Z0-9\s#\-\.]{5,150}$/", $address);
    }

    /**
     * Sanitiza strings para evitar inyecciones básicas y caracteres no deseados
     */
    public static function sanitizeString($str)
    {
        return htmlspecialchars(strip_tags(trim($str ?? '')));
    }

    /**
     * Valida si un valor es numérico y positivo (usado para IDs y precios)
     */
    public static function validateNumeric($val, $allowFloat = false)
    {
        if ($allowFloat) {
            return is_numeric($val) && (float)$val >= 0;
        }
        return is_numeric($val) && (int)$val > 0;
    }

    /**
     * Valida stock (entero no negativo)
     */
    public static function validateStock($stock)
    {
        return filter_var($stock, FILTER_VALIDATE_INT) !== false && (int)$stock >= 0;
    }

    /**
     * Valida precio (float positivo con hasta 2 decimales)
     */
    public static function validatePrice($price)
    {
        if (!is_numeric($price) || (float)$price < 0)
            return false;
        // Verifica que no tenga más de 2 decimales
        $parts = explode('.', (string)$price);
        if (isset($parts[1]) && strlen($parts[1]) > 2)
            return false;
        return true;
    }

    /**
     * Valida Documento de Identidad (alfanumérico, 5-15 caracteres)
     */
    public static function validateDocumentID($id)
    {
        return preg_match("/^[a-zA-Z0-9]{5,15}$/", $id);
    }

    /**
     * Valida Código Postal (exactamente 6 dígitos)
     */
    public static function validatePostalCode($zip)
    {
        return preg_match("/^[0-9]{6}$/", $zip);
    }

    /**
     * Valida formato básico de contraseña (mínimo 8 caracteres, alfanumérico/especial)
     */
    public static function validatePassword($pass)
    {
        return strlen($pass) >= 8;
    }

    /**
     * Validador Estricto: Centraliza el rechazo de datos inválidos (HTTP 400)
     * @param array $data Datos a validar
     * @param array $rules Reglas (ej: ['nombre' => 'name', 'telefono' => 'phone'])
     * @return bool|void Corta ejecución si falla
     */
    public static function validateOrReject($data, $rules)
    {
        foreach ($rules as $field => $type) {
            $value = $data[$field] ?? null;
            $isValid = false;

            if ($value === null || $value === '') {
                self::reject("El campo '$field' es obligatorio");
            }

            switch ($type) {
                case 'name':
                    $isValid = self::validateName($value);
                    break;
                case 'phone':
                    $isValid = self::validatePhone($value);
                    break;
                case 'email':
                    $isValid = self::validateEmail($value);
                    break;
                case 'address':
                    $isValid = self::validateAddress($value);
                    break;
                case 'stock':
                    $isValid = self::validateStock($value);
                    break;
                case 'price':
                    $isValid = self::validatePrice($value);
                    break;
                case 'id':
                    $isValid = self::validateNumeric($value);
                    break;
                case 'doc':
                    $isValid = self::validateDocumentID($value);
                    break;
                case 'zip':
                    $isValid = self::validatePostalCode($value);
                    break;
                case 'numeric':
                    $isValid = self::validateNumeric($value, true);
                    break;
                case 'password':
                    $isValid = self::validatePassword($value);
                    break;
            }

            if (!$isValid) {
                self::reject("El valor para '$field' no cumple con el estándar de formato requerido.");
            }
        }
    }

    private static function reject($msg)
    {
        http_response_code(400);
        header('Content-Type: application/json');
        echo json_encode(['ok' => false, 'error_type' => 'VALIDATION_ERROR', 'msg' => $msg]);
        exit;
    }
}
?>