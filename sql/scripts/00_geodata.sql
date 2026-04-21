-- DEFINICIÓN DE FUNCIONES DE SOPORTE PARA GEODATA
CREATE OR REPLACE FUNCTION fun_insert_departamentos(p_id integer, p_nombre varchar, p_iso varchar)
RETURNS void AS $$
BEGIN
    INSERT INTO tab_Departamentos (id_departamento, nombre_departamento, codigo_iso, usr_insert, fec_insert)
    VALUES (p_id, p_nombre, p_iso, 'system', CURRENT_TIMESTAMP)
    ON CONFLICT (id_departamento) DO UPDATE 
    SET nombre_departamento = EXCLUDED.nombre_departamento,
        codigo_iso = EXCLUDED.codigo_iso,
        usr_update = 'system',
        fec_update = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fun_insert_ciudades(p_id integer, p_dept integer, p_nombre varchar, p_postal varchar)
RETURNS void AS $$
BEGIN
    INSERT INTO tab_Ciudades (id_ciudad, id_departamento, nombre_ciudad, codigo_postal, usr_insert, fec_insert)
    VALUES (p_id, p_dept, p_nombre, p_postal, 'system', CURRENT_TIMESTAMP)
    ON CONFLICT (id_ciudad) DO UPDATE 
    SET id_departamento = EXCLUDED.id_departamento,
        nombre_ciudad = EXCLUDED.nombre_ciudad,
        codigo_postal = EXCLUDED.codigo_postal,
        usr_update = 'system',
        fec_update = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- INSERTS DEPARTAMENTOS

-- Región Amazonía
SELECT fun_insert_departamentos(1, 'Amazonas', 'CO-AMA');
SELECT fun_insert_departamentos(8, 'Caquetá', 'CO-CAQ');
SELECT fun_insert_departamentos(15, 'Guainía', 'CO-GUA');
SELECT fun_insert_departamentos(16, 'Guaviare', 'CO-GUV');
SELECT fun_insert_departamentos(23, 'Putumayo', 'CO-PUT');
SELECT fun_insert_departamentos(31, 'Vaupés', 'CO-VAU');

-- Región Andina
SELECT fun_insert_departamentos(2, 'Antioquia', 'CO-ANT');
SELECT fun_insert_departamentos(6, 'Boyacá', 'CO-BOY');
SELECT fun_insert_departamentos(7, 'Caldas', 'CO-CAL');
SELECT fun_insert_departamentos(14, 'Cundinamarca', 'CO-CUN');
SELECT fun_insert_departamentos(17, 'Huila', 'CO-HUI');
SELECT fun_insert_departamentos(22, 'Norte de Santander', 'CO-NSA');
SELECT fun_insert_departamentos(24, 'Quindío', 'CO-QUI');
SELECT fun_insert_departamentos(25, 'Risaralda', 'CO-RIS');
SELECT fun_insert_departamentos(27, 'Santander', 'CO-SAN'); -- Tu región
SELECT fun_insert_departamentos(29, 'Tolima', 'CO-TOL');
SELECT fun_insert_departamentos(33, 'Bogotá D.C.', 'CO-DC');

-- Región Orinoquía
SELECT fun_insert_departamentos(3, 'Arauca', 'CO-ARA');
SELECT fun_insert_departamentos(9, 'Casanare', 'CO-CAS');
SELECT fun_insert_departamentos(20, 'Meta', 'CO-MET');
SELECT fun_insert_departamentos(32, 'Vichada', 'CO-VIC');

-- Región Caribe
SELECT fun_insert_departamentos(4, 'Atlántico', 'CO-ATL');
SELECT fun_insert_departamentos(5, 'Bolívar', 'CO-BOL');
SELECT fun_insert_departamentos(11, 'Cesar', 'CO-CES');
SELECT fun_insert_departamentos(13, 'Córdoba', 'CO-COR');
SELECT fun_insert_departamentos(18, 'La Guajira', 'CO-LAG');
SELECT fun_insert_departamentos(19, 'Magdalena', 'CO-MAG');
SELECT fun_insert_departamentos(26, 'San Andrés y Providencia', 'CO-SAP');
SELECT fun_insert_departamentos(28, 'Sucre', 'CO-SUC');

