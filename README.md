# scripts/

MiSeq 解析の汎用スクリプト群。すべて devbox 環境内 (`devbox run -- bash ...` か `devbox shell`) で実行する想定。

## bcl2fastq.sh — BCL → FASTQ 変換

MiSeq の run ディレクトリ (BCL) から FASTQ を吐く。`RunInfo.xml` を読んで READ_STRUCTURE / Flowcell / Machine / RunNumber / LaneCount を自動抽出。

```
bash scripts/bcl2fastq.sh <run_dir> [out_dir]
```

例:
```
bash scripts/bcl2fastq.sh 260604_M04122_0046_000000000-MCGWY fastq_output
```

- 出力: `<out_dir>/<run_name>.L<lane>.<read>.fastq`
- 単一サンプル(barcode 無し)前提。多重化 run の場合は Picard の `MULTIPLEX_PARAMS` 切り替えが必要

## split_by_barcode.sh — 5'バーコード分割

CSV 記載のバーコードごとに `seqkit grep -sirp "^<seq>"` を実行して、対応するリードだけを抽出。

```
bash scripts/split_by_barcode.sh <barcodes.csv> <input.fastq> [out_dir] [jobs]
```

CSV フォーマット(ヘッダ必須):
```csv
id,sequence
bc1,tatagtagct
bc2,tacattatcct
...
```

例:
```
bash scripts/split_by_barcode.sh scripts/barcodes.csv fastq_output/yukihada.L1.1.fastq fastq_output/bc
```

- 出力: `<out_dir>/<id>.fastq`(ID は CSV の `id` カラム)
- `jobs` デフォルト 4(並列度。共有ストレージで多すぎると I/O が詰まって出力破損する可能性あり)

## rc_barcodes.sh — Reverse complement

ディレクトリ内の `*.fastq` をすべて reverse complement する。`*RC.fastq` は再実行時にスキップ(RCRC化されない)。

```
bash scripts/rc_barcodes.sh <in_dir> [out_dir] [jobs]
```

例:
```
bash scripts/rc_barcodes.sh fastq_output/bc fastq_output/bc_rc
```

- 出力: `<out_dir>/<name>RC.fastq`
- `seqkit seq -t DNA -pr` を使用
- `out_dir` 省略時は `in_dir` と同じ場所に出力

## count_fastq.sh — FASTQ → FASTA (FASTAptamer-Count)

ディレクトリ内の `*.fastq` を FASTAptamer-Count で集約。ユニーク配列ごとに `>RANK-READS-RPM` ヘッダの FASTA を生成。

```
bash scripts/count_fastq.sh <in_dir> [out_dir] [jobs]
```

例:
```
bash scripts/count_fastq.sh fastq_output/bc_trim fastq_output/bc_count
```

- 出力: `<out_dir>/<name>.fasta`
- ランク順、reads-per-million 付き(FASTAptamer-Count 仕様)
- 最後に `seqkit stats` で各ファイルのサマリを表示

## 典型的なパイプライン

```
# 1) BCL → FASTQ
bash scripts/bcl2fastq.sh 260604_M04122_0046_000000000-MCGWY fastq_output

# 2) バーコード分割
bash scripts/split_by_barcode.sh scripts/barcodes.csv \
  fastq_output/260604_M04122_0046_000000000-MCGWY.L1.1.fastq \
  fastq_output/bc

# 3) Reverse complement
bash scripts/rc_barcodes.sh fastq_output/bc fastq_output/bc_rc

# 4) トリム — ライブラリ構造に依存するためここでは省略

# 5) FASTAptamer-Count で集計
bash scripts/count_fastq.sh fastq_output/bc_rc fastq_output/bc_count
```
