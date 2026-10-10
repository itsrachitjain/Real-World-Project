# Real-World Data Cleaning & Data Quality Analysis Using PostgreSQL

## Project Overview

This project demonstrates an end-to-end SQL workflow for cleaning, standardizing, and validating a structured dataset using PostgreSQL.

The workflow was developed around real-world data-quality challenges. Due to client confidentiality, the original dataset and identifiable records are not included in this repository.

## Key Operations

- **Data Profiling:** Total record counts and column-wise missing or blank value analysis.
- **Text Standardization:** Removal of extra spaces, normalization of text, and handling of placeholder values.
- **Data Validation:** Mobile number format checks using regular expressions.
- **Duplicate Analysis:** Detection of exact duplicate rows and repeated mobile numbers.
- **Deduplication:** Use of CTEs and `ROW_NUMBER()` to identify preferred records and resolve duplicates.
- **Missing-Value Handling:** Investigation of repeated records to recover missing attributes where appropriate.
- **Category Standardization:** Mapping inconsistent stream values and calling remarks into standardized categories.
- **Data Quality Verification:** Post-cleaning checks for missing values, duplicates, and inconsistent categories.

## Tools & Concepts

PostgreSQL | pgAdmin | CTEs | CASE Statements | Regular Expressions | Window Functions | Aggregate Functions | Transactions

## Confidentiality

This repository contains SQL code and documentation only. The original client dataset, personal information, and identifiable records are excluded to protect confidentiality.

The scripts should be adapted to the target dataset and validated against the relevant business rules before production use.

## Key Learning

This project strengthened my practical understanding of SQL-based data profiling, data standardization, duplicate investigation, validation, and quality assurance in a real-world workflow.