-- Región Pacífica
SELECT fun_insert_departamentos(10, 'Cauca', 'CO-CAU');
SELECT fun_insert_departamentos(12, 'Chocó', 'CO-CHO');
SELECT fun_insert_departamentos(21, 'Nariño', 'CO-NAR');
SELECT fun_insert_departamentos(30, 'Valle del Cauca', 'CO-VAC');

--INSERTS CIUDADES 
-- 1. Amazonas
SELECT fun_insert_ciudades(1, 1, 'Leticia', '910001');
SELECT fun_insert_ciudades(2, 1, 'Puerto Nariño', '910010');

-- 2. Antioquia (Selección principal)
SELECT fun_insert_ciudades(3, 2, 'Medellín', '050001');
SELECT fun_insert_ciudades(4, 2, 'Bello', '051050');
SELECT fun_insert_ciudades(5, 2, 'Envigado', '055420');
SELECT fun_insert_ciudades(6, 2, 'Itagüí', '055410');
SELECT fun_insert_ciudades(7, 2, 'Rionegro', '054040');
SELECT fun_insert_ciudades(8, 2, 'Apartadó', '057860');

-- 3. Arauca
SELECT fun_insert_ciudades(9, 3, 'Arauca', '810001');
SELECT fun_insert_ciudades(10, 3, 'Saravena', '815010');

-- 4. Atlántico
SELECT fun_insert_ciudades(11, 4, 'Barranquilla', '080001');
SELECT fun_insert_ciudades(12, 4, 'Soledad', '083001');
SELECT fun_insert_ciudades(13, 4, 'Malambo', '083010');

-- 5. Bolívar
SELECT fun_insert_ciudades(14, 5, 'Cartagena de Indias', '130001');
SELECT fun_insert_ciudades(15, 5, 'Magangué', '132010');
SELECT fun_insert_ciudades(16, 5, 'Turbaco', '131001');

-- 6. Boyacá
SELECT fun_insert_ciudades(17, 6, 'Tunja', '150001');
SELECT fun_insert_ciudades(18, 6, 'Duitama', '150460');
SELECT fun_insert_ciudades(19, 6, 'Sogamoso', '152210');
SELECT fun_insert_ciudades(20, 6, 'Villa de Leyva', '154001');

-- 7. Caldas
SELECT fun_insert_ciudades(21, 7, 'Manizales', '170001');
SELECT fun_insert_ciudades(22, 7, 'La Dorada', '175030');

-- 8. Caquetá
SELECT fun_insert_ciudades(23, 8, 'Florencia', '180001');

-- 9. Casanare
SELECT fun_insert_ciudades(24, 9, 'Yopal', '850001');

-- 10. Cauca
SELECT fun_insert_ciudades(25, 10, 'Popayán', '190001');
SELECT fun_insert_ciudades(26, 10, 'Santander de Quilichao', '191030');

-- 11. Cesar
SELECT fun_insert_ciudades(27, 11, 'Valledupar', '200001');
SELECT fun_insert_ciudades(28, 11, 'Aguachica', '205010');

-- 12. Chocó
SELECT fun_insert_ciudades(29, 12, 'Quibdó', '270001');

-- 13. Córdoba
SELECT fun_insert_ciudades(30, 13, 'Montería', '230001');
SELECT fun_insert_ciudades(31, 13, 'Lorica', '234010');

-- 14. Cundinamarca
SELECT fun_insert_ciudades(32, 14, 'Soacha', '250050');
SELECT fun_insert_ciudades(33, 14, 'Girardot', '252430');
SELECT fun_insert_ciudades(34, 14, 'Zipaquirá', '250250');
SELECT fun_insert_ciudades(35, 14, 'Chía', '250001');
SELECT fun_insert_ciudades(36, 14, 'Mosquera', '250040');

-- 15. Guainía
SELECT fun_insert_ciudades(37, 15, 'Inírida', '940001');

-- 16. Guaviare
SELECT fun_insert_ciudades(38, 16, 'San José del Guaviare', '950001');

-- 17. Huila
SELECT fun_insert_ciudades(39, 17, 'Neiva', '410001');
SELECT fun_insert_ciudades(40, 17, 'Pitalito', '417030');

-- 18. La Guajira
SELECT fun_insert_ciudades(41, 18, 'Riohacha', '440001');
SELECT fun_insert_ciudades(42, 18, 'Maicao', '444001');

