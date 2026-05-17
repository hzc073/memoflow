#!/usr/bin/env python3
"""Generate MemoFlow-compatible ZIP packages with built-in or AI memo content.

The output ZIP follows the same structure used by MemoFlow export/import:
- index.md
- memos/<timestamp>_<uid>.md
"""

from __future__ import annotations

import argparse
import json
import os
import random
import re
import string
import sys
import urllib.error
import urllib.request
import zipfile
from datetime import date, datetime, time, timedelta, timezone
from pathlib import Path
from typing import Iterable

MAX_TAG_COUNT = 50
DEFAULT_OPENAI_BASE_URL = "https://api.openai.com/v1"
DEFAULT_OPENAI_MODEL = "gpt-4o-mini"
DEFAULT_CONTENT_BATCH_SIZE = 10
DEFAULT_RECENT_MEMO_COUNT = 3

FALLBACK_ZH_TAGS = [
    "工作", "学习", "阅读", "写作", "复盘", "总结", "计划", "目标", "效率", "专注",
    "灵感", "创意", "项目", "会议", "沟通", "决策", "记录", "习惯", "健康", "运动",
    "跑步", "饮食", "睡眠", "情绪", "成长", "家庭", "朋友", "旅行", "摄影", "理财",
    "预算", "消费", "投资", "技术", "编程", "产品", "设计", "营销", "运营", "复习",
    "清单", "提醒", "待办", "复查", "思考", "反思", "知识", "整理", "归档", "生活",
]

FALLBACK_EN_TAGS = [
    "work", "study", "reading", "writing", "review", "summary", "planning", "goals", "focus", "productivity",
    "idea", "creativity", "project", "meeting", "communication", "decision", "journal", "habit", "health", "fitness",
    "running", "nutrition", "sleep", "mood", "growth", "family", "friends", "travel", "photo", "finance",
    "budget", "spending", "investing", "tech", "coding", "product", "design", "marketing", "operations", "practice",
    "checklist", "reminder", "todo", "followup", "thinking", "reflection", "knowledge", "organizing", "archive", "life",
]

ZH_TOPICS = [
    "工作推进", "学习笔记", "阅读收获", "项目进展", "日常复盘", "健康管理", "运动计划", "理财安排", "家庭事务", "旅行准备",
    "内容创作", "技术调研", "产品思路", "会议纪要", "任务拆解", "时间管理", "习惯打卡", "情绪观察", "目标跟进", "生活记录",
]

ZH_ACTIONS = [
    "把关键问题重新拆解，优先处理最影响结果的两项。",
    "今天完成了主要步骤，剩余部分准备明天集中处理。",
    "记录了几个容易忽略的细节，避免后续重复返工。",
    "对照原计划做了微调，节奏比预期更稳定。",
    "把分散的信息整理成清单，执行起来更顺手。",
    "先完成最小可行版本，再决定是否继续扩展。",
    "把资料按主题分类，后续检索效率提升很多。",
    "遇到阻塞点后先回退一步，问题定位更清晰。",
    "今天重点放在质量，不追求数量。",
    "安排了下一步的时间窗口，减少临时决策成本。",
]

ZH_REFLECTIONS = [
    "整体状态还不错，保持这个节奏即可。",
    "这次调整有效，后面可以继续沿用。",
    "需要控制分心时间，优先完成核心任务。",
    "如果明天执行顺利，本周目标基本可达成。",
    "过程比结果更重要，先把方法跑通。",
    "今天的记录对后续复盘会很有帮助。",
    "下一次可以把准备工作提前半小时完成。",
    "当前方向可行，先小步快跑验证。",
    "注意留出缓冲时间，避免计划过满。",
    "持续跟踪一周后再评估是否需要调整。",
]

EN_TOPICS = [
    "work progress", "study notes", "reading insights", "project update", "daily review", "health tracking", "fitness routine", "finance planning", "family tasks", "travel prep",
    "content draft", "technical research", "product idea", "meeting notes", "task breakdown", "time management", "habit tracking", "mood check", "goal follow-up", "life log",
]

