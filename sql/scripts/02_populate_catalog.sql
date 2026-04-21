-- POBLACIÓN DE CATÁLOGO MAESTRO COMPLETO - RD WATCH V2
-- Propósito: Inventario de 55 productos y 10 servicios técnicos con integridad total.

-- 1. MARCAS
INSERT INTO tab_Marcas (id_marca, nom_marca, usr_insert, fec_insert) VALUES
(1, 'Rolex', 'system', NOW()), (2, 'Omega', 'system', NOW()), (3, 'CASSIO', 'system', NOW()),
(4, 'Tissot', 'system', NOW()), (5, 'Citizen', 'system', NOW()), (6, 'Seiko', 'system', NOW()),
(7, 'Bergeon', 'system', NOW()), (8, 'Tudor', 'system', NOW()), (9, 'Patek Philippe', 'system', NOW()),
(10, 'Tag Heuer', 'system', NOW()), (11, 'IWC Schaffhausen', 'system', NOW()), (12, 'Bulova', 'system', NOW())
ON CONFLICT (id_marca) DO NOTHING;

-- 2. CATEGORÍAS
INSERT INTO tab_Categorias (id_categoria, nom_categoria, descripcion_categoria, usr_insert, fec_insert) VALUES
(1, 'Relojes de Lujo', 'Cronometros de alta gama y prestigio internacional.', 'system', NOW()),
(2, 'Relojes Deportivos', 'Resistencia y funcionalidad para actividades extremas.', 'system', NOW()),
(3, 'Herramientas Profesionales', 'Instrumental técnico para maestros relojeros.', 'system', NOW()),
(4, 'Repuestos Originales', 'Componentes genuinos para mantenimiento.', 'system', NOW())
ON CONFLICT (id_categoria) DO NOTHING;

-- 3. SUBCATEGORÍAS
INSERT INTO tab_Subcategorias (id_categoria, id_subcategoria, nom_subcategoria, usr_insert, fec_insert) VALUES
(1, 1, 'Automáticos', 'system', NOW()), (1, 2, 'Cronógrafos', 'system', NOW()),
(2, 1, 'Resistentes al Agua', 'system', NOW()), (2, 2, 'Smartwatches', 'system', NOW()),
(3, 1, 'Instrumentos de Precisión', 'system', NOW()), (3, 2, 'Kits de Limpieza', 'system', NOW()),
(4, 1, 'Correas y Brazaletes', 'system', NOW()), (4, 2, 'Cristales y Biseles', 'system', NOW())
ON CONFLICT (id_categoria, id_subcategoria) DO NOTHING;

-- 4. SERVICIOS TÉCNICOS (Corregido según esquema: descripcion, duracion_estimada)
INSERT INTO tab_Servicios (id_servicio, nom_servicio, descripcion, precio_servicio, duracion_estimada, usr_insert, fec_insert) VALUES
(1, 'Cambio de Pila Premium', 'Instalación de batería suiza con empaque.', 45000, '30 min', 'system', NOW()),
(2, 'Mantenimiento General Automático', 'Limpieza y ajuste de marcha.', 320000, '3-5 días', 'system', NOW()),
(3, 'Pulido de Caja y Pulso', 'Restauración de brillo original.', 180000, '2 días', 'system', NOW()),
(4, 'Cambio de Cristal Zafiro', 'Sustitución por zafiro irrayable.', 250000, '24 horas', 'system', NOW()),
(5, 'Restauración de Esfera', 'Pintura técnica y LumiNova.', 450000, '15 días', 'system', NOW()),
(6, 'Prueba de Hermeticidad', 'Test de presión profesional.', 85000, '1 hora', 'system', NOW()),
(7, 'Ajuste de Brazalete', 'Remoción de eslabones.', 25000, '15 min', 'system', NOW()),
(8, 'Revisión y Diagnóstico', 'Evaluación técnica.', 0, '20 min', 'system', NOW()),
(9, 'Cambio de Corona y Tija', 'Repuesto original.', 120000, '1 día', 'system', NOW()),
(10, 'Mantenimiento Cronógrafo', 'Servicio especializado.', 650000, '8 días', 'system', NOW())
ON CONFLICT (id_servicio) DO NOTHING;