-- 19. Magdalena
SELECT fun_insert_ciudades(43, 19, 'Santa Marta', '470001');
SELECT fun_insert_ciudades(44, 19, 'Ciénaga', '479010');

-- 20. Meta
SELECT fun_insert_ciudades(45, 20, 'Villavicencio', '500001');
SELECT fun_insert_ciudades(46, 20, 'Acacías', '507001');

-- 21. Nariño
SELECT fun_insert_ciudades(47, 21, 'Pasto', '520001');
SELECT fun_insert_ciudades(48, 21, 'Ipiales', '524060');
SELECT fun_insert_ciudades(49, 21, 'Tumaco', '528501');

-- 22. Norte de Santander
SELECT fun_insert_ciudades(50, 22, 'Cúcuta', '540001');
SELECT fun_insert_ciudades(51, 22, 'Ocaña', '546550');
SELECT fun_insert_ciudades(52, 22, 'Pamplona', '543050');
SELECT fun_insert_ciudades(53, 22, 'Villa del Rosario', '541070');

-- 23. Putumayo
SELECT fun_insert_ciudades(54, 23, 'Mocoa', '860001');
SELECT fun_insert_ciudades(55, 23, 'Puerto Asís', '862020');

-- 24. Quindío
SELECT fun_insert_ciudades(56, 24, 'Armenia', '630001');
SELECT fun_insert_ciudades(57, 24, 'Calarcá', '632001');

-- 25. Risaralda
SELECT fun_insert_ciudades(58, 25, 'Pereira', '660001');
SELECT fun_insert_ciudades(59, 25, 'Dosquebradas', '660002');

-- 26. San Andrés
SELECT fun_insert_ciudades(60, 26, 'San Andrés', '880001');

-- 27. Santander (Tu región)
SELECT fun_insert_ciudades(61, 27, 'Bucaramanga', '680001');
SELECT fun_insert_ciudades(62, 27, 'Floridablanca', '681001');
SELECT fun_insert_ciudades(63, 27, 'Girón', '687541');
SELECT fun_insert_ciudades(64, 27, 'Piedecuesta', '681011');
SELECT fun_insert_ciudades(65, 27, 'Barrancabermeja', '687031');
SELECT fun_insert_ciudades(66, 27, 'San Gil', '684031');

-- 28. Sucre
SELECT fun_insert_ciudades(67, 28, 'Sincelejo', '700001');

-- 29. Tolima
SELECT fun_insert_ciudades(68, 29, 'Ibagué', '730001');
SELECT fun_insert_ciudades(69, 29, 'Espinal', '733520');

-- 30. Valle del Cauca
SELECT fun_insert_ciudades(70, 30, 'Cali', '760001');
SELECT fun_insert_ciudades(71, 30, 'Buenaventura', '764501');
SELECT fun_insert_ciudades(72, 30, 'Palmira', '763531');
SELECT fun_insert_ciudades(73, 30, 'Tuluá', '763021');
SELECT fun_insert_ciudades(74, 30, 'Buga', '763041');

-- 31. Vaupés
SELECT fun_insert_ciudades(75, 31, 'Mitú', '970001');

-- 32. Vichada
SELECT fun_insert_ciudades(76, 32, 'Puerto Carreño', '990001');

-- 33. Bogotá D.C.
SELECT fun_insert_ciudades(77, 33, 'Bogotá', '110001');


-- ================================================================
-- GRAN EXPANSIÓN DE CIUDADES DE COLOMBIA (Resto de Municipios)
-- Secuencia inicia en ID: 78
-- Códigos postales en NULL para agilizar la carga masiva
-- ================================================================

-- 2. ANTIOQUIA (Adicionales importantes)
SELECT fun_insert_ciudades(78, 2, 'Caucasia', NULL);
SELECT fun_insert_ciudades(79, 2, 'Turbo', NULL);
SELECT fun_insert_ciudades(80, 2, 'Santa Fe de Antioquia', NULL);
SELECT fun_insert_ciudades(81, 2, 'Guatapé', NULL);
SELECT fun_insert_ciudades(82, 2, 'Jardín', NULL);
SELECT fun_insert_ciudades(83, 2, 'Jericó', NULL);
SELECT fun_insert_ciudades(84, 2, 'La Ceja', NULL);
SELECT fun_insert_ciudades(85, 2, 'Marinilla', NULL);
SELECT fun_insert_ciudades(86, 2, 'Chigorodó', NULL);
SELECT fun_insert_ciudades(87, 2, 'Necoclí', NULL);
SELECT fun_insert_ciudades(88, 2, 'Yarumal', NULL);
SELECT fun_insert_ciudades(89, 2, 'Caldas', NULL);
SELECT fun_insert_ciudades(90, 2, 'Copacabana', NULL);
SELECT fun_insert_ciudades(91, 2, 'Girardota', NULL);
SELECT fun_insert_ciudades(92, 2, 'La Estrella', NULL);
SELECT fun_insert_ciudades(93, 2, 'Sabaneta', NULL);
SELECT fun_insert_ciudades(94, 2, 'Andes', NULL);
SELECT fun_insert_ciudades(95, 2, 'Urrao', NULL);