EN_ACTIONS = [
    "I broke down the key problem and handled the two highest impact tasks first.",
    "The core steps are done, and I will finish the remaining part tomorrow.",
    "I captured small details that usually cause rework later.",
    "I adjusted the original plan and the pace feels steadier now.",
    "I turned scattered information into a checklist for execution.",
    "I built a minimal version first before deciding on expansion.",
    "I grouped the material by topic, which improved retrieval speed.",
    "After hitting a blocker, I stepped back and clarified the root issue.",
    "Today I prioritized quality instead of quantity.",
    "I reserved a clear time slot for the next step to reduce ad hoc decisions.",
]

EN_REFLECTIONS = [
    "Overall energy was solid, so I should keep this rhythm.",
    "This adjustment worked well and is worth repeating.",
    "I need to reduce context switching and protect core work blocks.",
    "If tomorrow goes well, the weekly target should be on track.",
    "Method first, results second; the process is getting clearer.",
    "These notes will be useful for the next review.",
    "Next time I should finish preparation thirty minutes earlier.",
    "The current direction is workable, so I will validate in small steps.",
    "I need more buffer time to avoid an overloaded plan.",
    "I will track this for a week before making another adjustment.",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate MemoFlow-importable ZIP with built-in or AI memo content.",
    )
    parser.add_argument("--start-date", required=True, help="Start date, format YYYY-MM-DD")
    parser.add_argument("--end-date", required=True, help="End date, format YYYY-MM-DD")
    parser.add_argument("--memo-count", type=int, required=True, help="Number of memos to generate")
    parser.add_argument("--tag-count", type=int, required=True, help="Tag count per memo pool (max 50)")
    parser.add_argument("--language", choices=("zh", "en"), required=True, help="Memo language")
    parser.add_argument(
        "--tag-source",
        choices=("auto", "ai", "builtin"),
        default="auto",
        help="Tag source: auto (AI first, fallback), ai (AI only), builtin (local tags only)",
    )
    parser.add_argument(
        "--content-source",
        choices=("auto", "ai", "builtin"),
        default="builtin",
        help="Memo body source: auto (AI first, fallback), ai (AI only), builtin (template only)",
    )
    parser.add_argument(
        "--content-batch-size",
        type=int,
        default=DEFAULT_CONTENT_BATCH_SIZE,
        help="How many memos to request per AI batch when content-source is ai/auto",
    )
    parser.add_argument(
        "--recent-memo-count",
        type=int,
        default=DEFAULT_RECENT_MEMO_COUNT,
        help="How many recent generated memos to pass back to AI for continuity",
    )
    parser.add_argument(
        "--author-profile",
        default="",
        help="Optional author profile passed to AI to make memo content feel more realistic",
    )
    parser.add_argument(
        "--memo-context",
        default="",
        help="Optional long-running projects or life context passed to AI",
    )
    parser.add_argument(
        "--output",
        default="",
        help="Output zip path. Default: ./MemoFlow_generated_<timestamp>.zip",
    )
    parser.add_argument("--seed", type=int, default=None, help="Optional random seed")
    parser.add_argument(
        "--ai-timeout",
        type=int,
        default=25,
        help="AI request timeout in seconds",
    )
    return parser.parse_args()


def parse_ymd(value: str) -> date:
    try:
        return datetime.strptime(value, "%Y-%m-%d").date()
    except ValueError as exc:
        raise ValueError(f"Invalid date '{value}'. Expected YYYY-MM-DD") from exc


def ensure_chat_url(base_url: str) -> str:
    cleaned = base_url.strip().rstrip("/")
    if not cleaned:
        cleaned = DEFAULT_OPENAI_BASE_URL
    if cleaned.endswith("/chat/completions"):
        return cleaned
    return f"{cleaned}/chat/completions"


def parse_json_payload(raw_text: str) -> object | None:
    content = raw_text.strip()
    if not content:
        return None

    candidates = [content]
    for open_char, close_char in (("[", "]"), ("{", "}")):
        start = content.find(open_char)
        end = content.rfind(close_char)
        if 0 <= start < end:
            snippet = content[start : end + 1]
            if snippet not in candidates:
                candidates.append(snippet)

    for candidate in candidates:
        try:
            return json.loads(candidate)
        except json.JSONDecodeError:
            continue
    return None