-- 5. PRODUCTOS (1-55)
INSERT INTO tab_Productos (id_producto, id_marca, nom_producto, descripcion, precio, id_categoria, id_subcategoria, stock, url_imagen, usr_insert, fec_insert) VALUES
(1, 1, 'Rolex Submariner Date', 'Bisel Cerachrom negro.', 68500000, 1, 1, 5, 'https://images.unsplash.com/photo-1587836374828-4dbafa94cf0e?w=800', 'system', NOW()),
(2, 1, 'Rolex Daytona Cosmograph', 'Oro de 18 quilates.', 145000000, 1, 2, 2, 'https://images.unsplash.com/photo-1614164185128-e4ec99c436d7?w=800', 'system', NOW()),
(3, 2, 'Omega Speedmaster Moonwatch', 'Calibre 3861 manual.', 34200000, 1, 2, 8, 'https://images.unsplash.com/photo-1612817159949-195b6eb9e31a?w=800', 'system', NOW()),
(4, 2, 'Omega Seamaster Diver 300M', 'Cerámica azul.', 28900000, 1, 1, 10, 'https://images.unsplash.com/photo-1523170335258-f5ed11844a49?w=800', 'system', NOW()),
(5, 4, 'Tissot Le Locle Powermatic', '80 horas reserva.', 3450000, 1, 1, 15, 'https://images.unsplash.com/photo-1619134177114-f5da772156be?w=800', 'system', NOW()),
(6, 3, 'CASSIO G-Shock Mudmaster', 'Resistencia extrema.', 1850000, 2, 1, 20, 'https://images.unsplash.com/photo-1547996160-81dfa63595aa?w=800', 'system', NOW()),
(7, 3, 'CASSIO Retro Gold', 'Icono de los 80.', 320000, 2, 1, 50, 'https://images.unsplash.com/photo-1622434641406-a158123450f9?w=800', 'system', NOW()),
(8, 6, 'Seiko 5 Sports Orange', 'Automático dinámico.', 1650000, 2, 1, 12, 'https://images.unsplash.com/photo-1612502169027-5a3d92c7fac7?w=800', 'system', NOW()),
(9, 6, 'Seiko Prospex Turtle', 'Buceo profesional.', 2450000, 2, 1, 9, 'https://images.unsplash.com/photo-1614242233320-7f28ed98801d?w=800', 'system', NOW()),
(10, 5, 'Citizen Eco-Drive Promaster', 'Carga solar.', 1980000, 2, 1, 14, 'https://images.unsplash.com/photo-1623932230865-ec1ba0884d59?w=800', 'system', NOW()),
(11, 7, 'Set Bergeon 30081', '10 piezas precisión.', 1150000, 3, 1, 5, 'https://images.unsplash.com/photo-1530124560676-4ce69299d261?w=800', 'system', NOW()),
(12, 7, 'Prensa Bergeon', 'Fondos a presión.', 2300000, 3, 1, 3, 'https://images.unsplash.com/photo-1581092921461-7d2a9390779d?w=800', 'system', NOW()),
(13, 7, 'Ultrasonido Limpieza', 'Para pulsos y cajas.', 450000, 3, 2, 10, 'https://images.unsplash.com/photo-1533038590840-1cde6e668a91?w=800', 'system', NOW()),
(14, 7, 'Extractor Pasadores', 'Sin rayones.', 180000, 3, 1, 25, 'https://images.unsplash.com/photo-1579446565308-427218a244fe?w=800', 'system', NOW()),
(15, 7, 'Lupa Relojero 10x', 'Detalle calibres.', 85000, 3, 1, 40, 'https://images.unsplash.com/photo-1618035222100-81f3ad437341?w=800', 'system', NOW()),
(16, 1, 'Brazalete Oyster Acero', 'Repuesto Rolex.', 12500000, 4, 1, 2, 'https://images.unsplash.com/photo-1549448530-50d4f1073177?w=800', 'system', NOW()),
(17, 2, 'Correa Caucho Azul', 'Repuesto Omega.', 1850000, 4, 1, 6, 'https://images.unsplash.com/photo-1612817159676-e1e550c609e2?w=800', 'system', NOW()),
(18, 1, 'Zafiro Rolex GMT', 'Lupa Cyclops.', 3450000, 4, 2, 4, 'https://images.unsplash.com/photo-1618035222044-67ad68b8e053?w=800', 'system', NOW()),
(19, 6, 'Maquinaria NH35A', 'Movimiento Seiko.', 320000, 4, 2, 30, 'https://images.unsplash.com/photo-1618035222100-2dca84310e52?w=800', 'system', NOW()),
(20, 3, 'Correa Resina Negra', 'Repuesto G-Shock.', 120000, 4, 1, 100, 'https://images.unsplash.com/photo-1542496658-e33a6d0d50f6?w=800', 'system', NOW()),
(21, 5, 'Citizen Skyhawk', 'Radio controlado.', 3250000, 2, 1, 7, 'https://images.unsplash.com/photo-1612502169027-4c407f240902?w=800', 'system', NOW()),
(22, 4, 'Tissot PRX Blue', 'Icono de los 70.', 3850000, 1, 1, 12, 'https://images.unsplash.com/photo-1619134177114-f5da772156be?w=800', 'system', NOW()),
(23, 2, 'Omega Constellation', 'Reloj vintage.', 8500000, 1, 1, 1, 'https://images.unsplash.com/photo-1612817159949-195b6eb9e31a?w=800', 'system', NOW()),
(24, 6, 'Seiko Presage Cocktail', 'Textura esfera.', 2150000, 1, 1, 8, 'https://images.unsplash.com/photo-1612502169027-5a3d92c7fac7?w=800', 'system', NOW()),
(25, 3, 'CASSIO Edifice', 'Bluetooth intel.', 850000, 2, 1, 20, 'https://images.unsplash.com/photo-1614242233320-7f28ed98801d?w=800', 'system', NOW()),
(26, 9, 'Patek Nautilus 5711', 'Esfera azul degrade.', 480000000, 1, 1, 1, 'https://images.unsplash.com/photo-1547996160-81dfa63595aa?w=800', 'system', NOW()),
(27, 8, 'Tudor Black Bay 58', 'Bisel azul años 50.', 18500000, 1, 1, 6, 'https://images.unsplash.com/photo-1614164185128-e4ec99c436d7?w=800', 'system', NOW()),
(28, 10, 'Tag Heuer Monaco', 'Edición Gulf.', 32400000, 1, 2, 4, 'https://images.unsplash.com/photo-1523170335258-f5ed11844a49?w=800', 'system', NOW()),
(29, 11, 'IWC Portugieser', 'Agujas acero azul.', 39800000, 1, 2, 3, 'https://images.unsplash.com/photo-1612817159949-195b6eb9e31a?w=800', 'system', NOW()),
(30, 2, 'Omega Aqua Terra', 'Dial Teak.', 24600000, 1, 1, 5, 'https://images.unsplash.com/photo-1619134177114-f5da772156be?w=800', 'system', NOW()),
(31, 3, 'CASSIO Pro Trek', 'Altímetro solar.', 1250000, 2, 1, 15, 'https://images.unsplash.com/photo-1614242233320-7f28ed98801d?w=800', 'system', NOW()),
(32, 12, 'Bulova Lunar Pilot', 'Misión Apollo 15.', 3200000, 2, 1, 10, 'https://images.unsplash.com/photo-1622434641406-a158123450f9?w=800', 'system', NOW()),
(33, 6, 'Seiko Alpinist', 'Brújula interna.', 3450000, 2, 1, 8, 'https://images.unsplash.com/photo-1547996160-81dfa63595aa?w=800', 'system', NOW()),
(34, 4, 'Tissot Gentleman', 'Titanio ligero.', 4200000, 1, 1, 12, 'https://images.unsplash.com/photo-1612502169027-5a3d92c7fac7?w=800', 'system', NOW()),
(35, 1, 'Rolex Explorer II', 'Cajas polares.', 54000000, 2, 1, 2, 'https://images.unsplash.com/photo-1587836374828-4dbafa94cf0e?w=800', 'system', NOW()),
(36, 7, 'Aceitador Precisión', 'Bergeon gota-gota.', 85000, 3, 1, 20, 'https://images.unsplash.com/photo-1581092921461-7d2a9390779d?w=800', 'system', NOW()),
(37, 7, 'Kit Pulido Lux', 'Metales preciosos.', 120000, 3, 2, 40, 'https://images.unsplash.com/photo-1533038590840-1cde6e668a91?w=800', 'system', NOW()),
(38, 7, 'Pinzas Antimagnét.', 'Bergeon precisión.', 65000, 3, 1, 60, 'https://images.unsplash.com/photo-1579446565308-427218a244fe?w=800', 'system', NOW()),
(39, 1, 'Bisel Rolex Green', 'Bisel Hulk.', 8500000, 4, 2, 3, 'https://images.unsplash.com/photo-1618035222044-67ad68b8e053?w=800', 'system', NOW()),
(40, 2, 'Cierre Omega Acero', 'Seguridad cuero.', 2300000, 4, 1, 10, 'https://images.unsplash.com/photo-1618035222100-2dca84310e52?w=800', 'system', NOW()),
(41, 1, 'Rolex Datejust 41', 'Mint Green dial.', 52000000, 1, 1, 4, 'https://images.unsplash.com/photo-1587836374828-4dbafa94cf0e?w=800', 'system', NOW()),
(42, 6, 'Seiko SKX007', 'Legendario buceo.', 1450000, 2, 1, 0, 'https://images.unsplash.com/photo-1614242233320-7f28ed98801d?w=800', 'system', NOW()),
(43, 3, 'CASSIO F-91W', 'Clásico absoluto.', 85000, 2, 1, 200, 'https://images.unsplash.com/photo-1542496658-e33a6d0d50f6?w=800', 'system', NOW()),
(44, 4, 'Tissot Visodate', 'Estilo retro.', 2800000, 1, 1, 9, 'https://images.unsplash.com/photo-1619134177114-f5da772156be?w=800', 'system', NOW()),
(45, 10, 'Tag Heuer Carrera', 'Calibre 5 auto.', 12500000, 1, 1, 7, 'https://images.unsplash.com/photo-1523170335258-f5ed11844a49?w=800', 'system', NOW()),
(46, 11, 'IWC Big Pilot', 'Aviation icon.', 58000000, 2, 1, 2, 'https://images.unsplash.com/photo-1612817159949-195b6eb9e31a?w=800', 'system', NOW()),
(47, 5, 'Citizen Tsuyosa', 'Tiffany dial.', 1650000, 1, 1, 15, 'https://images.unsplash.com/photo-1612502169027-5a3d92c7fac7?w=800', 'system', NOW()),
(48, 12, 'Bulova Precisionist', 'Cuarzo fluido.', 2450000, 2, 1, 11, 'https://images.unsplash.com/photo-1622434641406-a158123450f9?w=800', 'system', NOW()),
(49, 9, 'Patek Aquanaut', 'Lujo tropical.', 320000000, 2, 1, 1, 'https://images.unsplash.com/photo-1547996160-81dfa63595aa?w=800', 'system', NOW()),
(50, 8, 'Tudor Pelagos', 'Titanio grado 2.', 22500000, 2, 1, 5, 'https://images.unsplash.com/photo-1614164185128-e4ec99c436d7?w=800', 'system', NOW()),
(51, 1, 'Rolex Milgauss', 'Z-Blue dial.', 48900000, 1, 1, 3, 'https://images.unsplash.com/photo-1587836374828-4dbafa94cf0e?w=800', 'system', NOW()),
(52, 2, 'Omega Bond NTTD', 'Edición titania.', 42000000, 2, 1, 4, 'https://images.unsplash.com/photo-1523170335258-f5ed11844a49?w=800', 'system', NOW()),
(53, 3, 'CASSIO Silver', 'Icono acero.', 230000, 2, 1, 100, 'https://images.unsplash.com/photo-1614242233320-7f28ed98801d?w=800', 'system', NOW()),
(54, 4, 'Tissot Seastar', 'Bicel cerámico.', 3150000, 2, 1, 14, 'https://images.unsplash.com/photo-1612502169027-5a3d92c7fac7?w=800', 'system', NOW()),
(55, 6, 'Seiko DressKX', 'Versatilidad pura.', 1200000, 1, 1, 20, 'https://images.unsplash.com/photo-1614242233320-7f28ed98801d?w=800', 'system', NOW())
ON CONFLICT (id_producto) DO NOTHING;