-- 4. ATLÁNTICO (Área Metropolitana y otros)
SELECT fun_insert_ciudades(96, 4, 'Puerto Colombia', NULL);
SELECT fun_insert_ciudades(97, 4, 'Galapa', NULL);
SELECT fun_insert_ciudades(98, 4, 'Sabanalarga', NULL);
SELECT fun_insert_ciudades(99, 4, 'Baranoa', NULL);
SELECT fun_insert_ciudades(100, 4, 'Santo Tomás', NULL);

-- 5. BOLÍVAR
SELECT fun_insert_ciudades(101, 5, 'El Carmen de Bolívar', NULL);
SELECT fun_insert_ciudades(102, 5, 'Mompox', NULL);
SELECT fun_insert_ciudades(103, 5, 'Arjona', NULL);
SELECT fun_insert_ciudades(104, 5, 'San Juan Nepomuceno', NULL);

-- 6. BOYACÁ
SELECT fun_insert_ciudades(105, 6, 'Chiquinquirá', NULL);
SELECT fun_insert_ciudades(106, 6, 'Paipa', NULL);
SELECT fun_insert_ciudades(107, 6, 'Puerto Boyacá', NULL);
SELECT fun_insert_ciudades(108, 6, 'Moniquirá', NULL);
SELECT fun_insert_ciudades(109, 6, 'Nobsa', NULL);
SELECT fun_insert_ciudades(110, 6, 'Tibasosa', NULL);
SELECT fun_insert_ciudades(111, 6, 'Ráquira', NULL);

-- 7. CALDAS
SELECT fun_insert_ciudades(112, 7, 'Chinchiná', NULL);
SELECT fun_insert_ciudades(113, 7, 'Villamaría', NULL);
SELECT fun_insert_ciudades(114, 7, 'Aguadas', NULL);
SELECT fun_insert_ciudades(115, 7, 'Riosucio', NULL);
SELECT fun_insert_ciudades(116, 7, 'Salamina', NULL);
SELECT fun_insert_ciudades(117, 7, 'Anserma', NULL);

-- 8. CAQUETÁ
SELECT fun_insert_ciudades(118, 8, 'San Vicente del Caguán', NULL);

-- 9. CASANARE
SELECT fun_insert_ciudades(119, 9, 'Aguazul', NULL);
SELECT fun_insert_ciudades(120, 9, 'Villanueva', NULL);
SELECT fun_insert_ciudades(121, 9, 'Tauramena', NULL);
SELECT fun_insert_ciudades(122, 9, 'Paz de Ariporo', NULL);

-- 10. CAUCA
SELECT fun_insert_ciudades(123, 10, 'Puerto Tejada', NULL);
SELECT fun_insert_ciudades(124, 10, 'Piendamó', NULL);
SELECT fun_insert_ciudades(125, 10, 'El Bordo', NULL);

-- 11. CESAR
SELECT fun_insert_ciudades(126, 11, 'Bosconia', NULL);
SELECT fun_insert_ciudades(127, 11, 'Curumaní', NULL);
SELECT fun_insert_ciudades(128, 11, 'Codazzi', NULL);
SELECT fun_insert_ciudades(129, 11, 'La Paz', NULL);

-- 12. CHOCÓ
SELECT fun_insert_ciudades(130, 12, 'Istmina', NULL);
SELECT fun_insert_ciudades(131, 12, 'Tadó', NULL);
SELECT fun_insert_ciudades(132, 12, 'Nuquí', NULL); -- Turismo
SELECT fun_insert_ciudades(133, 12, 'Bahía Solano', NULL); -- Turismo

