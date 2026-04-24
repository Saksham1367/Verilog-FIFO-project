from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

import matplotlib.pyplot as plt


WINDOWS_NS = [
    (0.0, 100.0, "plot_0_to_100_ns.png", "FIFO waveform: 0 ns to 100 ns"),
    (100.0, 220.0, "plot_100_to_220_ns.png", "FIFO waveform: 100 ns to 220 ns"),
    (0.0, 300.0, "plot_0_to_300_ns.png", "FIFO waveform: 0 ns to 300 ns"),
]

SIGNALS = [
    ("tb_fifo.wr_clk", "digital"),
    ("tb_fifo.rd_clk", "digital"),
    ("tb_fifo.wr_en", "digital"),
    ("tb_fifo.rd_en", "digital"),
    ("tb_fifo.wr_ack", "digital"),
    ("tb_fifo.rd_valid", "digital"),
    ("tb_fifo.full", "digital"),
    ("tb_fifo.empty", "digital"),
    ("tb_fifo.overflow", "digital"),
    ("tb_fifo.underflow", "digital"),
    ("tb_fifo.wr_ptr [3:0]", "bus"),
    ("tb_fifo.rd_ptr [3:0]", "bus"),
    ("tb_fifo.wr_count [4:0]", "bus"),
    ("tb_fifo.rd_count [4:0]", "bus"),
    ("tb_fifo.wr_data [15:0]", "bus"),
    ("tb_fifo.rd_data [15:0]", "bus"),
]


@dataclass
class Signal:
    code: str
    width: int
    values: list[tuple[float, str]]


def parse_vcd(vcd_path: Path, selected_names: set[str]) -> dict[str, Signal]:
    scope_stack: list[str] = []
    code_to_name: dict[str, str] = {}
    signal_map: dict[str, Signal] = {}
    current_time_ps = 0.0
    in_header = True

    for raw_line in vcd_path.read_text(errors="ignore").splitlines():
        line = raw_line.strip()
        if not line:
            continue

        if in_header:
            if line.startswith("$scope"):
                parts = line.split()
                scope_stack.append(parts[2])
            elif line.startswith("$upscope"):
                if scope_stack:
                    scope_stack.pop()
            elif line.startswith("$var"):
                parts = line.split()
                width = int(parts[2])
                code = parts[3]
                name = " ".join(parts[4:-1])
                full_name = ".".join(scope_stack + [name])
                code_to_name[code] = full_name
                if full_name in selected_names:
                    signal_map[full_name] = Signal(code=code, width=width, values=[])
            elif line.startswith("$enddefinitions"):
                in_header = False
            continue

        if line.startswith("#"):
            current_time_ps = float(line[1:])
            continue

        if line[0] in "01xXzZ":
            code = line[1:]
            name = code_to_name.get(code)
            if name in signal_map:
                signal_map[name].values.append((current_time_ps, line[0].lower()))
            continue

        if line[0] in "bBrR":
            value, code = line[1:].split()
            name = code_to_name.get(code)
            if name in signal_map:
                signal_map[name].values.append((current_time_ps, value.lower()))

    return signal_map


def value_to_numeric(value: str) -> int | None:
    if not value:
        return None

    if any(ch in value for ch in "xz"):
        return None

    if value in {"0", "1"}:
        return int(value)

    return int(value, 2)


def value_to_label(value: str) -> str:
    numeric = value_to_numeric(value)
    if numeric is None:
        return value.upper()
    return f"0x{numeric:X}"


def crop_events(values: list[tuple[float, str]], start_ps: float, end_ps: float) -> tuple[list[float], list[int | None], list[tuple[float, str]]]:
    cropped_times: list[float] = []
    cropped_values: list[int | None] = []
    labels: list[tuple[float, str]] = []
    last_value = None

    for time_ps, value in values:
        if time_ps <= start_ps:
            last_value = value
            continue
        break

    if last_value is not None:
        cropped_times.append(start_ps / 1000.0)
        cropped_values.append(value_to_numeric(last_value))
        labels.append((start_ps / 1000.0, value_to_label(last_value)))

    for time_ps, value in values:
        if time_ps < start_ps:
            continue
        if time_ps > end_ps:
            break
        cropped_times.append(time_ps / 1000.0)
        cropped_values.append(value_to_numeric(value))
        labels.append((time_ps / 1000.0, value_to_label(value)))
        last_value = value

    if not cropped_times:
        cropped_times.append(start_ps / 1000.0)
        cropped_values.append(None)
        labels.append((start_ps / 1000.0, "U"))
    elif cropped_times[-1] < end_ps / 1000.0:
        cropped_times.append(end_ps / 1000.0)
        cropped_values.append(cropped_values[-1])

    return cropped_times, cropped_values, labels


def plot_window(signal_map: dict[str, Signal], start_ns: float, end_ns: float, output_path: Path, title: str) -> None:
    start_ps = start_ns * 1000.0
    end_ps = end_ns * 1000.0
    fig, axes = plt.subplots(len(SIGNALS), 1, figsize=(16, 18), sharex=True)
    fig.patch.set_facecolor("#f5f7fb")

    for axis, (signal_name, kind) in zip(axes, SIGNALS):
        signal = signal_map[signal_name]
        times_ns, numeric_values, labels = crop_events(signal.values, start_ps, end_ps)

        safe_values = [0 if value is None else value for value in numeric_values]
        color = "#1f77b4" if kind == "digital" else "#c25b12"
        axis.step(times_ns, safe_values, where="post", color=color, linewidth=1.8)
        axis.set_facecolor("#ffffff")
        axis.grid(True, axis="x", linestyle="--", alpha=0.35)
        axis.set_ylabel(signal_name.split(".")[-1], rotation=0, ha="right", va="center", labelpad=70, fontsize=8)

        if kind == "digital":
            axis.set_ylim(-0.3, 1.3)
            axis.set_yticks([0, 1])
        else:
            max_value = max(safe_values) if safe_values else 0
            axis.set_ylim(-0.5, max(1.5, max_value + 0.5))
            axis.set_yticks([])

            max_annotations = 10
            if len(labels) > 1:
                step = max(1, len(labels) // max_annotations)
                for label_time, label_text in labels[::step]:
                    axis.text(label_time, axis.get_ylim()[1] * 0.88, label_text, fontsize=7, color="#4d4d4d")

    axes[0].set_title(title, fontsize=16, weight="bold")
    axes[-1].set_xlabel("Time (ns)")
    axes[-1].set_xlim(start_ns, end_ns)

    fig.tight_layout()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, dpi=180)
    plt.close(fig)


def main() -> None:
    parser = argparse.ArgumentParser(description="Export waveform plots from fifo.vcd")
    parser.add_argument("--vcd", required=True, type=Path, help="Path to the VCD dump")
    parser.add_argument("--outdir", required=True, type=Path, help="Directory for generated PNGs")
    args = parser.parse_args()

    selected = {name for name, _ in SIGNALS}
    signal_map = parse_vcd(args.vcd, selected)

    missing = sorted(selected - set(signal_map))
    if missing:
        missing_list = ", ".join(missing)
        raise SystemExit(f"Missing expected VCD signals: {missing_list}")

    for start_ns, end_ns, filename, title in WINDOWS_NS:
        plot_window(signal_map, start_ns, end_ns, args.outdir / filename, title)


if __name__ == "__main__":
    main()