def normalize_tag(raw_tag: str, language: str) -> str:
    tag = raw_tag.strip().strip("`\"'")
    while tag.startswith("#"):
        tag = tag[1:]
    tag = tag.strip().strip(".,;:!?，。；：、")
    if not tag:
        return ""

    if language == "en":
        tag = tag.lower()
        tag = re.sub(r"\s+", "-", tag)
        tag = re.sub(r"[^a-z0-9_-]", "", tag)
        return tag

    tag = re.sub(r"[A-Za-z]", "", tag)
    tag = re.sub(r"\s+", "", tag)
    return tag


def parse_tags_from_text(raw_text: str, language: str) -> list[str]:
    content = raw_text.strip()
    if not content:
        return []

    candidates: list[str] = []
    parsed_json = parse_json_payload(content)

    if isinstance(parsed_json, list):
        for item in parsed_json:
            if isinstance(item, str):
                candidates.append(item)

    if not candidates:
        for chunk in re.split(r"[\n,;|]", content):
            item = chunk.strip()
            if item:
                candidates.append(item)

    deduped: list[str] = []
    seen: set[str] = set()
    for candidate in candidates:
        tag = normalize_tag(candidate, language)
        if not tag or tag in seen:
            continue
        if language == "en" and not re.fullmatch(r"[a-z0-9_-]+", tag):
            continue
        if language == "zh" and re.search(r"[A-Za-z]", tag):
            continue
        seen.add(tag)
        deduped.append(tag)

    return deduped


def ai_prompt_for_language(language: str) -> str:
    if language == "zh":
        return (
            "请生成50个常用笔记标签。要求："
            "1) 只输出JSON数组；"
            "2) 每个标签必须是纯中文，不要英文，不要#；"
            "3) 标签覆盖工作、学习、生活、健康、财务、阅读、写作、项目管理；"
            "4) 必须恰好50个且不重复。"
        )
    return (
        "Generate 50 common note tags. Requirements: "
        "1) Output JSON array only; "
        "2) Each tag must be pure English lowercase, no '#', use single token or hyphenated token; "
        "3) Cover work, study, life, health, finance, reading, writing, project management; "
        "4) Exactly 50 unique tags."
    )


def call_ai_chat(messages: list[dict[str, str]], timeout_sec: int, temperature: float) -> str:
    api_key = os.getenv("OPENAI_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY is not set")

    base_url = os.getenv("OPENAI_BASE_URL", DEFAULT_OPENAI_BASE_URL)
    model = os.getenv("OPENAI_MODEL", DEFAULT_OPENAI_MODEL)
    endpoint = ensure_chat_url(base_url)

    payload = {
        "model": model,
        "temperature": temperature,
        "messages": messages,
    }

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        endpoint,
        data=data,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=timeout_sec) as resp:
            body = resp.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        details = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"AI request failed ({exc.code}): {details}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"AI request failed: {exc}") from exc

    try:
        parsed = json.loads(body)
        return str(parsed["choices"][0]["message"]["content"])
    except (KeyError, IndexError, TypeError, json.JSONDecodeError) as exc:
        raise RuntimeError("Unexpected AI response format") from exc


def call_ai_for_tags(language: str, timeout_sec: int) -> list[str]:
    ai_text = call_ai_chat(
        messages=[
            {
                "role": "system",
                "content": "You are a strict formatter. Return only JSON array.",
            },
            {
                "role": "user",
                "content": ai_prompt_for_language(language),
            },
        ],
        timeout_sec=timeout_sec,
        temperature=0.4,
    )

    tags = parse_tags_from_text(str(ai_text), language)
    if len(tags) < MAX_TAG_COUNT:
        raise RuntimeError(f"AI returned too few tags: {len(tags)}")

    return tags[:MAX_TAG_COUNT]


def fallback_tags(language: str) -> list[str]:
    return FALLBACK_ZH_TAGS[:] if language == "zh" else FALLBACK_EN_TAGS[:]


