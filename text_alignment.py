import argparse
import html
import json
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from sentence_transformers import SentenceTransformer


MODEL_NAME = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
MAX_GROUP_SIZE = 3
MINIMUM_SIMILARITY = 0.55
ANCHOR_SIMILARITY = 0.62
GAP_PENALTY = 0.015
GROUP_PENALTY = 0.025
TIME_PATTERN = re.compile(
    r"(?P<start>\d{1,3}:\d{2}:\d{2}[,.]\d{1,3})\s*-->\s*"
    r"(?P<end>\d{1,3}:\d{2}:\d{2}[,.]\d{1,3})"
)


@dataclass
class Cue:
    start: int
    end: int
    text: str


def parse_time(value: str) -> int:
    hours, minutes, remainder = value.replace(".", ",").split(":")
    seconds, milliseconds = remainder.split(",")
    return (
        (int(hours) * 3600 + int(minutes) * 60 + int(seconds)) * 1000
        + int(milliseconds.ljust(3, "0")[:3])
    )


def format_time(value: float) -> str:
    total = max(0, round(value))
    hours, total = divmod(total, 3_600_000)
    minutes, total = divmod(total, 60_000)
    seconds, milliseconds = divmod(total, 1_000)
    return f"{hours:02}:{minutes:02}:{seconds:02},{milliseconds:03}"


def read_srt(path: Path) -> list[Cue]:
    text = path.read_text(encoding="utf-8-sig").replace("\r", "").strip()
    cues = []
    for block in re.split(r"\n{2,}", text):
        lines = block.split("\n")
        timing_index = next(
            (index for index, line in enumerate(lines) if "-->" in line), None
        )
        if timing_index is None:
            continue
        match = TIME_PATTERN.search(lines[timing_index])
        if match is None:
            continue
        cue_text = "\n".join(lines[timing_index + 1 :]).strip()
        if cue_text:
            cues.append(
                Cue(
                    parse_time(match.group("start")),
                    parse_time(match.group("end")),
                    cue_text,
                )
            )
    if not cues:
        raise ValueError(f"No valid subtitle cues found in {path.name}.")
    return cues


def normalize_text(value: str) -> str:
    value = html.unescape(re.sub(r"<[^>]+>", " ", value))
    return re.sub(r"\s+", " ", value).strip()


def create_groups(cues: list[Cue]) -> tuple[list[str], list[tuple[int, int]]]:
    texts = []
    spans = []
    for start in range(len(cues)):
        for size in range(1, min(MAX_GROUP_SIZE, len(cues) - start) + 1):
            texts.append(normalize_text(" ".join(cue.text for cue in cues[start : start + size])))
            spans.append((start, size))
    return texts, spans


def align_groups(
    target_cues: list[Cue], reference_cues: list[Cue], model: SentenceTransformer
) -> list[tuple[int, int, int, int, float]]:
    target_texts, target_spans = create_groups(target_cues)
    reference_texts, reference_spans = create_groups(reference_cues)
    embeddings = model.encode(
        target_texts + reference_texts,
        batch_size=64,
        normalize_embeddings=True,
        convert_to_numpy=True,
        show_progress_bar=False,
    )
    target_vectors = embeddings[: len(target_texts)]
    reference_vectors = embeddings[len(target_texts) :]
    similarities = target_vectors @ reference_vectors.T

    target_group_index = {span: index for index, span in enumerate(target_spans)}
    reference_group_index = {span: index for index, span in enumerate(reference_spans)}
    target_count = len(target_cues)
    reference_count = len(reference_cues)
    scores = np.full((target_count + 1, reference_count + 1), -np.inf)
    trace_kind = np.zeros((target_count + 1, reference_count + 1), dtype=np.uint8)
    trace_target_size = np.zeros_like(trace_kind)
    trace_reference_size = np.zeros_like(trace_kind)
    scores[0, 0] = 0.0

    for target_index in range(target_count + 1):
        for reference_index in range(reference_count + 1):
            current = scores[target_index, reference_index]
            if not np.isfinite(current):
                continue
            if target_index < target_count:
                candidate = current - GAP_PENALTY
                if candidate > scores[target_index + 1, reference_index]:
                    scores[target_index + 1, reference_index] = candidate
                    trace_kind[target_index + 1, reference_index] = 1
            if reference_index < reference_count:
                candidate = current - GAP_PENALTY
                if candidate > scores[target_index, reference_index + 1]:
                    scores[target_index, reference_index + 1] = candidate
                    trace_kind[target_index, reference_index + 1] = 2

            for target_size in range(1, min(MAX_GROUP_SIZE, target_count - target_index) + 1):
                target_group = target_group_index[(target_index, target_size)]
                for reference_size in range(
                    1, min(MAX_GROUP_SIZE, reference_count - reference_index) + 1
                ):
                    reference_group = reference_group_index[
                        (reference_index, reference_size)
                    ]
                    similarity = float(similarities[target_group, reference_group])
                    if similarity < MINIMUM_SIMILARITY:
                        continue
                    candidate = (
                        current
                        + similarity
                        - MINIMUM_SIMILARITY
                        - GROUP_PENALTY * (target_size + reference_size - 2)
                    )
                    next_target = target_index + target_size
                    next_reference = reference_index + reference_size
                    if candidate > scores[next_target, next_reference]:
                        scores[next_target, next_reference] = candidate
                        trace_kind[next_target, next_reference] = 3
                        trace_target_size[next_target, next_reference] = target_size
                        trace_reference_size[next_target, next_reference] = reference_size

    matches = []
    target_index, reference_index = target_count, reference_count
    while target_index or reference_index:
        kind = trace_kind[target_index, reference_index]
        if kind == 1:
            target_index -= 1
        elif kind == 2:
            reference_index -= 1
        elif kind == 3:
            target_size = int(trace_target_size[target_index, reference_index])
            reference_size = int(trace_reference_size[target_index, reference_index])
            previous_target = target_index - target_size
            previous_reference = reference_index - reference_size
            target_group = target_group_index[(previous_target, target_size)]
            reference_group = reference_group_index[(previous_reference, reference_size)]
            similarity = float(similarities[target_group, reference_group])
            matches.append(
                (
                    previous_target,
                    previous_reference,
                    target_size,
                    reference_size,
                    similarity,
                )
            )
            target_index = previous_target
            reference_index = previous_reference
        else:
            raise RuntimeError("Could not reconstruct the subtitle alignment.")

    matches.reverse()
    return [match for match in matches if match[4] >= ANCHOR_SIMILARITY]


