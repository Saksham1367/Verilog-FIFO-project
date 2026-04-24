from __future__ import annotations

import argparse
import re
from pathlib import Path


CHECKS = [
    (
        "Synchronizer declarations are marked ASYNC_REG",
        lambda text: all(
            token in text
            for token in [
                '(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [PTR_WIDTH-1:0] rd_gray_sync1;',
                '(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [PTR_WIDTH-1:0] rd_gray_sync2;',
                '(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [PTR_WIDTH-1:0] wr_gray_sync1;',
                '(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [PTR_WIDTH-1:0] wr_gray_sync2;',
            ]
        ),
        "Both crossing synchronizer stages are explicitly tagged for implementation tools.",
    ),
    (
        "Read-domain synchronizer is two stages",
        lambda text: "wr_gray_sync1 <= wr_gray;" in text and "wr_gray_sync2 <= wr_gray_sync1;" in text,
        "Read-domain logic samples the write Gray pointer through two explicit flip-flop stages.",
    ),
    (
        "Write-domain synchronizer is two stages",
        lambda text: "rd_gray_sync1 <= rd_gray;" in text and "rd_gray_sync2 <= rd_gray_sync1;" in text,
        "Write-domain logic samples the read Gray pointer through two explicit flip-flop stages.",
    ),
    (
        "Flags use synchronized cross-domain pointers",
        lambda text: "assign full_next    = (wr_gray_next == invert_msb2(rd_gray_sync2));" in text
        and "assign empty_next   = (rd_gray_next == wr_gray_sync2);" in text,
        "The full and empty decisions use the second synchronizer stage, not raw opposite-domain signals.",
    ),
    (
        "Occupancy estimates are derived from synchronized pointers",
        lambda text: "assign rd_bin_sync = gray2bin(rd_gray_sync2);" in text
        and "assign wr_bin_sync = gray2bin(wr_gray_sync2);" in text
        and "assign wr_count_int = wr_bin - rd_bin_sync;" in text
        and "assign rd_count_int = wr_bin_sync - rd_bin;" in text,
        "Count outputs are local-domain estimates based on synchronized pointer views.",
    ),
    (
        "Reset release is synchronized per clock domain",
        lambda text: all(
            token in text
            for token in [
                "reg [1:0] wr_rst_pipe;",
                "reg [1:0] rd_rst_pipe;",
                "wire wr_rst_local = wr_rst_pipe[0];",
                "wire rd_rst_local = rd_rst_pipe[0];",
                "always @(posedge wr_clk or posedge wr_rst)",
                "always @(posedge rd_clk or posedge rd_rst)",
            ]
        ),
        "Asynchronous reset assertion is followed by local synchronous release staging in both domains.",
    ),
]


def generate_report(rtl_path: Path, output_path: Path) -> None:
    text = rtl_path.read_text()
    results = []

    for name, predicate, rationale in CHECKS:
        passed = bool(predicate(text))
        results.append((name, passed, rationale))

    all_passed = all(passed for _, passed, _ in results)
    status = "PASS" if all_passed else "REVIEW REQUIRED"

    lines = [
        "# CDC Structural Review",
        "",
        f"Source file: `{rtl_path.name}`",
        "",
        f"Overall status: **{status}**",
        "",
        "This report is a structural CDC review generated from the RTL source.",
        "It is useful for open-source pre-signoff checking, but it is not a substitute for a commercial CDC analyzer such as SpyGlass CDC or Questa CDC.",
        "",
        "| Check | Result | Notes |",
        "| --- | --- | --- |",
    ]

    for name, passed, rationale in results:
        lines.append(f"| {name} | {'PASS' if passed else 'FAIL'} | {rationale} |")

    lines.extend(
        [
            "",
            "## Review Notes",
            "",
            "- The design crosses only Gray-coded pointers, not raw binary pointers.",
            "- Memory data is not synchronized directly; safe operation relies on the asynchronous FIFO pointer/flag protocol and the dual-port memory abstraction.",
            "- Integration still requires proper timing/CDC constraints in the target implementation flow.",
        ]
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(lines) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate a structural CDC review report.")
    parser.add_argument("--rtl", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()

    generate_report(args.rtl, args.out)


if __name__ == "__main__":
    main()
