-- data.sql para microservicio Despachos
INSERT INTO despacho (id_despacho, fecha_despacho, patente_camion, intento, id_compra, direccion_compra, valor_compra, despachado) 
VALUES (1, '2026-07-04', 'ABCD12', 1, 1, 'Av. Libertador Bernardo OHiggins 1234', 250000, false);

INSERT INTO despacho (id_despacho, fecha_despacho, patente_camion, intento, id_compra, direccion_compra, valor_compra, despachado) 
VALUES (2, '2026-07-05', 'HGKL34', 0, 2, 'Avenida Los Cedros 742', 85000, false);