def build_anchors(
    matches: list[tuple[int, int, int, int, float]],
    target_cues: list[Cue],
    reference_cues: list[Cue],
) -> tuple[np.ndarray, np.ndarray]:
    anchors = []
    for target_start, reference_start, target_size, reference_size, confidence in matches:
        target_first = target_cues[target_start]
        reference_first = reference_cues[reference_start]
        anchors.append((target_first.start, reference_first.start, confidence))
        target_last = target_cues[target_start + target_size - 1]
        reference_last = reference_cues[reference_start + reference_size - 1]
        if target_size > 1 or reference_size > 1:
            anchors.append((target_last.end, reference_last.end, confidence))

    anchors.sort(key=lambda anchor: anchor[0])
    unique_anchors = []
    for source_time, reference_time, confidence in anchors:
        if unique_anchors and source_time == unique_anchors[-1][0]:
            prior = unique_anchors[-1]
            unique_anchors[-1] = (
                source_time,
                (prior[1] * prior[2] + reference_time * confidence)
                / (prior[2] + confidence),
                max(prior[2], confidence),
            )
        else:
            unique_anchors.append((source_time, reference_time, confidence))

    if len(unique_anchors) < 6:
        raise ValueError(
            f"Only {len(unique_anchors)} confident text matches were found; "
            "use the speech-pattern sync or load a clearer reference subtitle."
        )

    source_times = np.array([anchor[0] for anchor in unique_anchors], dtype=np.float64)
    reference_times = np.array([anchor[1] for anchor in unique_anchors], dtype=np.float64)
    reference_times = np.maximum.accumulate(reference_times)
    return source_times, reference_times


def map_time(value: int, source_times: np.ndarray, reference_times: np.ndarray) -> int:
    if value < source_times[0]:
        mapped = value + reference_times[0] - source_times[0]
    elif value > source_times[-1]:
        mapped = value + reference_times[-1] - source_times[-1]
    else:
        mapped = np.interp(value, source_times, reference_times)
    return max(0, round(float(mapped)))


def write_srt(path: Path, cues: list[Cue]) -> None:
    blocks = [
        f"{index}\n{format_time(cue.start)} --> {format_time(cue.end)}\n{cue.text}"
        for index, cue in enumerate(cues, start=1)
    ]
    path.write_text("\r\n\r\n".join(blocks) + "\r\n", encoding="utf-8-sig")


def load_model() -> SentenceTransformer:
    os.environ["HF_HUB_OFFLINE"] = "1"
    os.environ["TRANSFORMERS_OFFLINE"] = "1"
    return SentenceTransformer(MODEL_NAME, device="cpu")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("install", "align"))
    parser.add_argument("reference", nargs="?")
    parser.add_argument("target", nargs="?")
    parser.add_argument("output", nargs="?")
    args = parser.parse_args()

    if args.command == "install":
        os.environ.pop("HF_HUB_OFFLINE", None)
        os.environ.pop("TRANSFORMERS_OFFLINE", None)
        SentenceTransformer(MODEL_NAME, device="cpu")
        print(json.dumps({"ready": True, "model": MODEL_NAME}))
        return

    if not args.reference or not args.target or not args.output:
        parser.error("align requires reference, target, and output paths")

    reference_cues = read_srt(Path(args.reference))
    target_cues = read_srt(Path(args.target))
    model = load_model()
    matches = align_groups(target_cues, reference_cues, model)
    source_times, reference_times = build_anchors(matches, target_cues, reference_cues)

    synced_cues = [
        Cue(
            map_time(cue.start, source_times, reference_times),
            map_time(cue.end, source_times, reference_times),
            cue.text,
        )
        for cue in target_cues
    ]
    write_srt(Path(args.output), synced_cues)
    print(
        json.dumps(
            {
                "cueCount": len(synced_cues),
                "matchedGroups": len(matches),
                "anchors": len(source_times),
                "averageSimilarity": round(
                    sum(match[4] for match in matches) / len(matches), 3
                ),
                "firstCue": format_time(synced_cues[0].start),
                "lastCue": format_time(synced_cues[-1].start),
            }
        )
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        raise