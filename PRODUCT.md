# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

Delegated from the user's request: a dependency-light HTML/CSS/JavaScript interface with a Python service, packaged in the existing Spark + Ozone Docker image and launched by Docker Compose.

## Users

Inferred from the request: a Russian-speaking technical learner who is exploring Apache Ozone through familiar Spark concepts and wants to work without memorizing shell commands.

## Product Purpose

Ozone Explorer makes the Ozone hierarchy visible, lets the user create volumes and buckets, and opens Parquet, CSV, or JSON paths through a real Spark DataFrame. Success means the user can move from a bucket to rows and schema in one interface.

## Positioning

The interface joins Ozone namespace operations and Spark DataFrame inspection in one local workflow. A generic S3 browser can list objects, but it cannot show how Spark interprets their schema and rows.

## Operating Context

The product runs in the repository's local Docker Compose lab on Windows with Ubuntu WSL. It works with Apache Ozone 2.2.1, Spark 3.5.4, Iceberg 1.6.1, and the existing `ofs://om/<volume>/<bucket>/<path>` addressing model. The interface language is Russian.

## Capabilities and Constraints

- Create and list Ozone volumes and buckets.
- Browse directories and keys in a selected bucket.
- Preview Parquet, CSV, and JSON paths with Spark DataFrame, including inferred schema and a bounded row sample.
- Run locally without a separate package manager at container startup.
- Reuse the repository's Spark + Ozone image and remain part of the same repository and Compose stack.
- This is a learning environment without authentication, multi-user isolation, or production hardening.
- Inferred scope: editing individual DataFrame cells and arbitrary SQL execution are not part of the first version.

## Evidence on Hand

- Working Ozone lab under `hadoop_iceberg_spark_ozone/`.
- Verified example data at `ofs://om/spark/data/users-parquet`.
- Verified Iceberg catalog at `ofs://om/spark/warehouse`.
- No external brand assets or commercial claims are supplied.

## Product Principles

- Show the Ozone hierarchy before exposing its terminology.
- Keep storage navigation and DataFrame inspection visibly connected.
- Prefer safe bounded previews over unrestricted operations.
- Explain failures in Russian and name the recovery action.
- Preserve a direct escape hatch to the equivalent `ozone sh` or Spark command.

## Accessibility & Inclusion

The interface must work with keyboard navigation, visible focus, sufficient contrast, reduced motion, and responsive layouts for desktop and narrow screens.