def build_tag_pool(language: str, tag_source: str, timeout_sec: int) -> tuple[list[str], str]:
    if tag_source == "builtin":
        return fallback_tags(language), "builtin"

    if tag_source in ("auto", "ai"):
        try:
            return call_ai_for_tags(language, timeout_sec), "ai"
        except Exception as exc:
            if tag_source == "ai":
                raise
            print(f"[warn] AI tag generation failed, fallback to built-in tags: {exc}", file=sys.stderr)
            return fallback_tags(language), "builtin"

    return fallback_tags(language), "builtin"


def build_tag_line(tags: Iterable[str]) -> str:
    items = [t for t in tags if t]
    if not items:
        return ""
    return " ".join(f"#{tag}" for tag in items)


def clean_body_text(raw_text: str) -> str:
    text = raw_text.replace("\r\n", "\n").strip()
    if text.startswith("```"):
        text = re.sub(r"^```[a-zA-Z0-9_-]*\n?", "", text)
        text = re.sub(r"\n?```$", "", text).strip()
    lines = [line.rstrip() for line in text.split("\n")]
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    return "\n".join(lines).strip()


def finalize_body(body: str, tags: list[str]) -> str:
    cleaned = clean_body_text(body)
    tag_line = build_tag_line(tags)
    if cleaned and tag_line:
        return f"{cleaned}\n{tag_line}"
    if cleaned:
        return cleaned
    return tag_line


def recent_memo_preview(body: str, max_chars: int = 120) -> str:
    single_line = re.sub(r"\s+", " ", clean_body_text(body))
    if len(single_line) <= max_chars:
        return single_line
    return f"{single_line[: max_chars - 3].rstrip()}..."


def generate_uid(rng: random.Random, length: int = 12) -> str:
    alphabet = string.ascii_lowercase + string.digits
    return "".join(rng.choice(alphabet) for _ in range(length))


def random_datetime_in_range(rng: random.Random, start_day: date, end_day: date) -> datetime:
    start_dt = datetime.combine(start_day, time.min, tzinfo=timezone.utc)
    end_dt = datetime.combine(end_day, time.max, tzinfo=timezone.utc)
    total_seconds = int((end_dt - start_dt).total_seconds())
    offset = rng.randint(0, max(total_seconds, 0))
    return start_dt + timedelta(seconds=offset)


def safe_uid_prefix(uid: str) -> str:
    cleaned = re.sub(r"[^a-zA-Z0-9_-]", "", uid)
    if len(cleaned) < 8:
        cleaned = cleaned.ljust(8, "_")
    return cleaned[:8]


def memo_filename(created_at: datetime, uid: str, used: set[str]) -> str:
    base = f"{created_at.strftime('%Y%m%d_%H%M%S')}_{safe_uid_prefix(uid)}"
    name = f"{base}.md"
    index = 1
    while name in used:
        name = f"{base}_{index}.md"
        index += 1
    used.add(name)
    return name


def format_tags_for_front_matter(tags: Iterable[str]) -> str:
    return build_tag_line(tags)


def generate_zh_body(rng: random.Random, created_at: datetime) -> str:
    topic = rng.choice(ZH_TOPICS)
    action = rng.choice(ZH_ACTIONS)
    reflection = rng.choice(ZH_REFLECTIONS)
    date_text = created_at.strftime("%Y-%m-%d")
    return (
        f"{date_text} 围绕{topic}做了阶段记录。\n"
        f"{action}\n"
        f"{reflection}"
    )


def generate_en_body(rng: random.Random, created_at: datetime) -> str:
    topic = rng.choice(EN_TOPICS)
    action = rng.choice(EN_ACTIONS)
    reflection = rng.choice(EN_REFLECTIONS)
    date_text = created_at.strftime("%Y-%m-%d")
    return (
        f"{date_text} quick note on {topic}.\n"
        f"{action}\n"
        f"{reflection}"
    )


def generate_builtin_body(rng: random.Random, language: str, tags: list[str], created_at: datetime) -> str:
    if language == "zh":
        return finalize_body(generate_zh_body(rng, created_at), tags)
    return finalize_body(generate_en_body(rng, created_at), tags)


