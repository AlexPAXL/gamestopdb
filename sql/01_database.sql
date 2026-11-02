-- =====================================================================
-- GameStop DB  |  01_database.sql
-- Objetivo : MySQL 8.0.16+ (CHECK constraints, JSON_TABLE, roles).
--            Probado contra la versión del servidor: 8.0.44.
--
-- ADVERTENCIA: este script BORRA y RECREA la base gamestopdb.
-- Al momento de la auditoría (2026-09-28) todas las tablas tenían 0 filas.
-- Si ya hay datos reales, haga un respaldo antes:
--   mysqldump -u root -p gamestopdb > respaldo_gamestopdb.sql
-- =====================================================================

DROP DATABASE IF EXISTS gamestopdb;

CREATE DATABASE gamestopdb
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;   -- insensible a mayúsculas y acentos: "Pokemon" = "Pokémon"

USE gamestopdb;
