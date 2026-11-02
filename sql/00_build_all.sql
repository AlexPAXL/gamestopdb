-- =====================================================================
-- GameStop DB  |  00_build_all.sql
-- Reconstruye TODO desde cero y ejecuta las pruebas.
-- ¡Borra gamestopdb! (ver advertencia en 01_database.sql)
--
-- Uso (desde esta carpeta):
--   mysql -u root -p --default-character-set=utf8mb4 < 00_build_all.sql
-- =====================================================================

SOURCE 01_database.sql
SOURCE 02_tables.sql
SOURCE 10_app_usuarios.sql
SOURCE 03_views.sql
SOURCE 04_routines.sql
SOURCE 05_triggers.sql
SOURCE 06_security.sql
SOURCE 11_app_service_accounts.sql
SOURCE 07_seed.sql
SOURCE 08_validation.sql
