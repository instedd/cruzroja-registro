# Script for populating the database with custom functions. You can run it as:
#
#     mix run priv/repo/functions_init.exs

PgSql.load_functions!