def build_ai_memo_batch_prompt(
    language: str,
    batch: list[dict[str, object]],
    recent_previews: list[str],
    author_profile: str,
    memo_context: str,
) -> str:
    language_name = "Simplified Chinese" if language == "zh" else "English"
    batch_items = [
        {
            "id": str(item["uid"]),
            "created_at": str(item["created_at"]),
            "weekday": datetime.fromisoformat(str(item["created_at"])).strftime("%A"),
            "tags": list(item["tags"]),
        }
        for item in batch
    ]
    prompt_payload = {
        "language": language_name,
        "author_profile": author_profile.strip() or "Use one plausible ordinary person and keep the voice consistent across entries.",
        "memo_context": memo_context.strip() or "Keep a few recurring work, study, health, family, or side-project threads across the notes.",
        "recent_memo_previews": recent_previews,
        "requirements": [
            "Return JSON array only.",
            "Each item must be an object with keys: id, body.",
            "Match every input id exactly once.",
            "Write the body in the requested language.",
            "Body only. No title, no YAML, no code fences, no hashtags.",
            "Sound like realistic quick memos, not polished articles, reports, or motivational summaries.",
            "Use concrete details, blockers, follow-ups, or small observations when natural.",
            "Vary tone and length. Some notes can feel incomplete or casual.",
            "Prefer 3-6 short lines for each memo.",
            "Use tags only as soft hints; do not just restate all tags.",
        ],
        "items": batch_items,
    }
    return json.dumps(prompt_payload, ensure_ascii=False, indent=2)


def parse_memo_bodies_from_text(raw_text: str, expected_ids: list[str]) -> dict[str, str]:
    parsed = parse_json_payload(raw_text)
    if parsed is None:
        raise RuntimeError("AI memo content was not valid JSON")

    bodies: dict[str, str] = {}
    expected = set(expected_ids)

    if isinstance(parsed, dict) and isinstance(parsed.get("items"), list):
        parsed = parsed["items"]

    if isinstance(parsed, dict):
        for memo_id, body in parsed.items():
            if memo_id in expected and isinstance(body, str):
                cleaned = clean_body_text(body)
                if cleaned:
                    bodies[memo_id] = cleaned
    elif isinstance(parsed, list):
        for item in parsed:
            if not isinstance(item, dict):
                continue
            memo_id = str(item.get("id", "")).strip()
            body = item.get("body")
            if memo_id not in expected or not isinstance(body, str):
                continue
            cleaned = clean_body_text(body)
            if cleaned:
                bodies[memo_id] = cleaned

    missing = [memo_id for memo_id in expected_ids if memo_id not in bodies]
    if missing:
        raise RuntimeError(f"AI memo content missing items: {', '.join(missing[:5])}")
    return bodies


def call_ai_for_memo_bodies(
    language: str,
    batch: list[dict[str, object]],
    recent_previews: list[str],
    author_profile: str,
    memo_context: str,
    timeout_sec: int,
) -> dict[str, str]:
    ai_text = call_ai_chat(
        messages=[
            {
                "role": "system",
                "content": (
                    "You write realistic personal memos. Return JSON array only. "
                    "Each item must be an object with keys 'id' and 'body'. "
                    "No markdown code fences, no explanations, no YAML."
                ),
            },
            {
                "role": "user",
                "content": build_ai_memo_batch_prompt(
                    language=language,
                    batch=batch,
                    recent_previews=recent_previews,
                    author_profile=author_profile,
                    memo_context=memo_context,
                ),
            },
        ],
        timeout_sec=timeout_sec,
        temperature=0.9,
    )
    expected_ids = [str(item["uid"]) for item in batch]
    return parse_memo_bodies_from_text(ai_text, expected_ids)