-- 13. CÓRDOBA
SELECT fun_insert_ciudades(134, 13, 'Cereté', NULL);
SELECT fun_insert_ciudades(135, 13, 'Sahagún', NULL);
SELECT fun_insert_ciudades(136, 13, 'Montelíbano', NULL);
SELECT fun_insert_ciudades(137, 13, 'Planeta Rica', NULL);
SELECT fun_insert_ciudades(138, 13, 'Ciénaga de Oro', NULL);

-- 14. CUNDINAMARCA (Sabana y aledaños - Muy importante para envíos)
SELECT fun_insert_ciudades(139, 14, 'Facatativá', NULL);
SELECT fun_insert_ciudades(140, 14, 'Fusagasugá', NULL);
SELECT fun_insert_ciudades(141, 14, 'Madrid', NULL);
SELECT fun_insert_ciudades(142, 14, 'Funza', NULL);
SELECT fun_insert_ciudades(143, 14, 'Cajicá', NULL);
SELECT fun_insert_ciudades(144, 14, 'Tocancipá', NULL); -- Zona industrial
SELECT fun_insert_ciudades(145, 14, 'Cota', NULL);
SELECT fun_insert_ciudades(146, 14, 'Sopó', NULL);
SELECT fun_insert_ciudades(147, 14, 'Tabio', NULL);
SELECT fun_insert_ciudades(148, 14, 'Tenjo', NULL);
SELECT fun_insert_ciudades(149, 14, 'La Calera', NULL);
SELECT fun_insert_ciudades(150, 14, 'Villeta', NULL);
SELECT fun_insert_ciudades(151, 14, 'Ubaté', NULL);
SELECT fun_insert_ciudades(152, 14, 'Tocaima', NULL);
SELECT fun_insert_ciudades(153, 14, 'Ricaurte', NULL);
SELECT fun_insert_ciudades(154, 14, 'Guaduas', NULL);
SELECT fun_insert_ciudades(155, 14, 'Pacho', NULL);

-- 17. HUILA
SELECT fun_insert_ciudades(156, 17, 'Garzón', NULL);
SELECT fun_insert_ciudades(157, 17, 'La Plata', NULL);
SELECT fun_insert_ciudades(158, 17, 'Campoalegre', NULL);
SELECT fun_insert_ciudades(159, 17, 'San Agustín', NULL); -- Turismo

-- 18. LA GUAJIRA
SELECT fun_insert_ciudades(160, 18, 'Uribia', NULL);
SELECT fun_insert_ciudades(161, 18, 'Fonseca', NULL);
SELECT fun_insert_ciudades(162, 18, 'San Juan del Cesar', NULL);

-- 19. MAGDALENA
SELECT fun_insert_ciudades(163, 19, 'Fundación', NULL);
SELECT fun_insert_ciudades(164, 19, 'El Banco', NULL);
SELECT fun_insert_ciudades(165, 19, 'Plato', NULL);
SELECT fun_insert_ciudades(166, 19, 'Aracataca', NULL);

-- 20. META
SELECT fun_insert_ciudades(167, 20, 'Granada', NULL);
SELECT fun_insert_ciudades(168, 20, 'Puerto López', NULL);
SELECT fun_insert_ciudades(169, 20, 'Cumaral', NULL);
SELECT fun_insert_ciudades(170, 20, 'Restrepo', NULL);

-- 21. NARIÑO
SELECT fun_insert_ciudades(171, 21, 'La Unión', NULL);
SELECT fun_insert_ciudades(172, 21, 'Túquerres', NULL);
SELECT fun_insert_ciudades(173, 21, 'Samaniego', NULL);

-- 22. NORTE DE SANTANDER
SELECT fun_insert_ciudades(174, 22, 'Los Patios', NULL);
SELECT fun_insert_ciudades(175, 22, 'Tibú', NULL);
SELECT fun_insert_ciudades(176, 22, 'Chinácota', NULL);
SELECT fun_insert_ciudades(177, 22, 'El Zulia', NULL);

-- 23. PUTUMAYO
SELECT fun_insert_ciudades(178, 23, 'Orito', NULL);
SELECT fun_insert_ciudades(179, 23, 'Sibundoy', NULL);

