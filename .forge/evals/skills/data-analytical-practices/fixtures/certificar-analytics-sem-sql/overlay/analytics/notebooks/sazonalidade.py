# Databricks notebook source
df = spark.sql("select data_recarga, sum(valor_centavos) from gold.fct_recargas group by 1")
display(df)