def build_memo_bodies_for_batch(
    rng: random.Random,
    language: str,
    batch: list[dict[str, object]],
    content_source: str,
    timeout_sec: int,
    recent_previews: list[str],
    author_profile: str,
    memo_context: str,
) -> tuple[dict[str, str], str]:
    if content_source == "builtin":
        return (
            {
                str(item["uid"]): generate_builtin_body(
                    rng=rng,
                    language=language,
                    tags=list(item["tags"]),
                    created_at=datetime.fromisoformat(str(item["created_at"])),
                )
                for item in batch
            },
            "builtin",
        )

    if content_source in ("auto", "ai"):
        try:
            ai_bodies = call_ai_for_memo_bodies(
                language=language,
                batch=batch,
                recent_previews=recent_previews,
                author_profile=author_profile,
                memo_context=memo_context,
                timeout_sec=timeout_sec,
            )
            return (
                {
                    str(item["uid"]): finalize_body(
                        ai_bodies[str(item["uid"])],
                        list(item["tags"]),
                    )
                    for item in batch
                },
                "ai",
            )
        except Exception as exc:
            if content_source == "ai":
                raise
            print(f"[warn] AI memo generation failed, fallback to built-in content: {exc}", file=sys.stderr)
            return (
                {
                    str(item["uid"]): generate_builtin_body(
                        rng=rng,
                        language=language,
                        tags=list(item["tags"]),
                        created_at=datetime.fromisoformat(str(item["created_at"])),
                    )
                    for item in batch
                },
                "builtin",
            )

    return (
        {
            str(item["uid"]): generate_builtin_body(
                rng=rng,
                language=language,
                tags=list(item["tags"]),
                created_at=datetime.fromisoformat(str(item["created_at"])),
            )
            for item in batch
        },
        "builtin",
    )


def chunked(items: list[dict[str, object]], size: int) -> Iterable[list[dict[str, object]]]:
    for index in range(0, len(items), size):
        yield items[index : index + size]


def build_memo_markdown(
    uid: str,
    created_at: datetime,
    updated_at: datetime,
    visibility: str,
    pinned: bool,
    state: str,
    tags: list[str],
    body: str,
) -> str:
    lines = [
        "---",
        f"uid: {uid}",
        f"created: {created_at.isoformat().replace('+00:00', 'Z')}",
        f"updated: {updated_at.isoformat().replace('+00:00', 'Z')}",
        f"visibility: {visibility}",
        f"pinned: {'true' if pinned else 'false'}",
        f"state: {state}",
    ]

    tag_text = format_tags_for_front_matter(tags)
    if tag_text:
        lines.append(f"tags: {tag_text}")

    lines.extend([
        "---",
        "",
        body.rstrip(),
        "",
    ])
    return "\n".join(lines)


def build_index_markdown(
    language: str,
    start_day: date,
    end_day: date,
    memo_count: int,
    tag_count: int,
    tag_source_used: str,
    content_source_used: str,
) -> str:
    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    if language == "zh":
        return (
            "# MemoFlow 导出\n\n"
            f"- 导出时间: {now}\n"
            f"- 日期范围: {start_day.isoformat()} ~ {end_day.isoformat()}\n"
            f"- 语言: 中文\n"
            f"- 笔记数量: {memo_count}\n"
            f"- 标签数量: {tag_count}\n"
            f"- 标签来源: {tag_source_used}\n"
            f"- 正文来源: {content_source_used}\n"
        )

    return (
        "# MemoFlow Export\n\n"
        f"- Exported at: {now}\n"
        f"- Date range: {start_day.isoformat()} ~ {end_day.isoformat()}\n"
        f"- Language: English\n"
        f"- Memo count: {memo_count}\n"
        f"- Tag count: {tag_count}\n"
        f"- Tag source: {tag_source_used}\n"
        f"- Content source: {content_source_used}\n"
    )