-- 24. QUINDÍO
SELECT fun_insert_ciudades(180, 24, 'Montenegro', NULL); -- Parque del Café
SELECT fun_insert_ciudades(181, 24, 'Quimbaya', NULL);
SELECT fun_insert_ciudades(182, 24, 'La Tebaida', NULL);
SELECT fun_insert_ciudades(183, 24, 'Circasia', NULL);
SELECT fun_insert_ciudades(184, 24, 'Salento', NULL); -- Turismo
SELECT fun_insert_ciudades(185, 24, 'Filandia', NULL); -- Turismo

-- 25. RISARALDA
SELECT fun_insert_ciudades(186, 25, 'Santa Rosa de Cabal', NULL);
SELECT fun_insert_ciudades(187, 25, 'La Virginia', NULL);
SELECT fun_insert_ciudades(188, 25, 'Belén de Umbría', NULL);
SELECT fun_insert_ciudades(189, 25, 'Marsella', NULL);

-- 27. SANTANDER (Gran Santander)
SELECT fun_insert_ciudades(190, 27, 'Socorro', NULL);
SELECT fun_insert_ciudades(191, 27, 'Barbosa', NULL);
SELECT fun_insert_ciudades(192, 27, 'Vélez', NULL);
SELECT fun_insert_ciudades(193, 27, 'Zapatoca', NULL);
SELECT fun_insert_ciudades(194, 27, 'Barichara', NULL); -- Turismo
SELECT fun_insert_ciudades(195, 27, 'Lebrija', NULL); -- Aeropuerto
SELECT fun_insert_ciudades(196, 27, 'Rionegro', NULL);
SELECT fun_insert_ciudades(197, 27, 'Sabana de Torres', NULL);
SELECT fun_insert_ciudades(198, 27, 'Cimitarra', NULL);
SELECT fun_insert_ciudades(199, 27, 'Málaga', NULL);
SELECT fun_insert_ciudades(200, 27, 'Puerto Wilches', NULL);
SELECT fun_insert_ciudades(201, 27, 'Oiba', NULL);
SELECT fun_insert_ciudades(202, 27, 'Charalá', NULL);

-- 28. SUCRE
SELECT fun_insert_ciudades(203, 28, 'Corozal', NULL);
SELECT fun_insert_ciudades(204, 28, 'San Marcos', NULL);
SELECT fun_insert_ciudades(205, 28, 'Tolú', NULL); -- Turismo
SELECT fun_insert_ciudades(206, 28, 'Coveñas', NULL); -- Turismo
SELECT fun_insert_ciudades(207, 28, 'Sampués', NULL);

-- 29. TOLIMA
SELECT fun_insert_ciudades(208, 29, 'Melgar', NULL); -- Turismo
SELECT fun_insert_ciudades(209, 29, 'Honda', NULL);
SELECT fun_insert_ciudades(210, 29, 'Mariquita', NULL);
SELECT fun_insert_ciudades(211, 29, 'Chaparral', NULL);
SELECT fun_insert_ciudades(212, 29, 'Líbano', NULL);
SELECT fun_insert_ciudades(213, 29, 'Flandes', NULL);
SELECT fun_insert_ciudades(214, 29, 'Guamo', NULL);

-- 30. VALLE DEL CAUCA (Muy denso comercialmente)
SELECT fun_insert_ciudades(215, 30, 'Jamundí', NULL);
SELECT fun_insert_ciudades(216, 30, 'Yumbo', NULL);
SELECT fun_insert_ciudades(217, 30, 'Cartago', NULL);
SELECT fun_insert_ciudades(218, 30, 'Candelaria', NULL);
SELECT fun_insert_ciudades(219, 30, 'Florida', NULL);
SELECT fun_insert_ciudades(220, 30, 'Pradera', NULL);
SELECT fun_insert_ciudades(221, 30, 'El Cerrito', NULL);
SELECT fun_insert_ciudades(222, 30, 'Zarzal', NULL);
SELECT fun_insert_ciudades(223, 30, 'Roldanillo', NULL);
SELECT fun_insert_ciudades(224, 30, 'Sevilla', NULL);
SELECT fun_insert_ciudades(225, 30, 'Caicedonia', NULL);
SELECT fun_insert_ciudades(226, 30, 'Dagua', NULL);

-- 3. ARAUCA (Extra)
SELECT fun_insert_ciudades(227, 3, 'Tame', NULL);

-- 1. AMAZONAS (Extra)
SELECT fun_insert_ciudades(228, 1, 'Tarapacá', NULL);