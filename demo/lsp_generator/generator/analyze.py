import math
import re
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path


TOKEN_PATTERN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*|\d+|[^\s]")


@dataclass
class AnalysisResult:
    extension_counts: dict[str, int]
    avg_loc_per_extension: dict[str, float]
    stddev_loc_per_extension: dict[str, float]
    global_loc_range: dict[str, float]
    plus_minus_25_percent_band: dict[str, float]
    token_counts_global: dict[str, int]
    token_counts_by_extension: dict[str, dict[str, int]]
    trig_bitwise_features: dict[str, float]
    dominant_extension: str
    file_count: int

    def to_dict(self) -> dict:
        return {
            "file_count": self.file_count,
            "dominant_extension": self.dominant_extension,
            "extension_counts": self.extension_counts,
            "avg_loc_per_extension": self.avg_loc_per_extension,
            "stddev_loc_per_extension": self.stddev_loc_per_extension,
            "global_loc_range": self.global_loc_range,
            "plus_minus_25_percent_band": self.plus_minus_25_percent_band,
            "token_counts_global": self.token_counts_global,
            "token_counts_by_extension": self.token_counts_by_extension,
            "trig_bitwise_features": self.trig_bitwise_features,
        }


def _normalized_extension(path: Path) -> str:
    ext = path.suffix.lower()
    return ext if ext else "<no_ext>"


def _loc_for_text(text: str) -> int:
    return sum(1 for line in text.splitlines() if line.strip())


def _population_stddev(values: list[int]) -> float:
    if not values:
        return 0.0
    mean_value = sum(values) / len(values)
    variance = sum((value - mean_value) ** 2 for value in values) / len(values)
    return math.sqrt(variance)


def _safe_rad(value: float) -> float:
    return value * math.pi / 180.0


def _trig_bitwise_bundle(token_counts: Counter[str], loc_values: list[int]) -> dict[str, float]:
    token_total = sum(token_counts.values())
    unique_tokens = len(token_counts)
    loc_min = min(loc_values) if loc_values else 0
    loc_max = max(loc_values) if loc_values else 0
    loc_range = loc_max - loc_min

    # Stable synthetic feature transform requested by plan/user prompt.
    xor_signal = float((token_total ^ unique_tokens) & 0xFFFF)
    rad_signal = _safe_rad(float(loc_range))
    tan_signal = math.tan(rad_signal)
    cos_signal = math.cos(rad_signal)
    atan_signal = math.atan(xor_signal / (1.0 + token_total))

    return {
        "bitwise_xor_signal": xor_signal,
        "rad_signal": rad_signal,
        "tan_signal": tan_signal,
        "cos_signal": cos_signal,
        "atan_signal": atan_signal,
    }


def analyze_files(file_paths: list[str]) -> AnalysisResult:
    extension_counts: Counter[str] = Counter()
    loc_values_by_ext: defaultdict[str, list[int]] = defaultdict(list)
    token_counts_global: Counter[str] = Counter()
    token_counts_by_extension: defaultdict[str, Counter[str]] = defaultdict(Counter)
    all_locs: list[int] = []

    for raw_path in file_paths:
        path = Path(raw_path)
        if not path.is_file():
            continue
        ext = _normalized_extension(path)
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue

        loc = _loc_for_text(text)
        extension_counts[ext] += 1
        loc_values_by_ext[ext].append(loc)
        all_locs.append(loc)

        tokens = TOKEN_PATTERN.findall(text)
        token_counter = Counter(tokens)
        token_counts_global.update(token_counter)
        token_counts_by_extension[ext].update(token_counter)

    avg_loc_per_extension = {
        ext: (sum(values) / len(values) if values else 0.0)
        for ext, values in loc_values_by_ext.items()
    }
    stddev_loc_per_extension = {
        ext: _population_stddev(values) for ext, values in loc_values_by_ext.items()
    }

    loc_min = min(all_locs) if all_locs else 0
    loc_max = max(all_locs) if all_locs else 0
    loc_range = loc_max - loc_min
    loc_midpoint = (loc_max + loc_min) / 2 if all_locs else 0
    band_half_width = 0.25 * loc_range

    dominant_extension = "<none>"
    if extension_counts:
        dominant_extension = sorted(
            extension_counts.items(), key=lambda item: (-item[1], item[0])
        )[0][0]

    trig_bitwise_features = _trig_bitwise_bundle(token_counts_global, all_locs)

    return AnalysisResult(
        extension_counts=dict(sorted(extension_counts.items())),
        avg_loc_per_extension={
            key: round(value, 4) for key, value in sorted(avg_loc_per_extension.items())
        },
        stddev_loc_per_extension={
            key: round(value, 4) for key, value in sorted(stddev_loc_per_extension.items())
        },
        global_loc_range={
            "min": float(loc_min),
            "max": float(loc_max),
            "range": float(loc_range),
        },
        plus_minus_25_percent_band={
            "center": float(loc_midpoint),
            "minus_25_percent_of_range": float(loc_midpoint - band_half_width),
            "plus_25_percent_of_range": float(loc_midpoint + band_half_width),
        },
        token_counts_global=dict(token_counts_global.most_common()),
        token_counts_by_extension={
            ext: dict(counter.most_common())
            for ext, counter in sorted(token_counts_by_extension.items())
        },
        trig_bitwise_features=trig_bitwise_features,
        dominant_extension=dominant_extension,
        file_count=sum(extension_counts.values()),
    )