def main() -> int:
    args = parse_args()

    try:
        start_day = parse_ymd(args.start_date)
        end_day = parse_ymd(args.end_date)
    except ValueError as exc:
        print(f"[error] {exc}", file=sys.stderr)
        return 1

    if end_day < start_day:
        print("[error] end-date must be greater than or equal to start-date", file=sys.stderr)
        return 1

    if args.memo_count <= 0:
        print("[error] memo-count must be greater than 0", file=sys.stderr)
        return 1

    if args.tag_count < 0:
        print("[error] tag-count must be >= 0", file=sys.stderr)
        return 1

    if args.content_batch_size <= 0:
        print("[error] content-batch-size must be greater than 0", file=sys.stderr)
        return 1

    if args.recent_memo_count < 0:
        print("[error] recent-memo-count must be >= 0", file=sys.stderr)
        return 1

    rng = random.Random(args.seed)

    try:
        tag_pool, tag_source_used = build_tag_pool(
            language=args.language,
            tag_source=args.tag_source,
            timeout_sec=args.ai_timeout,
        )
    except Exception as exc:
        print(f"[error] Failed to build tag pool: {exc}", file=sys.stderr)
        return 1

    capped_tag_count = min(args.tag_count, MAX_TAG_COUNT, len(tag_pool))
    if args.tag_count > MAX_TAG_COUNT:
        print(
            f"[warn] tag-count={args.tag_count} exceeds {MAX_TAG_COUNT}, using {MAX_TAG_COUNT}",
            file=sys.stderr,
        )

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_path = Path(args.output) if args.output else Path(f"MemoFlow_generated_{timestamp}.zip")
    if output_path.parent and str(output_path.parent) != ".":
        output_path.parent.mkdir(parents=True, exist_ok=True)

    used_names: set[str] = set()
    memos: list[tuple[str, str]] = []
    memo_records: list[dict[str, object]] = []

    for _ in range(args.memo_count):
        created_at = random_datetime_in_range(rng, start_day, end_day)
        updated_at = created_at + timedelta(minutes=rng.randint(0, 240))
        uid = generate_uid(rng)

        visibility = "PRIVATE"
        state = "NORMAL"
        pinned = False

        selected_tags: list[str] = []
        if capped_tag_count > 0:
            per_memo_count = rng.randint(1, min(capped_tag_count, 5))
            selected_tags = rng.sample(tag_pool, k=per_memo_count)

        memo_records.append(
            {
                "uid": uid,
                "created_at": created_at.isoformat(),
                "updated_at": updated_at.isoformat(),
                "visibility": visibility,
                "pinned": pinned,
                "state": state,
                "tags": selected_tags,
            }
        )

    memo_records.sort(key=lambda item: (str(item["created_at"]), str(item["uid"])))

    recent_previews: list[str] = []
    content_sources_used: list[str] = []
    for batch in chunked(memo_records, args.content_batch_size):
        bodies_by_uid, content_source_used = build_memo_bodies_for_batch(
            rng=rng,
            language=args.language,
            batch=batch,
            content_source=args.content_source,
            timeout_sec=args.ai_timeout,
            recent_previews=recent_previews,
            author_profile=args.author_profile,
            memo_context=args.memo_context,
        )
        if content_source_used not in content_sources_used:
            content_sources_used.append(content_source_used)

        for item in batch:
            uid = str(item["uid"])
            body = bodies_by_uid[uid]
            item["body"] = body
            if args.recent_memo_count > 0:
                created_label = datetime.fromisoformat(str(item["created_at"])).strftime("%Y-%m-%d %H:%M")
                preview = recent_memo_preview(body)
                if preview:
                    recent_previews.append(f"{created_label} | {preview}")
                    recent_previews = recent_previews[-args.recent_memo_count :]

    content_source_used_label = "+".join(content_sources_used) if content_sources_used else "builtin"

    for item in memo_records:
        created_at = datetime.fromisoformat(str(item["created_at"]))
        updated_at = datetime.fromisoformat(str(item["updated_at"]))
        uid = str(item["uid"])
        content = build_memo_markdown(
            uid=uid,
            created_at=created_at,
            updated_at=updated_at,
            visibility=str(item["visibility"]),
            pinned=bool(item["pinned"]),
            state=str(item["state"]),
            tags=list(item["tags"]),
            body=str(item["body"]),
        )
        filename = memo_filename(created_at, uid, used_names)
        memos.append((filename, content))

    index_content = build_index_markdown(
        language=args.language,
        start_day=start_day,
        end_day=end_day,
        memo_count=args.memo_count,
        tag_count=capped_tag_count,
        tag_source_used=tag_source_used,
        content_source_used=content_source_used_label,
    )

    with zipfile.ZipFile(output_path, mode="w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("index.md", index_content)
        for filename, content in memos:
            zf.writestr(f"memos/{filename}", content)

    print(f"Output: {output_path.resolve()}")
    print(f"Memos: {args.memo_count}")
    print(f"Language: {args.language}")
    print(f"Tag source: {tag_source_used}")
    print(f"Content source: {content_source_used_label}")
    print(f"Tag cap applied: {capped_tag_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
