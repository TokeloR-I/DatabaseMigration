# DatabaseMigration
DatabaseMigration tool if you have 2 databases with the same name schema etc , and you dont want the data to mix together 

small Application will ask for DB instance name
ask for db instance login(Sysadmin recommended)
database with same name will be detached 
will attach new db 
if you have an orphan script I recommend you to rename it to Orphan_fix.sql

known bugs
error generated if the db files do not have the right permissions for DB admin (recommend manually adding full rights for DB owner on Microsoft)
